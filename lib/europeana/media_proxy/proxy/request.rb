# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module Request
        protected

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
      end
    end
  end
end
