# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'europeana/api'
require 'mime/types'
require 'rack/proxy'
require 'uri'

module Europeana
  module Proxy
    # Rack middleware to proxy Europeana record media resources
    class Media < Rack::Proxy
      # Default maximum number of redirects to follow.
      # Can be overriden in `opts` argument passed to +#initialize+.
      DEFAULT_MAX_REDIRECTS = 3

      # @!attribute [rw] max_redirects
      #   @return [Integr] Maximum number of redirects to follow, defaults to
      #     +DEFAULT_MAX_REDIRECTS+
      attr_accessor :max_redirects

      # @!attribute [rw] permitted_api_urls
      #   @return [Array<String>] API URLs to permit in +api_url+ parameter,
      #     to which +Europeana::API.url+ is always added
      attr_accessor :permitted_api_urls

      # @!attribute [rw] raise_exception_classes
      #   @return [Array<Class>] Exception classes to raise instead of logging
      #     and responding with plain text HTTP error responses, e.g. in dev env
      attr_accessor :raise_exception_classes

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
      delegate :logger, to: Europeana::Proxy

      # @param app Rack app
      # @param opts [Hash] options
      # @option opts [Integer] :max_redirects Maximum number of redirects to
      #   follow, defaults to +DEFAULT_MAX_REDIRECTS+
      # @options opts [Array<String>] :permitted_api_urls API URLs to permit
      #   in +api_url+ parameter, to which +Europeana::API.url+ is always added
      # @options opts [Array<Class>] :raise_exception_classes Exception classes
      #   to raise instead of logging and responding with plain text HTTP error
      #   responses, e.g. in dev env
      def initialize(app, opts = {})
        self.max_redirects = opts.delete(:max_redirects) || DEFAULT_MAX_REDIRECTS
        self.permitted_api_urls = opts.delete(:permitted_api_urls) || []
        self.permitted_api_urls << Europeana::API.url
        self.permitted_api_urls.uniq!
        self.raise_exception_classes = opts.delete(:raise_exception_classes) || []

        opts[:streaming] ||= true

        super(opts)
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
          init_app_env_store(env)
          if proxy?(env)
            rewrite_response_with_env(perform_request(rewrite_env(env)), env)
          else
            @app.call(env)
          end
        end
      end

      # Init the app's data store in the env before processing a request
      #
      # @param env [Hash] request env
      # @return [Hash] env with additional middleware-specific values
      def init_app_env_store(env)
        env['app.request'] = Rack::Request.new(env)
        env['app.params'] = env['app.request'].params
        env['app.urls'] = []
        env['app.record_id'] = nil
        env['app.redirects'] = 0
        env
      end

      # Should this request be proxied?
      #
      # @param env [Hash] request env
      # @return [Boolean]
      def proxy?(env)
        (env['app.request'].get? || env['app.request'].head?) &&
          !!(env['app.request'].path =~ %r{/[0-9]+/[a-zA-Z0-9_]+\z})
      end

      # Rewrite request env for edm:isShownBy target URL
      #
      # @param env [Hash] request env
      # @return [Hash] rewritten request env
      def rewrite_env(env)
        env['app.record_id'] = env['REQUEST_PATH']

        if env['app.params']['api_url']
          fail Errors::AccessDenied, 'Requested API url is invalid' unless permitted_api_urls.include?(env['app.params']['api_url'])
        end

        search_response = api_search_response(env)
        requested_view = view_url_to_proxy(env, search_response)
        rewrite_env_for_url(env, requested_view)
      end

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
        if env['app.redirects'] > max_redirects
          fail Errors::TooManyRedirects, max_redirects
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

      def rescue_call_errors
        yield
      rescue StandardError => exception
        # Log all errors, then handle them individually below
        logger.error(exception.message)
        raise if raise_exception_classes.include?(exception.class)
        error_response_for_exception(exception)
      end

      def error_response_for_exception(exception)
        case exception
        when ArgumentError
          response_for_status_code(500)
        when Europeana::API::Errors::RequestError
          response_for_status_code(400)
        when Errors::AccessDenied
          response_for_status_code(403)
        when Europeana::API::Errors::ResourceNotFoundError, Errors::UnknownView
          response_for_status_code(404)
        when Europeana::API::Errors::ResponseError, Errors::UnknownMediaType,
             Errors::TooManyRedirects, Errno::ENETUNREACH
          response_for_status_code(502) # Bad Gateway!
        when Errno::ETIMEDOUT
          response_for_status_code(504) # Gateway Timeout
        when StandardError
          response_for_status_code(500)
        end
      end
    end
  end
end
