class User < ActiveRecord::Base
  devise :ldap_norm, :rememberable
end
