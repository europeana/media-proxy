module Europeana
  module Proxy
    module Errors
      ##
      # URL to proxy is invalid
      class BadUrl < StandardError
        def message
          "Bad URL \"#{super}\""
        end
      end

      ##
      # No URL to proxy
      class NoUrl < StandardError
        def message
          super || 'No URL'
        end
      end

      ##
      # Maximum number of redirects exceeded
      class TooManyRedirects < StandardError
        def message
          "Too many redirects; max is #{super}"
        end
      end

      ##
      # Media type is invalid
      class UnknownMediaType < StandardError
        def message
          "Unknown media type \"#{super}\""
        end
      end
    end
  end
end
