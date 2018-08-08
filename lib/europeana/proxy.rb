# frozen_string_literal: true

require 'europeana/proxy/version'

module Europeana
  ##
  # HTTP proxy for Europeana web resources
  module Proxy
    autoload :Errors, 'europeana/proxy/errors'
    autoload :Media, 'europeana/proxy/media'

    class << self
      attr_accessor :logger
    end

    self.logger = Logger.new(STDOUT)
    logger.progname = '[Europeana::Proxy]'
  end
end
