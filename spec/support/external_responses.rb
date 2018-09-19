# frozen_string_literal: true

require 'mimic'

# TODO: make this a module

def load_media(filename)
  # TODO: load fixture file data (spec/fixtures/media/*) for response.
  filename.to_s
end

def setup_external_responses
  Mimic.mimic do
    get "/api/v2/search.json" do
      id = params[:query].gsub('europeana_id:"', '').gsub('"', '') # do this with regex?

      return [200,{ 'Content-Type' => 'text/plain' }, "NOT VALID JSON"] if id == '/123/API_ERROR'

      edm_preview = 'http://europeanastatic.eu/api/image?uri=' + CGI.escape("http://127.0.0.1:#{Mimic::MIMIC_DEFAULT_PORT}#{id}") + '&size=LARGE&type=TEXT'
      items = [{id: id, title: id , 'edmIsShownBy': "http://127.0.0.1:#{Mimic::MIMIC_DEFAULT_PORT}/provider#{id}", 'edmPreview':[edm_preview]}]
      api_search_response = {
        "success":true,
        "itemsCount": items.size,
        "totalResults": items.size,
        "items": items,
        "facets":[
          {
            "name": "COLOURPALETTE",
            "fields": [
              {
                "label": "#000000",
                "count": 2000
              }, {
                "label": "#FFFFFF",
                "count": 1000
              }
            ]
          }
        ]
      }
      [200, { 'Content-Type' => 'application/json;charset=UTF-8' }, api_search_response.to_json]
    end

    get '/provider/123/html' do
      [200, { 'Content-Type' => 'text/html' }, '<body><p>Hello from provider.</p></body>']
    end

    get '/provider/123/image' do
      content = load_media('image.jpg')
      [200, {'Content-Type' => 'image/jpeg'}, content]
    end

    get '/provider/123/audio' do
      content = load_media('audio/mp3')
      [200, {'Content-Type' => 'audio/mpeg'}, content]
    end

    get '/provider/123/invalid_mime' do
      content = load_media('image.jpg')
      [200, {'Content-Type' => 'image/jpg'}, content]
    end
  end
end
