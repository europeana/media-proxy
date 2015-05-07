require 'active_support/core_ext/hash' # @todo fix this in europeana-api
require 'europeana/api'
require 'mime/types'
require 'rack/proxy'
require 'uri'

module Europeana
  module Proxy
    # @todo stress test
    # @todo only respond to / proxy GET requests?
    class EdmIsShownBy < Rack::Proxy
      MAX_REDIRECTS = 3

      class << self
        def response_for_status_code(status_code)
          [status_code, { 'Content-Type' => 'text/plain' },
            [Rack::Utils::HTTP_STATUS_CODES[status_code]]
          ]
        end
      end

      attr_reader :logger

      def initialize(app, opts = {})
        @logger = opts.fetch(:logger, Logger.new(STDOUT))
        @logger.progname ||= 'Europeana::Proxy'
        @max_redirects = opts.fetch(:max_redirects, MAX_REDIRECTS)
        super(opts)
        @app = app
      end

      def call(env)
        rescue_call_errors do
          # call super if we want to proxy, otherwise just handle regularly via call
          (proxy?(env) && init && super) || @app.call(env)
        end
      end

      def init
        GC.start
        @urls = []
        @record_id = nil
        @redirects = 0
      end

      # @todo move into Rack/Sinatra app?
      def proxy?(env)
        match = env['REQUEST_PATH'].match(/^\/([^\/]*?)\/([^\/]*)$/)
        !match.nil?
      end

      def rewrite_env(env)
        @record_id = env['REQUEST_PATH']
        edm = Europeana::API.record(@record_id)['object']
        edm_is_shown_by = edm['aggregations'].collect { |a| a['edmIsShownBy'] }.first
        if edm_is_shown_by.blank?
          fail Errors::NoUrl, "No edm:isShownBy URL for record \"#{@record_id}\""
        end
        rewrite_env_for_url(env, edm_is_shown_by)
      end

      def rewrite_response(triplet)
        status_code = triplet.first.to_i
        case status_code
        when 200..299
          content_type = triplet[1]['content-type']
          content_type = content_type.first if content_type.is_a?(Array)
          content_type = content_type.split(/; */).first

          if content_type == 'text/html'
            # don't download HTML; redirect to it
            triplet = [301, { 'location' => @urls.last }, ['']]
          else
            media_type = MIME::Types[content_type].first
            fail Errors::UnknownMediaType, content_type if media_type.nil?
            extension = media_type.preferred_extension
            filename = @record_id.sub('/', '').gsub('/', '_') + '.' + extension
            triplet[1]['Content-Disposition'] = "attachment; filename=#{filename}"
            # prevent duplicate headers on some text/html documents
            triplet[1]['Content-Length'] = triplet[1]['content-length']
          end
        else
          triplet = response_for_status_code(status_code)
        end
        triplet
      end

      def response_for_status_code(status_code)
        self.class.response_for_status_code(status_code)
      end

      protected

      def rewrite_env_for_url(env, url)
        logger.info "URL: #{url}"

        # Keep a stack of URLs requested
        @urls << url

        # app server may already be proxied; don't let Rack know
        env.reject! { |k, _v| k.match(/^HTTP_X_/) } if @urls.size == 1

        u = URI.parse(url)
        fail Errors::BadUrl, url unless u.host.present?

        env['HTTP_HOST'] = u.host
        env['HTTP_X_FORWARDED_PORT'] = u.port.to_s
        env['REQUEST_PATH'] = env['PATH_INFO'] = u.path || ''
        env['QUERY_STRING'] = u.query || ''
        env['HTTPS'] = 'on' if u.scheme == 'https'
        env
      end

      def perform_redirect(env, url)
        @redirects += 1
        if @redirects > @max_redirects
          fail Errors::TooManyRedirects, @max_redirects
        end

        url = url.first if url.is_a?(Array)
        url = absolute_redirect_url(url)
        perform_request(rewrite_env_for_url(env, url))
      end

      def perform_request(env)
        triplet = super
        status_code = triplet.first.to_i
        logger.info("HTTP status code: #{status_code}")

        case status_code
        when 300..399
          perform_redirect(env, triplet[1]['location'])
        else
          triplet
        end
      end

      def absolute_redirect_url(url_or_path)
        return url_or_path unless url_or_path[0] == '.'
        # relative redirect: keep previous host; resolve path from previous url
        u = URI.parse(url_or_path)
        up = URI.parse(@urls[-1])
        u.path = File.expand_path(u.path, File.dirname(up.path))
        up.merge(u).to_s
      end

      # @todo move error handling out of this class, into the Rack/Sinatra app
      def rescue_call_errors
        begin
          yield
        rescue Exception => e
          # log all errors, then handle them individually below
          logger.error(e.message)
          raise
        end
      rescue Europeana::API::Errors::RequestError => e
        if e.message.match(/^Invalid record identifier/)
          response_for_status_code(404)
        else
          response_for_status_code(400)
        end
      rescue Errors::NoUrl
        response_for_status_code(404)
      rescue Europeana::API::Errors::ResponseError, Errors::UnknownMediaType,
        Errors::TooManyRedirects, Errno::ENETUNREACH
        response_for_status_code(502) # Bad Gateway!
      rescue Errno::ETIMEDOUT
        response_for_status_code(504) # Gateway Timeout
      rescue Exception => e
        raise if ['development', 'test'].include?(ENV['RACK_ENV'])
        response_for_status_code(500)
      end
    end
  end
end
