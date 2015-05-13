# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'europeana/proxy/version'

Gem::Specification.new do |spec|
  spec.name          = 'europeana-proxy'
  spec.version       = Europeana::Proxy::VERSION
  spec.license       = 'EUPL V.1.1'
  spec.authors       = ['Richard Doe']
  spec.email         = ['richard.doe@rwdit.net']

  spec.summary       = 'Rack proxy to download Europeana record edm:isShownBy targets'
  spec.homepage      = 'http://github.com/europeana/europeana-proxy-ruby'

  spec.files         = Dir['lib/**/*.rb'] + Dir['spec/**/*']
  spec.files         += ['config.ru', 'Gemfile', 'LICENSE.md', 'Rakefile',
                         'README.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency 'europeana-api', '~> 0.3.1'
  spec.add_dependency 'rack-proxy', '~> 0.5'
  spec.add_dependency 'mime-types', '~> 2.4'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.2'
end
