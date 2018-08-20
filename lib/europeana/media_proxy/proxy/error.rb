# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module Error
        # @!attribute [rw] raise_exception_classes
        #   @return [Array<Class>] Exception classes to raise instead of logging
        #     and responding with plain text HTTP error responses, e.g. in dev env
        attr_accessor :raise_exception_classes

        protected

        def rescue_call_errors(env)
          yield
        rescue StandardError => exception
          # Log all errors, then handle them individually below
          logger.error(exception.message)
          raise if raise_exception_classes.include?(exception.class)
          if debug_profile?(env)
            debug_response_for_exception(exception)
          else
            error_response_for_exception(exception)
          end
        end

        def error_response_for_exception(exception)
          response_for_status_code(status_code_for_exception(exception))
        end

        def status_code_for_exception(exception)
          case exception
          when ArgumentError
            500
          when Europeana::API::Errors::RequestError
            400
          when Errors::AccessDenied
            403
          when Europeana::API::Errors::ResourceNotFoundError, Errors::UnknownView
            404
          when Europeana::API::Errors::ResponseError, Errors::UnknownMediaType,
               Errors::TooManyRedirects, Errno::ENETUNREACH
            502 # Bad Gateway!
          when Errno::ETIMEDOUT
            504 # Gateway Timeout
          when StandardError
            500
          end
        end
      end
    end
  end
end
