# frozen_string_literal: true

require 'daemons'

Daemons.run(File.expand_path('boot.rb', __dir__),
            app_name: 'europeana-media-proxy-test-api', backtrace: true)
