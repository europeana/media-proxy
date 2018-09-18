# frozen_string_literal: true

require 'rack'
require 'rack/handler/puma'
require_relative 'api_app'

Rack::Handler::Puma.run(APIApp.freeze.app, Port: 9292)
