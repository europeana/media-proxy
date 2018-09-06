# frozen_string_literal: true

require File.expand_path('config/boot', __dir__)

require 'europeana/media_proxy/app'
run Europeana::MediaProxy::App.build
