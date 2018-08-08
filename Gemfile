# frozen_string_literal: true

source 'https://rubygems.org'

gem 'activesupport', '~> 4.2.3'
gem 'europeana-api', '~> 1.0.0'
gem 'http_logger'
gem 'mime-types', '~> 2.4'
gem 'puma'
gem 'rack'
# Pending release > 1.0.2
gem 'rack-cors', git: 'https://github.com/cyu/rack-cors.git', ref: '51f5c534d968d8ed89ae25f4aa4e93d16cc115f1'
gem 'rack-proxy', '~> 0.5'
gem 'rake'

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
