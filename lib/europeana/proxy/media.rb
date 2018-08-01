# frozen_string_literal: true

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
           [Rack::Utils::HTTP_STATUS_CODES[status_code]]]
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
        @permitted_api_urls = ENV['PERMITTED_API_URLS'].present? ? ENV['PERMITTED_API_URLS'].split(',').map(&:strip) : []
        @permitted_api_urls << Europeana::API.url

        streaming = (ENV['DISABLE_STREAMING'] != '1')

        super(opts.merge(streaming: streaming))
        @app = app
      end

      ##
      # Proxy a request
      #
      # @param env [Hash] request env
      # @return [Array] Rack response triplet
      def call(env)
        GC.start
        rescue_call_errors do
          if proxy?(env)
            init_app_env_store(env)
            rewrite_response_with_env(perform_request(rewrite_env(env)), env)
          else
            @app.call(env)
          end
        end
      end

      ##
      # Init the app's data store in the env before a new request
      def init_app_env_store(env)
        env['app.params'] = Rack::Request.new(env).params
        env['app.urls'] = []
        env['app.record_id'] = nil
        env['app.redirects'] = 0
        env
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
        env['app.record_id'] = env['REQUEST_PATH']

        if env['app.params']['api_url']
          fail Errors::AccessDenied, 'Requested API url is invalid' unless @permitted_api_urls.include?(env['app.params']['api_url'])
        end

        search_response = api_search_response(env)
        requested_view = view_url_to_proxy(env, search_response)
        rewrite_env_for_url(env, requested_view)
      end

      ##
      # Rewrite the response
      #
      # Where the HTTP status code indicates success, delegates to
      # {#rewrite_success_response}. Otherwise, delegates to
      # {#response_for_status_code} for a plain text response.
      #
      # @param triplet [Array] Rack response triplet
      # @param env Request env
      # @return [Array] Rewritten Rack response triplet
      def rewrite_response_with_env(triplet, env)
        status_code = triplet.first.to_i
        if (200..299).cover?(status_code)
          rewrite_success_response(triplet, env)
        else
          response_for_status_code(status_code)
        end
      end

      # (see .response_for_status_code)
      def response_for_status_code(status_code)
        self.class.response_for_status_code(status_code)
      end

      def rewrite_response(_triplet)
        fail StandardError, "Use ##{rewrite_response_with_env}, not ##{rewrite_response}"
      end

      protected

      def api_search_response(env)
        search_params = { query: api_search_query(env), profile: 'rich', api_url: env['app.params']['api_url'] }
        search_response = Europeana::API.record.search(search_params)

        if search_response['totalResults'].zero?
          unknown_view_msg = if env['app.params']['view'].present?
                               %(Unknown view URL for record "#{env['app.record_id']}": "#{env['app.params']['view']}")
                             else
                               %(Unknown record "#{env['app.record_id']}")
                             end

          fail Errors::UnknownView, unknown_view_msg
        end

        search_response
      end

      def view_url_to_proxy(env, search_response)
        requested_view = if env['app.params']['view'].present?
                           env['app.params']['view']
                         else
                           [search_response['items'].first['edmIsShownBy']].flatten.first
                         end

        if requested_view.blank?
          fail Errors::UnknownView, %(No view for record "#{env['app.record_id']}")
        end

        requested_view
      end

      # Constructs an API search query parameter for view validation
      def api_search_query(env)
        search_query = %(europeana_id:"#{env['app.record_id']}")

        if env['app.params']['view'].present?
          search_query += %< AND (provider_aggregation_edm_isShownBy:"#{env['app.params']['view']}">
          search_query += %< OR provider_aggregation_edm_hasView:"#{env['app.params']['view']}")>
        end

        search_query
      end

      ##
      # Rewrite a successful response
      #
      # (see #rewrite_response)
      def rewrite_success_response(triplet, env)
        content_type = content_type_from_header(triplet[1]['content-type'])
        case content_type
        when 'text/html'
          # don't download HTML; redirect to it
          return [301, { 'location' => env['app.urls'].last }, ['']]
        when 'application/octet-stream', 'binary/octet-stream'
          download_octet_stream_response(triplet, env)
        else
          download_response(triplet, content_type, env)
        end
      end

      # @param header [String,Array<String>] content-type header
      # @return [String] just the (first) media type part of the header
      def content_type_from_header(header)
        first_content_type = [header].flatten.first
        if first_content_type.nil?
          'application/octet-stream'
        else
          first_content_type.split(/; */).first
        end
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
      def download_octet_stream_response(triplet, env)
        extension = File.extname(URI.parse(env['app.urls'].last).path)
        extension.sub!(/^\./, '')
        extension.downcase!
        media_type = MIME::Types.type_for(extension).first
        unless media_type.nil?
          triplet[1]['content-type'] = media_type.content_type
        end
        download_response(triplet, 'application/octet-stream', env,
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
      def download_response(triplet, content_type, env, opts = {})
        media_type = opts[:media_type] || MIME::Types[content_type].first
        fail Errors::UnknownMediaType, content_type if media_type.nil?

        extension = opts[:extension] || media_type.preferred_extension
        filename = env['app.record_id'].sub('/', '').tr('/', '_')
        filename = filename + '.' + extension unless extension.nil?

        triplet[1]['Content-Disposition'] = "#{content_disposition(env)}; filename=#{filename}"
        # prevent duplicate headers on some text/html documents
        triplet[1]['Content-Length'] = triplet[1]['content-length']
        triplet
      end

      def content_disposition(env)
        env['app.params']['disposition'] == 'inline' ? 'inline' : 'attachment'
      end

      def rewrite_env_for_url(env, url)
        logger.info "URL: #{url}"

        # Keep a stack of URLs requested
        env['app.urls'] << url

        # app server may already be proxied; don't let Rack know
        env.reject! { |k, _v| k.match(/^HTTP_X_/) } if env['app.urls'].size == 1

        uri = URI.parse(url)
        fail Errors::BadUrl, url unless uri.host.present?

        rewrite_env_for_uri(env, uri)
      end

      def rewrite_env_for_uri(env, uri)
        env['HTTP_HOST'] = uri.host
        env['HTTP_HOST'] << ":#{uri.port}" unless uri.port == (uri.scheme == 'https' ? 443 : 80)
        env['HTTP_X_FORWARDED_PORT'] = uri.port.to_s
        env['REQUEST_PATH'] = env['PATH_INFO'] = uri.path.blank? ? '/' : uri.path
        env.delete('HTTP_COOKIE')
        env['QUERY_STRING'] = uri.query || ''
        if uri.scheme == 'https'
          env['HTTPS'] = 'on'
        else
          env.delete('HTTPS')
        end

        env
      end

      def perform_redirect(env, url)
        env['app.redirects'] += 1
        if env['app.redirects'] > @max_redirects
          fail Errors::TooManyRedirects, @max_redirects
        end

        url = url.first if url.is_a?(Array)
        url = absolute_redirect_url(env, url)
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

      def absolute_redirect_url(env, url_or_path)
        u = URI.parse(url_or_path)
        return url_or_path if u.host.present?

        # relative redirect: keep previous host; resolve path from previous url
        up = URI.parse(env['app.urls'][-1])
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
        if /^Invalid Europeana record ID/.match?(e.message)
          response_for_status_code(404)
        elsif %w(development test).include?(ENV['RACK_ENV'])
          raise
        else
          response_for_status_code(500)
        end
      rescue Europeana::API::Errors::RequestError
        response_for_status_code(400)
      rescue Errors::AccessDenied
        response_for_status_code(403)
      rescue Europeana::API::Errors::ResourceNotFoundError, Errors::UnknownView
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
