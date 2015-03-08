class ApplicationController < ActionController::Base
  rescue_from DeviseLdapNorm::LdapException do |exception|
    render :text => exception, :status => 500
  end
  protect_from_forgery
  layout 'application'
end
