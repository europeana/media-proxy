if ['development', 'test'].include?(ENV['RACK_ENV'])
  require 'dotenv'
  Dotenv.load
end

require 'europeana/api'
require 'europeana/proxy'
require 'logger'

# @todo move into initializer / middleware / etc
unless ENV.key?('EUROPEANA_API_KEY')
  puts 'EUROPEANA_API_KEY must be set in the environment'
  exit 1
end

Europeana::API.api_key = ENV['EUROPEANA_API_KEY']

logger = Logger.new(STDOUT)
use Rack::CommonLogger, logger
use Europeana::Proxy::EdmIsShownBy

app = Proc.new do |env|
  Europeana::Proxy::EdmIsShownBy.response_for_status_code(404)
end
run app
