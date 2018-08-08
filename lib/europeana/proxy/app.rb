# frozen_string_literal: true

require 'sinatra'

module Europeana
  module Proxy
    # Sinatra app to respond to media proxy requests
    class App < Sinatra::Base
      configure do
        set :permitted_api_urls,
            ENV['PERMITTED_API_URLS'].present? ? ENV['PERMITTED_API_URLS'].split(',').map(&:strip) : []
        set :raise_exception_classes,
            settings.production? ? [] : [ArgumentError, StandardError]
        set :streaming, (ENV['DISABLE_STREAMING'] != '1')
      end

      use Rack::CommonLogger, Europeana::Proxy.logger
      use Europeana::Proxy::Media,
          permitted_api_urls: settings.permitted_api_urls,
          raise_exception_classes: settings.raise_exception_classes,
          streaming: settings.streaming

      if ENV['CORS_ORIGINS']
        require 'rack/cors'
        use Rack::Cors do
          allow do
            origins ENV['CORS_ORIGINS'].split(' ')
            resource '/*', headers: :any, methods: %i(get head options),
                           expose: ['Content-Length']
          end
        end
      end

      get '/' do
        Europeana::Proxy::Media.response_for_status_code(200)
      end
    end
  end
end
