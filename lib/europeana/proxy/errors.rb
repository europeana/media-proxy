module Europeana
  module Proxy
    module Errors
      ##
      # URL to media resource is invalid, i.e. not a URL
      class BadUrl < StandardError
        def message
          "Bad URL \"#{super}\""
        end
      end

      ##
      # URL is not known for the requested record
      class UnknownView < StandardError
        def message
          super || 'Unknown view URL'
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
