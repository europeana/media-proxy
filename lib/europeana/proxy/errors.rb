module Europeana
  module Proxy
    module Errors
      class BadUrl < StandardError
        def message
          "Bad URL: \"#{super}\""
        end
      end

      class NoUrl < StandardError
        def message
          super || 'No URL'
        end
      end

      class TooManyRedirects < StandardError
        def message
          "Too many redirects; max is: #{super}"
        end
      end

      class UnknownMediaType < StandardError
        def message
          "Unknown media type: \"#{super}\""
        end
      end
    end
  end
end
