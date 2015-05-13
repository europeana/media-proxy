require 'europeana/proxy/version'

module Europeana
  ##
  # HTTP proxy for Europeana web resources
  module Proxy
    autoload :EdmIsShownBy, 'europeana/proxy/edm_is_shown_by'
    autoload :Errors,       'europeana/proxy/errors'
  end
end
