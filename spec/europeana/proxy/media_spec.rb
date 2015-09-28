# feature spec for the app
describe Europeana::Proxy::Media do
  it 'capitalises header names'

  context 'when URL path is not a Europeana record ID' do
    it 'responds with 404 Not Found'
  end

  context 'when HTTP status code=2xx' do
    context 'when content-type = text/html' do
      let(:content_type) { 'text/html' }
      it 'redirects to the external URL'
    end

    context 'when content-type = application/octet-stream' do
      let(:content_type) { 'application/octet-stream' }

      it 'streams the content to the client as a download'
      it 'has a file basename based on the record ID'

      context 'when target URL has extension' do
        context 'when extension is of a known type' do
          let(:url) { 'http://www.example.com/file.pdf' }
          it 'uses extension from target URL for download'
          it 'overrides the content-type header'
        end

        context 'when extension is not of a known type' do
          let(:url) { 'http://www.example.com/file.not-a-known-extension' }
          it 'uses .bin for file extension'
          it 'keeps the application/octet-stream content-type'
        end
      end
    end

    context 'when content-type != (text/html or application/octet-stream)' do
      it 'streams the content to the client as a download'
      it 'preserves the content-type header'
      it 'has a file basename based on the record ID'
      it 'has a file extension based on the media type'
      it 'adds a CORS header'
    end
  end

  context 'when HTTP status code=3xx' do
    it 'follows the redirection'
    it 'handles relative redirects'
    it 'only follows a limited number of redirects'
  end

  context 'when Europeana API response is not understood' do
    it 'responds with 502 Bad Gateway'
  end

  context 'when provider returns invalid content-type header' do
    let(:content_type) { 'image/jpg' }
    it 'responds with 502 Bad Gateway'
  end
end
