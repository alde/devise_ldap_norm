# Devise LDAP No ORM

## Why this fork?
This is a fork of https://github.com/cschiewek/devise_ldap_authenticatable, to get away from the need to have an ActiveRecord backing.

## Prerequisites
 * devise ~> 3.0.0 (which requires rails ~> 4.0)
 * net-ldap ~> 0.3.1

## Usage
In the Gemfile for your application:

    gem "devise_ldap_norm"

To get the latest version, pull directly from github instead of the gem:

    gem "devise_ldap_norm", :git => "git://github.com/alde/devise_ldap_norm.git"


## Setup
### Run the rails generators for devise
(please check the [devise](http://github.com/plataformatec/devise) documents for further instructions)

    rails generate devise:install
    rails generate devise MODEL_NAME

### Run the rails generator for `devise_ldap_norm`

    rails generate devise_ldap_norm:install [options]

This will install the ldap.yml, update the devise.rb initializer, and update your user model. There are some options you can pass to it:

Options:

    [--user-model=USER_MODEL]  # Model to update
                               # Default: user
    [--update-model]           # Update model to change from database_authenticatable to ldap_authenticatable
                               # Default: true
    [--add-rescue]             # Update Application Controller with rescue_from for DeviseLdapAuthenticatable::LdapException
                               # Default: true
    [--advanced]               # Add advanced config options to the devise initializer

### Ensure the timeout of your session
Edit your config/initializers/session_store.rb to include an expiry:

    Rails.application.config.session_store :cookie_store, key: '__app_session', :expire_after => Rails.application.config.devise.timeout_in

### Protect from session hijacking
Add a before_action validation to ApplicationController:

Sample:

    class ApplicationController < ActionController::Base

      before_action :validate_origin

      def validate_origin
        if current_user && current_user.remote_ip != request.remote_ip
            Rails.logger.warn("Remote IP for #{current_user.email} does not match session data.")
            session.destroy
        end
      end
    end


### Modify your user model
Since there is no longer a need for ActiveRecord, modify the User model.

Sample model:


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

      def remote_ip
        @data['remote_ip']
      end

      def email
        @data['email']
      end
    end


Development guide
------------

Devise LDAP Authenticatable uses a running OpenLDAP server to do automated acceptance tests. You'll need the executables `slapd`, `ldapadd`, and `ldapmodify`.

On OS X, this is available out of the box.

To start hacking on `devise_ldap_norm`, clone the github repository, start the test LDAP server, and run the rake test task:

    git clone https://github.com/alde/devise_ldap_norm.git
    cd devise_ldap_norm
    bundle install

    # in a separate console or backgrounded
    ./spec/ldap/run-server

    bundle exec rake spec

References
----------
* [OpenLDAP](http://www.openldap.org/)
* [Devise](http://github.com/plataformatec/devise)
* [Warden](http://github.com/hassox/warden)

Released under the MIT license

Copyright (c) 2015 [Rickard Dybeck](https://github.com/alde)

Based on devise_ldap_authenticatable
Copyright (c) 2012 [Curtis Schiewek](https://github.com/cschiewek), [Daniel McNevin](https://github.com/dpmcnevin), [Steven Xu](https://github.com/cairo140)
