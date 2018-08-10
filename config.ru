# frozen_string_literal: true

require File.expand_path('config/boot', __dir__)

require 'europeana/proxy/app'
run Europeana::Proxy::App.build
