# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module Response
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

          response = if (200..299).cover?(status_code)
                       rewrite_success_response(triplet, env)
                     else
                       # FIXME: would we ever reach here given other error handling?
                       response_for_status_code(status_code)
                     end

          debug_profile?(env) ? debug_response_for_triplet(response) : response
        end

        def rewrite_response(_triplet)
          fail StandardError, "Use ##{rewrite_response_with_env}, not ##{rewrite_response}"
        end

        protected

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
      end
    end
  end
end
