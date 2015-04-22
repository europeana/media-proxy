require 'rack/proxy'
require 'europeana/api'
require 'active_support/core_ext/hash' # @todo fix this in europeana-api
require 'uri'
require 'mime/types'

module Europeana
  module Proxy
    # @todo stress test
    # @todo monitor memory usage/leakage
    # @todo log actions
    # @todo only respond to / proxy GET requests?
    class EdmIsShownBy < Rack::Proxy
      class << self
        def response_for_status_code(status_code)
          [status_code, { 'Content-Type' => 'text/plain' }, [Rack::Utils::HTTP_STATUS_CODES[status_code]]]
        end
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        # call super if we want to proxy, otherwise just handle regularly via call
        (proxy?(env) && super) || @app.call(env)
      end

      def proxy?(env)
        match = env['REQUEST_PATH'].match(/^\/([^\/]*?)\/([^\/]*)$/)
        !match.nil?
      end

      def rewrite_response(triplet)
        status_code = triplet.first.to_i
        case status_code
        when 200..299
          content_type = triplet[1]['content-type'].split('; ').first
          extension = MIME::Types[content_type].first.preferred_extension
          filename = @record_id.sub('/', '').gsub('/', '_') + '.' + extension
          triplet[1]['Content-Disposition'] = "attachment; filename=#{filename}"
          # prevent duplicate headers on some text/html documents
          triplet[1]['Content-Length'] = triplet[1]['content-length']
          triplet
        else
          response_for_status_code(status_code)
        end
      end

      # @todo handle failures
      def rewrite_env(env)
        @record_id = env['REQUEST_PATH']
        @edm = Europeana::API.record(@record_id)['object']
        edm_is_shown_by = @edm['aggregations'].collect { |a| a['edmIsShownBy'] }.first
        rewrite_env_for_url(env, edm_is_shown_by)
      end

      protected

      def rewrite_env_for_url(env, url)
        # app server may already be proxied; don't let Rack know
        env.reject! { |k, _v| k.match(/^HTTP_X_/) }
        u = URI.parse(url)
        env['HTTP_HOST'] = u.host + ':' + u.port.to_s
        env['QUERY_STRING'] = u.query || ''
        env['REQUEST_PATH'] = env['PATH_INFO'] = u.path || ''
        env['HTTPS'] = 'on' if u.scheme == 'https'
        env
      end

      # @todo limit # of redirects
      def perform_request(env)
        triplet = super
        status_code = triplet.first.to_i
        case status_code
        when 300..399
          redirect = triplet[1]['location']
          perform_request(rewrite_env_for_url(env, redirect))
        else
          triplet
        end
      rescue Errno::ETIMEDOUT
        response_for_status_code(504) # 504 Gateway Timeout
      end

      def response_for_status_code(status_code)
        self.class.response_for_status_code(status_code)
      end
    end
  end
end
