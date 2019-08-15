# frozen_string_literal: true

module Europeana
  module MediaProxy
    # Rack app to respond to media proxy requests
    class App
      attr_accessor :permitted_api_urls
      attr_accessor :raise_exceptions
      attr_accessor :streaming

      delegate :response_for_status_code, to: Europeana::MediaProxy

      def self.build
        Rack::Builder.new do
          app = Europeana::MediaProxy::App.new

          use Rack::CommonLogger, Europeana::MediaProxy.logger

          if ENV['CORS_ORIGINS']
            require 'rack/cors'
            use Rack::Cors do
              allow do
                origins ENV['CORS_ORIGINS'].split(' ')
                resource '*', headers: :any, methods: %i(get head options),
                               expose: ['Content-Length']
              end
            end
          end

          use Europeana::MediaProxy::Proxy,
              permitted_api_urls: app.permitted_api_urls,
              raise_exceptions: app.raise_exceptions,
              streaming: app.streaming

          run app
        end
      end

      def initialize
        self.permitted_api_urls = if ENV['PERMITTED_API_URLS'].present?
                                    ENV['PERMITTED_API_URLS'].split(',').map(&:strip)
                                  else
                                    []
                                  end

        self.raise_exceptions = (ENV['RAISE_EXCEPTIONS'] == '1')

        self.streaming = (ENV['DISABLE_STREAMING'] != '1')
      end

      def call(env)
        request = Rack::Request.new(env)
        status = request.path == '/' ? 200 : 404
        response_for_status_code(status)
      end
    end
  end
end
