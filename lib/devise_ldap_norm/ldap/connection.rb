module Devise
  module LDAP
    class Connection
      attr_reader :ldap, :login

      def initialize(params = {})
        if ::Devise.ldap_config.is_a?(Proc)
          ldap_config = ::Devise.ldap_config.call
        else
          ldap_config = YAML.load(ERB.new(File.read(::Devise.ldap_config || "#{Rails.root}/config/ldap.yml")).result)[Rails.env]
        end
        ldap_options = params
        ldap_config['ssl'] = :simple_tls if ldap_config['ssl'] === true
        ldap_options[:encryption] = ldap_config['ssl'].to_sym if ldap_config['ssl']

        @ldap = Net::LDAP.new(ldap_options)
        @ldap.host = ldap_config['host']
        @ldap.port = ldap_config['port']
        @ldap.base = ldap_config['base']
        @attribute = ldap_config['attribute']
        @allow_unauthenticated_bind = ldap_config['allow_unauthenticated_bind']

        @ldap_auth_username_builder = params[:ldap_auth_username_builder]

        @group_base = ldap_config['group_base']
        @check_group_membership = ldap_config.has_key?('check_group_membership') ? ldap_config['check_group_membership'] : ::Devise.ldap_check_group_membership

        @allowed_groups = ldap_config['allowed_groups'] || []
        @allowed_groups = @allowed_groups.split(' ') if @allowed_groups.is_a? ::String

        @required_attributes = ldap_config["require_attribute"]

        @ldap.auth ldap_config["admin_user"], ldap_config["admin_password"] if params[:admin]
        @ldap.auth params[:login], params[:password] if ldap_config["admin_as_user"]

        @login = (params[:login] || '').gsub(/[^-\w.@]/i, '')
        @password = params[:password]
        @new_password = params[:new_password]
      end

      def delete_param(param)
        update_ldap [[:delete, param.to_sym, nil]]
      end

      def set_param(param, new_value)
        update_ldap( { param.to_sym => new_value } )
      end

      def dn
        @dn ||= begin
          DeviseLdapNorm::Logger.send("LDAP dn lookup: #{@attribute}=#{@login}")
          ldap_entry = search_for_login
          if ldap_entry.nil?
            @ldap_auth_username_builder.call(@attribute,@login,@ldap)
          else
            ldap_entry.dn
          end
        end
      end

      def ldap_param_value(param)
        ldap_entry = search_for_login

        if ldap_entry
          unless ldap_entry[param].empty?
            value = ldap_entry.send(param)
            DeviseLdapNorm::Logger.send("Requested param #{param} has value #{value}")
            value
          else
            DeviseLdapNorm::Logger.send("Requested param #{param} does not exist")
            value = nil
          end
        else
          DeviseLdapNorm::Logger.send("Requested ldap entry does not exist")
          value = nil
        end
      end

      def authenticate!
        return false unless (@password.present? || @allow_unauthenticated_bind)
        @ldap.auth(dn, @password)
        @ldap.bind
      end

      def authenticated?
        authenticate!
      end

      def authorized?
        DeviseLdapNorm::Logger.send("Authorizing user #{dn}")
        if !authenticated?
          DeviseLdapNorm::Logger.send("Not authorized because not authenticated.")
          return false
        elsif !in_allowed_groups?
          DeviseLdapNorm::Logger.send("Not authorized because not in allowed groups.")
          return false
        elsif !has_required_attribute?
          DeviseLdapNorm::Logger.send("Not authorized because does not have required attribute.")
          return false
        else
          return true
        end
      end

      def change_password!
        update_ldap(:userpassword => Net::LDAP::Password.generate(:sha, @new_password))
      end

      def in_allowed_groups?
        return true unless @check_group_membership

        memberships = self.ldap_param_value("memberOf")

        return false if memberships.blank?

        memberships.map! do |g|
          m = g.match(/cn=([A-Za-z0-9\._-]+),./)
          m[1] unless m.nil?
        end

        # array bisect to determine if any of the groups in groups is allowed access
        (memberships & @allowed_groups).length > 0
      end

      def in_required_groups?
        return true unless @check_group_membership


        ## FIXME set errors here, the ldap.yml isn't set properly.
        return false if @required_groups.nil?

        for group in @required_groups
          if group.is_a?(Array)
            return false unless in_group?(group[1], group[0])
          else
            return false unless in_group?(group)
          end
        end
        return true
      end

      def in_group?(group_name, group_attribute = LDAP::DEFAULT_GROUP_UNIQUE_MEMBER_LIST_KEY)
        in_group = false

        admin_ldap = Connection.admin

        unless ::Devise.ldap_ad_group_check
          admin_ldap.search(:base => group_name, :scope => Net::LDAP::SearchScope_BaseObject) do |entry|
            if entry[group_attribute].include? dn
              in_group = true
            end
          end
        else
          # AD optimization - extension will recursively check sub-groups with one query
          # "(memberof:1.2.840.113556.1.4.1941:=group_name)"
          search_result = admin_ldap.search(:base => dn,
                            :filter => Net::LDAP::Filter.ex("memberof:1.2.840.113556.1.4.1941", group_name),
                            :scope => Net::LDAP::SearchScope_BaseObject)
          # Will return  the user entry if belongs to group otherwise nothing
          if search_result.length == 1 && search_result[0].dn.eql?(dn)
            in_group = true
          end
        end

        unless in_group
          DeviseLdapNorm::Logger.send("User #{dn} is not in group: #{group_name}")
        end

        return in_group
      end

      def has_required_attribute?
        return true unless ::Devise.ldap_check_attributes

        admin_ldap = Connection.admin

        user = find_ldap_user(admin_ldap)

        @required_attributes.each do |key,val|
          unless user[key].include? val
            DeviseLdapNorm::Logger.send("User #{dn} did not match attribute #{key}:#{val}")
            return false
          end
        end

        return true
      end

      def user_groups
        admin_ldap = Connection.admin

        DeviseLdapNorm::Logger.send("Getting groups for #{dn}")
        filter = Net::LDAP::Filter.eq("uniqueMember", dn)
        admin_ldap.search(:filter => filter, :base => @group_base).collect(&:dn)
      end

      def valid_login?
        !search_for_login.nil?
      end

      # Searches the LDAP for the login
      #
      # @return [Object] the LDAP entry found; nil if not found
      def search_for_login
        @login_ldap_entry ||= begin
          DeviseLdapNorm::Logger.send("LDAP search for login: #{@attribute}=#{@login}")
          filter = Net::LDAP::Filter.eq(@attribute.to_s, @login.to_s)
          ldap_entry = nil
          match_count = 0
          @ldap.search(:filter => filter) {|entry| ldap_entry = entry; match_count+=1}
          DeviseLdapNorm::Logger.send("LDAP search yielded #{match_count} matches")
          ldap_entry
        end
      end

      private

      def self.admin
        ldap = Connection.new(:admin => true).ldap

        unless ldap.bind
          DeviseLdapNorm::Logger.send("Cannot bind to admin LDAP user")
          raise DeviseLdapNorm::LdapException, "Cannot connect to admin LDAP user"
        end

        return ldap
      end

      def find_ldap_user(ldap)
        DeviseLdapNorm::Logger.send("Finding user: #{dn}")
        ldap.search(:base => dn, :scope => Net::LDAP::SearchScope_BaseObject).try(:first)
      end

      def update_ldap(ops)
        operations = []
        if ops.is_a? Hash
          ops.each do |key,value|
            operations << [:replace,key,value]
          end
        elsif ops.is_a? Array
          operations = ops
        end

        if ::Devise.ldap_use_admin_to_bind
          privileged_ldap = Connection.admin
        else
          authenticate!
          privileged_ldap = self.ldap
        end

        DeviseLdapNorm::Logger.send("Modifying user #{dn}")
        privileged_ldap.modify(:dn => dn, :operations => operations)
      end
    end
  end
end
