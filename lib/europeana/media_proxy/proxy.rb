# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'europeana/api'
require 'mime/types'
require 'rack/proxy'
require 'uri'

module Europeana
  module MediaProxy
    # Rack middleware to proxy Europeana record media resources
    class Proxy < Rack::Proxy
      autoload :API, 'europeana/media_proxy/proxy/api'
      autoload :Debug, 'europeana/media_proxy/proxy/debug'
      autoload :Download, 'europeana/media_proxy/proxy/download'
      autoload :Env, 'europeana/media_proxy/proxy/env'
      autoload :Error, 'europeana/media_proxy/proxy/error'
      autoload :Redirect, 'europeana/media_proxy/proxy/redirect'
      autoload :Request, 'europeana/media_proxy/proxy/request'
      autoload :Response, 'europeana/media_proxy/proxy/response'

      include API
      include Debug
      include Download
      include Env
      include Error
      include Redirect
      include Request
      include Response

      delegate :http_status, :logger, :response_for_status_code, to: Europeana::MediaProxy

      # @param app Rack app
      # @param options [Hash] options
      # @option options [Integer] :max_redirects Maximum number of redirects to
      #   follow, defaults to +DEFAULT_MAX_REDIRECTS+
      # @options options [Array<String>] :permitted_api_urls API URLs to permit
      #   in +api_url+ parameter, to which +Europeana::API.url+ is always added
      # @options options [Boolean] :raise_exceptions Raise exceptions instead of
      #   logging and responding with plain text HTTP error responses
      def initialize(app, options = {})
        opts = options.dup
        self.max_redirects = opts.delete(:max_redirects) || DEFAULT_MAX_REDIRECTS
        self.permitted_api_urls = opts.delete(:permitted_api_urls) || []
        permitted_api_urls << Europeana::API.url
        permitted_api_urls.uniq!
        self.raise_exceptions = opts.delete(:raise_exceptions) || false

        opts[:streaming] ||= true
        opts[:read_timeout] ||= 30

        super(opts)
        @app = app
      end

      # Proxy a request
      #
      # @param env [Hash] request env
      # @return [Array] Rack response triplet
      def call(env)
        GC.start

        init_app_env_store(env)

        rescue_call_errors(env) do
          if proxy?(env)
            rewrite_response_with_env(perform_request(rewrite_env(env)), env)
          else
            @app.call(env)
          end
        end
      end

      # Should this request be proxied?
      #
      # * Only GET and HEAD methods are proxied
      # * Only request paths matching the Europeana record ID format are proxied
      #
      # @param env [Hash] request env
      # @return [Boolean]
      def proxy?(env)
        (env['app.request'].get? || env['app.request'].head?) &&
          !!(env['app.request'].path =~ %r{/[0-9]+/[a-zA-Z0-9_]+\z})
      end
    end
  end
end
