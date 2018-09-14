# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'rack/test'
require 'mimic'
require 'support/external_responses'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'europeana/media_proxy'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.before(:suite) do
    setup_external_responses
  end
end
