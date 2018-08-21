# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module Env
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

        protected

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
      end
    end
  end
end
