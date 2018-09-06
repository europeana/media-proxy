# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

ENV['RACK_ENV'] ||= 'development'

require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'])

Dotenv.load if defined?(Dotenv)

require 'europeana/media_proxy'

unless ENV.key?('EUROPEANA_API_KEY')
  Europeana::MediaProxy.logger.fatal('EUROPEANA_API_KEY must be set in the environment')
  exit 1
end

Europeana::API.key = ENV['EUROPEANA_API_KEY']
Europeana::API.url = ENV['EUROPEANA_API_URL'] if ENV['EUROPEANA_API_URL']

# NB: HttpLogger will only log full requests & responses if streaming is disabled
# by env var DISABLE_STREAMING=1
HttpLogger.logger = Europeana::MediaProxy.logger
HttpLogger.log_headers = true
HttpLogger.log_response_body = false
