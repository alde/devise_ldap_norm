# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "devise_ldap_norm/version"

Gem::Specification.new do |s|
  s.name     = 'devise_ldap_norm'
  s.version  = DeviseLdapNorm::VERSION.dup
  s.platform = Gem::Platform::RUBY
  s.summary  = 'Devise extension to allow authentication via LDAP'
  s.email = 'rickard@alde.nu'
  s.homepage = 'https://github.com/alde/devise_ldap_norm'
  s.description = s.summary
  s.authors = ['Rickard Dybeck', 'Curtis Schiewek', 'Daniel McNevin', 'Steven Xu']
  s.license = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('devise')
  s.add_dependency('net-ldap')

  s.add_development_dependency 'rake', '>= 0.9'
  s.add_development_dependency 'rdoc', '>= 3'
  s.add_development_dependency 'rails', '>= 4.0'
  s.add_development_dependency 'factory_girl_rails', '~> 4.5.0'
  s.add_development_dependency 'factory_girl', '~> 4.5.0'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'launchy'
end
