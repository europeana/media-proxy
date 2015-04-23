require 'spec_helper'

describe Europeana::Proxy::EdmIsShownBy do
  it 'handles relative redirects'

  context 'when Europeana API response is not understood' do
    it 'responds with 502 Bad Gateway'
  end

  context 'when provider returns invalid content-type header' do
    let(:content_type) { 'image/jpg' }
    it 'responds with 502 Bad Gateway'
  end

  context 'when HTTP status code=2xx' do
    context 'when content-type=text/html' do
      let(:content_type) { 'text/html' }
      it 'redirects to the external URL'
    end

    context 'when content-type != text/html' do
      it 'streams the content to the client as a download'
      it 'has a file name based on the record ID'
      it 'has a file extension based on the media type'
    end
  end

  context 'when HTTP status code=3xx' do
    it 'follows the redirection'
    it 'only follows a limited number of redirects'
  end
end
