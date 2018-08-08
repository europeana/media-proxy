# frozen_string_literal: true

source 'https://rubygems.org'

gem 'activesupport', '~> 4.2.3'
gem 'europeana-api', '~> 1.0.0'
gem 'http_logger'
gem 'mime-types', '~> 2.4'
gem 'puma', '>= 2.0.0'
gem 'rack', '~> 1.6.4'
# Pending https://github.com/cyu/rack-cors/pull/107
gem 'rack-cors', '~> 0.4.0', git: 'https://github.com/europeana/rack-cors.git', branch: 'europeana-proxy'
gem 'rack-proxy', '~> 0.5'
gem 'rake', '~> 10.0'
gem 'sinatra'

group :development, :test do
  gem 'dotenv'
  gem 'rspec', '~> 3.2'
  gem 'rubocop', '~> 0.53', require: false
end

group :development do
  gem 'foreman'
end

group :test do
  gem 'simplecov', require: false
end
