# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      # Debug handling for +Europeana::MediaProxy::Proxy+
      module Debug
        protected

        def debug_profile?(env)
          env['app.params']['profile'] == 'debug'
        end

        def debug_response(status_code, error: nil)
          body = {
            success: (200..299).cover?(status_code),
            status: "#{status_code} #{http_status(status_code)}"
          }
          body[:error] = error unless error.nil?

          [
            status_code,
            { 'Content-Type' => 'application/json' },
            [body.to_json]
          ]
        end

        # @param triplet [Array] Original response triplet
        def debug_response_for_triplet(triplet)
          debug_response(triplet.first.to_i)
        end

        def debug_response_for_exception(exception)
          debug_response(status_code_for_exception(exception), error: exception.message)
        end
      end
    end
  end
end
