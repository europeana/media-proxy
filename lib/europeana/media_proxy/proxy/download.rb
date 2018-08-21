# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module Download
        protected

        # Rewrite response for application/octet-stream content-type
        #
        # application/octet-stream = "arbitrary binary data" [RFC 2046], so
        # look to file extension (if any) in upstream URL for a clue as to what
        # the file is.
        #
        # @param triplet [Array] Rack response triplet
        # @return [Array] Rewritten Rack response triplet
        def download_octet_stream_response(triplet, env)
          extension = octet_stream_response_extension(env)
          media_type = MIME::Types.type_for(extension).first
          unless media_type.nil?
            triplet[1]['content-type'] = media_type.content_type
          end
          download_response(triplet, 'application/octet-stream', env,
                            extension: extension.blank? ? nil : extension,
                            media_type: media_type.blank? ? nil : media_type)
        end

        def octet_stream_response_extension(env)
          File.extname(URI.parse(env['app.urls'].last).path).tap do |extension|
            extension = extension[1..-1] unless extension == ''
            extension.downcase!
          end
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
          # Prevent duplicate headers on some text/html documents
          triplet[1]['Content-Length'] = triplet[1]['content-length']
          triplet
        end

        def content_disposition(env)
          env['app.params']['disposition'] == 'inline' ? 'inline' : 'attachment'
        end
      end
    end
  end
end
