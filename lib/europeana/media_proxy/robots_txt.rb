module Europeana
  module MediaProxy
    class RobotsTxt
      def initialize(app)
        @app = app
      end

      def call(env)
        if env['PATH_INFO'] == '/robots.txt'
          status = 200
          headers = { 'Content-Type' => 'text/plain' }
          body = [ENV['ROBOTS_TXT'] || "User-agent: *\nDisallow: /"]
          [status, headers, body]
        else
          @app.call(env)
        end
      end
    end
  end
end
