# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module Redirect
        # Default maximum number of redirects to follow.
        # Can be overriden in `opts` argument passed to +#initialize+.
        DEFAULT_MAX_REDIRECTS = 3

        # @!attribute [rw] max_redirects
        #   @return [Integr] Maximum number of redirects to follow, defaults to
        #     +DEFAULT_MAX_REDIRECTS+
        attr_accessor :max_redirects

        protected

        def perform_redirect(env, url)
          env['app.redirects'] += 1
          if env['app.redirects'] > max_redirects
            fail Errors::TooManyRedirects, max_redirects
          end

          url = url.first if url.is_a?(Array)
          url = absolute_redirect_url(env, url)
          perform_request(rewrite_env_for_url(env, url))
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
      end
    end
  end
end
