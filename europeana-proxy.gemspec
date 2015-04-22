# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'europeana/proxy/version'

Gem::Specification.new do |spec|
  spec.name          = 'europeana-proxy'
  spec.version       = Europeana::Proxy::VERSION
  spec.authors       = ['Richard Doe']
  spec.email         = ['richard.doe@rwdit.net']

  spec.summary       = 'Rack proxy to download Europeana record edm:isShownBy targets'
  spec.homepage      = 'http://github.com/europeana/europeana-proxy-ruby'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_development_dependency 'europeana-api'
  spec.add_development_dependency 'puma'
  spec.add_development_dependency 'rack-proxy'
  spec.add_development_dependency 'mime-types'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
end
