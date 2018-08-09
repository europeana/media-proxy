# frozen_string_literal: true

require 'europeana/proxy/version'
require 'logger'

module Europeana
  # HTTP proxy for Europeana web resources
  module Proxy
    autoload :App, 'europeana/proxy/app'
    autoload :Errors, 'europeana/proxy/errors'
    autoload :Media, 'europeana/proxy/media'

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
         [Rack::Utils::HTTP_STATUS_CODES[status_code]]]
      end
    end

    self.logger = Logger.new(STDOUT)
    logger.progname = '[Europeana::Proxy]'
  end
end
