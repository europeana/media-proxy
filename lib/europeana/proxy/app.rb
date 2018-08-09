# frozen_string_literal: true

module Europeana
  module Proxy
    # Rack app to respond to media proxy requests
    class App
      attr_accessor :permitted_api_urls
      attr_accessor :raise_exception_classes
      attr_accessor :streaming

      delegate :response_for_status_code, to: Europeana::Proxy

      def self.build
        Rack::Builder.new do
          app = Europeana::Proxy::App.new

          use Rack::CommonLogger, Europeana::Proxy.logger
          use Europeana::Proxy::Media,
              permitted_api_urls: app.permitted_api_urls,
              raise_exception_classes: app.raise_exception_classes,
              streaming: app.streaming

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

          run app
        end
      end

      def initialize
        self.permitted_api_urls = if ENV['PERMITTED_API_URLS'].present?
                                    ENV['PERMITTED_API_URLS'].split(',').map(&:strip)
                                  else
                                    []
                                  end

        self.raise_exception_classes = if %w(develop test).include?(ENV['RACK_ENV'])
                                         []
                                       else
                                         [ArgumentError, StandardError]
                                       end

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
