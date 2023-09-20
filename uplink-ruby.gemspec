# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'uplink-ruby'
  s.version     = '1.8.0'
  s.summary     = 'libuplink bindings for ruby'
  s.description = 'Ruby bindings to the libuplink C Storj API library'
  s.authors     = ['Your Data Inc']
  s.homepage    = 'https://github.com/storj-thirdparty/uplink-ruby'
  s.license     = 'MIT'
  s.files       = Dir['lib/**/*.rb']
  s.required_ruby_version = '>= 2.6.0'
  s.add_runtime_dependency 'ffi', '~> 1.15.0'
  s.add_development_dependency 'rspec', '~> 3.12.0'
end
