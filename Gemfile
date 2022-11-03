# frozen_string_literal: true

source 'https://rubygems.org'

gem 'activesupport'
gem 'addressable'
gem 'elastic-apm'
gem 'europeana-api'
gem 'http_logger'
gem 'mime-types'
gem 'puma'
gem 'rack'
gem 'rack-cors', '~> 1.0.3'
gem 'rack-proxy'
gem 'rake'

group :development, :test do
  gem 'dotenv'
  gem 'rspec'
  gem 'rubocop', '~> 0.53', require: false
end

group :development do
  gem 'foreman'
end

group :test do
  gem 'daemons'
  gem 'rack-test'
  gem 'roda'
  gem 'simplecov', require: false
end
