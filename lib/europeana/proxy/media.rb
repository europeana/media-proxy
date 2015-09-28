require 'active_support/core_ext/object/blank'
require 'europeana/api'
require 'mime/types'
require 'rack/proxy'
require 'uri'

module Europeana
  module Proxy
    ##
    # Rack middleware to proxy Europeana record media resources
    #
    # @todo only respond to / proxy GET requests?
    class Media < Rack::Proxy
      # Default maximum number of redirects to follow.
      # Can be overriden in {opts} passed to {#initialize}.
      MAX_REDIRECTS = 3

      # @!attribute [r] record_id
      #   @return [String] Europeana record ID of the requested object
      attr_reader :record_id

      class << self
        ##
        # Plain text response for a given HTTP status code
        #
        # @param status_code [Fixnum] HTTP status code
        # @return [Array] {Rack} response triplet
        def response_for_status_code(status_code)
          [status_code, { 'Content-Type' => 'text/plain' },
           [Rack::Utils::HTTP_STATUS_CODES[status_code]]
          ]
        end
      end

      # @!attribute [r] logger
      #   @return [Logger] Logger for proxy actitivies
      attr_reader :logger

      # @param app Rack app
      # @param opts [Hash] options
      # @option opts [Fixnum] :max_redirects Maximum number of redirects to
      #   follow
      def initialize(app, opts = {})
        @logger = opts.fetch(:logger, Logger.new(STDOUT))
        @logger.progname ||= '[Europeana::Proxy]'
        @max_redirects = opts.fetch(:max_redirects, MAX_REDIRECTS)
        super(opts)
        @app = app
      end

      ##
      # Proxy a request
      #
      # @param env [Hash] request env
      # @return [Array] Rack response triplet
      def call(env)
        rescue_call_errors do
          if proxy?(env)
            reset
            @params = Rack::Request.new(env).params
            super
          else
            @app.call(env)
          end
        end
      end

      ##
      # Reset the proxy handler before a new request
      #
      # @return [NilClass]
      def reset
        GC.start
        @urls = []
        @record_id = nil
        @redirects = 0
        nil
      end

      ##
      # Should this request be proxied?
      #
      # @param env [Hash] request env
      # @return [Boolean]
      # @todo move into Rack/Sinatra app?
      def proxy?(env)
        match = env['REQUEST_PATH'].match(%r{^/([^/]*?)/([^/]*)$})
        !match.nil?
      end

      ##
      # Rewrite request env for edm:isShownBy target URL
      #
      # @param env [Hash] request env
      # @return [Hash] rewritten request env
      def rewrite_env(env)
        @record_id = env['REQUEST_PATH']
        edm = Europeana::API.record(@record_id)['object']

        record_views = ([record_edm_is_shown_by(edm)] + record_has_view(edm)).compact.flatten
        requested_view = @params['view'].present? ? @params['view'] : record_edm_is_shown_by(edm)

        unless record_views.include?(requested_view)
          fail Errors::UnknownView,
               "Unknown view URL for record \"#{@record_id}\": \"#{@requested_view}\""
        end
        rewrite_env_for_url(env, requested_view)
      end

      def record_edm_is_shown_by(record)
        @record_edm_is_shown_by ||= begin
          record['aggregations'].map do |aggregation|
            aggregation['edmIsShownBy']
          end.first
        end
      end

      def record_has_view(record)
        @record_has_view ||= begin
          has_view = record['aggregations'].map do |aggregation|
            aggregation['hasView']
          end.flatten
        end
      end

      ##
      # Rewrite the response
      #
      # Where the HTTP status code indicates success, delegates to
      # {#rewrite_success_response}. Otherwise, delegates to
      # {#response_for_status_code} for a plain text response.
      #
      # @param triplet [Array] Rack response triplet
      # @return [Array] Rewritten Rack response triplet
      def rewrite_response(triplet)
        status_code = triplet.first.to_i
        if (200..299).include?(status_code)
          rewrite_success_response(triplet)
        else
          response_for_status_code(status_code)
        end
      end

      # (see .response_for_status_code)
      def response_for_status_code(status_code)
        self.class.response_for_status_code(status_code)
      end

      protected

      ##
      # Rewrite a successful response
      #
      # (see #rewrite_response)
      def rewrite_success_response(triplet)
        content_type = content_type_from_header(triplet[1]['content-type'])
        case content_type
        when 'text/html'
          # don't download HTML; redirect to it
          return [301, { 'location' => @urls.last }, ['']]
        when 'application/octet-stream'
          application_octet_stream_response(triplet)
        else
          download_response(triplet, content_type)
        end
      end

      # @param header [String,Array<String>] content-type header
      # @return [String] just the (first) media type part of the header
      def content_type_from_header(header)
        [header].flatten.first.split(/; */).first
      end

      ##
      # Rewrite response for application/octet-stream content-type
      #
      # application/octet-stream = "arbitrary binary data" [RFC 2046], so
      # look to file extension (if any) in upstream URL for a clue as to what
      # the file is.
      #
      # @param triplet [Array] Rack response triplet
      # @return [Array] Rewritten Rack response triplet
      def application_octet_stream_response(triplet)
        extension = File.extname(URI.parse(@urls.last).path)
        extension.sub!(/^\./, '')
        extension.downcase!
        media_type = MIME::Types.type_for(extension).first
        unless media_type.nil?
          triplet[1]['content-type'] = media_type.content_type
        end
        download_response(triplet, 'application/octet-stream',
                          extension: extension.blank? ? nil : extension,
                          media_type: media_type.blank? ? nil : media_type)
      end

      ##
      # Rewrite response to force file download
      #
      # @param triplet [Array] Rack response triplet
      # @param content_type [String] File content type (from response header)
      # @param opts [Hash] Rewrite options
      # @option opts [MIME::Type] :media_type Media type for download, else
      #   detected from {content_type}
      # @option opts [String] :extension File name extension for download, else
      #   calculated from {content_type}
      # @return [Array] Rewritten Rack response triplet
      # @raise [Errors::UnknownMediaType] if the content_type is not known by
      #   {MIME::Types}, e.g. "image/jpg"
      def download_response(triplet, content_type, opts = {})
        media_type = opts[:media_type] || MIME::Types[content_type].first
        fail Errors::UnknownMediaType, content_type if media_type.nil?

        extension = opts[:extension] || media_type.preferred_extension
        filename = @record_id.sub('/', '').gsub('/', '_') + '.' + extension

        triplet[1]['Content-Disposition'] = "#{content_disposition}; filename=#{filename}"
        # prevent duplicate headers on some text/html documents
        triplet[1]['Content-Length'] = triplet[1]['content-length']
        triplet
      end

      def content_disposition
        @params['disposition'] == 'inline' ? 'inline' : 'attachment'
      end

      def rewrite_env_for_url(env, url)
        logger.info "URL: #{url}"

        # Keep a stack of URLs requested
        @urls << url

        # app server may already be proxied; don't let Rack know
        env.reject! { |k, _v| k.match(/^HTTP_X_/) } if @urls.size == 1

        uri = URI.parse(url)
        fail Errors::BadUrl, url unless uri.host.present?

        rewrite_env_for_uri(env, uri)
      end

      def rewrite_env_for_uri(env, uri)
        env['HTTP_HOST'] = uri.host
        env['HTTP_X_FORWARDED_PORT'] = uri.port.to_s
        env['REQUEST_PATH'] = env['PATH_INFO'] = uri.path || ''
        env['QUERY_STRING'] = uri.query || ''
        env['HTTPS'] = 'on' if uri.scheme == 'https'
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
        when 300..303, 305..399
          perform_redirect(env, triplet[1]['location'])
        else
          triplet
        end
      end

      def absolute_redirect_url(url_or_path)
        u = URI.parse(url_or_path)
        return url_or_path if u.host.present?

        # relative redirect: keep previous host; resolve path from previous url
        up = URI.parse(@urls[-1])
        unless u.path[0] == '/'
          u.path = File.expand_path(u.path, File.dirname(up.path))
        end
        up.merge(u).to_s
      end

      # @todo move error handling out of this class, into the Rack/Sinatra app
      def rescue_call_errors
        begin
          yield
        rescue StandardError => e
          # log all errors, then handle them individually below
          logger.error(e.message)
          raise
        end
      rescue ArgumentError => e
        if e.message.match(/^Invalid Europeana record ID/)
          response_for_status_code(404)
        elsif %w(development test).include?(ENV['RACK_ENV'])
          raise
        else
          response_for_status_code(500)
        end
      rescue Europeana::API::Errors::RequestError => e
        if e.message.match(/^Invalid record identifier/)
          response_for_status_code(404)
        else
          response_for_status_code(400)
        end
      rescue Errors::UnknownView
        response_for_status_code(404)
      rescue Europeana::API::Errors::ResponseError, Errors::UnknownMediaType,
             Errors::TooManyRedirects, Errno::ENETUNREACH
        response_for_status_code(502) # Bad Gateway!
      rescue Errno::ETIMEDOUT
        response_for_status_code(504) # Gateway Timeout
      rescue StandardError
        raise if %w(development test).include?(ENV['RACK_ENV'])
        response_for_status_code(500)
      end
    end
  end
end
