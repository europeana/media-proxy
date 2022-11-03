# frozen_string_literal: true

require 'europeana/media_proxy/version'
require 'logger'

module Europeana
  # HTTP proxy for Europeana web resources
  module MediaProxy
    autoload :App, 'europeana/media_proxy/app'
    autoload :Errors, 'europeana/media_proxy/errors'
    autoload :Proxy, 'europeana/media_proxy/proxy'
    autoload :RobotsTxt, 'europeana/media_proxy/robots_txt'

    class << self
      # @!attribute [r] logger
      #   @return [Logger] Logger for proxy actitivies
      attr_accessor :logger

      # Plain text response for a given HTTP status code
      #
      # @param status_code [Fixnum] HTTP status code
      # @return [Array] {Rack} response triplet
      def response_for_status_code(status_code)
        [status_code, { 'Content-Type' => 'text/plain' },
         [http_status(status_code)]]
      end

      def http_status(code)
        Rack::Utils::HTTP_STATUS_CODES[code]
      end
    end

    self.logger = Logger.new(STDOUT)
    logger.progname = '[Europeana::MediaProxy]'
  end
end
