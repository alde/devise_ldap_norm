require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LdapNorm < Authenticatable
      def authenticate!
        resource = mapping.to.find_for_ldap_authentication(authentication_hash.merge(password: password, remote_ip: request.remote_ip))

        if resource && validate(resource) { resource.valid_ldap_authentication?(password) }
          remember_me(resource)
          resource.after_ldap_authentication
          success!(resource)
        else
          return fail(:invalid)
        end
      end
    end
  end
end

Warden::Strategies.add(:ldap_norm, Devise::Strategies::LdapNorm)
