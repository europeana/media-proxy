# frozen_string_literal: true

require 'roda'

class MediaApp < Roda
  route do |r|
    r.on '123' do
      r.get 'invalid_mime' do
        response['Content-Type'] = 'application/jpg'
        ''
      end
    end
  end
end
