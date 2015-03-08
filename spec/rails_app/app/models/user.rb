class User
  include ActiveModel::Validations
  extend ActiveModel::Callbacks
  extend Devise::Models

  define_model_callbacks :validation

  devise :ldap_norm, :rememberable

  def initialize (id)
    @data = HashWithIndifferentAccess.new
    @id = id
  end

  def []=(key, value)
    @data[key] = value
  end

  def [](key)
    @data[key]
  end

  def email
    @data['email']
  end

  def email=(email)
    @data['email'] = email
  end
end
