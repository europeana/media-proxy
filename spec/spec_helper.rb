# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'rack/test'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'europeana/media_proxy'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  def app_dir(app)
    File.expand_path("apps/#{app}", __dir__)
  end

  def start_app(app, port)
    dir = app_dir(app)
    cmd = "bundle exec rackup -p #{port} -P #{dir}/rack.pid -D #{dir}/config.ru"
    puts cmd
    system(cmd)
  end

  def stop_app(app)
    dir = app_dir(app)
    Process.kill('TERM', File.read("#{dir}/rack.pid").strip.to_i)
  end

  config.before(:suite) do
    start_app(:api, 9292)
    start_app(:media, 9393)
  end

  config.after(:suite) do
    stop_app(:api)
    stop_app(:media)
  end
end
