# frozen_string_literal: true

require 'rack'
require 'rack/handler/puma'
require_relative 'media_app'

Rack::Handler::Puma.run(MediaApp.freeze.app, :Port => 9393)
