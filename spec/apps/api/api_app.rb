# frozen_string_literal: true

require 'roda'

class APIApp < Roda
  plugin :json

  route do |r|
    r.on 'api' do
      r.on 'v2' do
        r.get 'search.json' do
          europeana_id = request.params['query'].match(%r{europeana_id:"(.*)"})[1]

          {
            success: true,
            totalResults: 1,
            items: [
              { edmIsShownBy: "http://localhost:9393#{europeana_id}" }
            ]
          }
        end
      end
    end
  end
end
