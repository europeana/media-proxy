# Europeana::Proxy::EdmIsShownBy

[Rack](http://rack.github.io/) proxy to download the edm:isShownBy
targets of Europeana records.

## License

Licensed under the EUPL V.1.1.

For full details, see [LICENSE.md](LICENSE.md).

## Installation

1. Download and extract the
  [ZIP](https://github.com/europeana/europeana-proxy-ruby/archive/master.zip)
2. Install dependencies with Bundler:

    `bundle`

## Configuration

1. Get a Europeana API key from http://labs.europeana.eu/api/
2. Set your API key in the environment variable `EUROPEANA_API_KEY`.
  
  In a development environment, environment variables can be set in the file
  [.env](https://github.com/bkeepers/dotenv)
3. Run with Puma:
  
    `bundle exec puma`

## Usage

The proxy application will respond to requests for URL paths corresponding to
the two-part IDs of Europeana records, with the format "/provider-code/item-id",
e.g. http://www.example.com/abcdef/123456. Any other requests will result in a
404 error response.

The [Europeana REST API](http://labs.europeana.eu/api/introduction/) will be
queried for the record ID in the request path, and the edm:isShownBy URL for
the record retrieved.

The proxy application will request from the provider the target of the
edm:isShownBy URL, resolve redirects in the response, and finally stream the
content to the user agent (e.g. web browser) as a download, with file name
derived from the record ID, e.g. "abcdef_123456.jpeg".

Where the target is an HTML page, it will not be downloaded, but the user agent
will instead be redirected to it.


## TODO

* Make the proxy usable as Rack middleware, and document installation as a gem
* Document in this README:
  * error handling
  * logger output
