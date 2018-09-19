# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'rack/test'
require 'daemons'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'europeana/media_proxy'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  def app_dir(app)
    File.expand_path("apps/#{app}", __dir__)
  end

  def control_daemon(app, action)
    dir = app_dir(app)
    cmd = "bundle exec ruby #{dir}/daemon.rb #{action}"
    system(cmd)
  end

  config.before(:suite) do
    control_daemon(:api, 'start')
    control_daemon(:media, 'start')
  end

  config.after(:suite) do
    control_daemon(:api, 'stop')
    control_daemon(:media, 'stop')
  end
end
