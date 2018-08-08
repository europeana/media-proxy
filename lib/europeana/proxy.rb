# frozen_string_literal: true

require 'europeana/proxy/version'

module Europeana
  # HTTP proxy for Europeana web resources
  module Proxy
    autoload :Errors, 'europeana/proxy/errors'
    autoload :Media, 'europeana/proxy/media'

    class << self
      attr_accessor :logger

      # Plain text response for a given HTTP status code
      #
      # @param status_code [Fixnum] HTTP status code
      # @return [Array] {Rack} response triplet
      def response_for_status_code(status_code)
        [status_code, { 'Content-Type' => 'text/plain' },
         [Rack::Utils::HTTP_STATUS_CODES[status_code]]]
      end
    end

    self.logger = Logger.new(STDOUT)
    logger.progname = '[Europeana::Proxy]'
  end
end
