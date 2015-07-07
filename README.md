# Europeana::Proxy::EdmIsShownBy

[![Build Status](https://travis-ci.org/europeana/europeana-proxy-ruby.svg?branch=master)](https://travis-ci.org/europeana/europeana-proxy-ruby) [![Coverage Status](https://coveralls.io/repos/europeana/europeana-proxy-ruby/badge.svg?branch=master&service=github)](https://coveralls.io/github/europeana/europeana-proxy-ruby?branch=master) [![security](https://hakiri.io/github/europeana/europeana-proxy-ruby/master.svg)](https://hakiri.io/github/europeana/europeana-proxy-ruby/master)

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

  `bundle exec puma -C config/puma.rb`

  In a development environment, Puma can be run with foreman to pick up .env
  environment variables:

  `foreman start`

## Usage

### Overview

1. Proxy receives HTTP request with Europeana record ID as URL path
2. Proxy requests record metadata from Europeana REST API
3. Proxy gets edm:isShownBy URL from record metadata
4. Proxy issues an HTTP request for edm:isShownBy URL
5. Proxy follows redirects in response from remote provider
6. If final target is HTML, user agent is redirected to it
7. If final target is not HTML, proxy constructs a file name based on record ID
  and streams it to the user agent as a file download
8. If errors are encountered at any stage of the request handling, proxy
  returns a relevant HTTP status code with plain text message

### Valid URL paths

The only URL paths accepted by the proxy application are Europeana record IDs.
For instance, the record with ID "/11614/_HERBARIUMSPECIMEN_RBGK_UK_K000885766"
has the proxied download URL:
http://www.example.com/11614/_HERBARIUMSPECIMEN_RBGK_UK_K000885766 (where
www.example.com is the hostname of your deployed application)

HTTP requests to the proxy application for any other URL path result in a 404
Not Found error.

### Redirects

The proxy application follows redirects in the responses from remote providers,
requesting the target of the redirect until it receives a response that is not
a redirect, up to a maximum of 3 redirects.

Relative paths in redirect targets are detected and handled.

### Downloaded file names

The media streamed to the user agent as a downloaded file will have a file name
based on the record ID, with extension for the media type reported by the remote
provider. For instance, the record with ID
"/92023/BibliographicResource_2000068846208" has a JPEG image at its
edm:isShownBy URL, which is downloaded as a file named
"92023_BibliographicResource_2000068846208.jpeg".

### text/html content-type

If the target of the edm:isShownBy URL has an HTML media type, i.e. "text/html",
then it will not be sent to the user agent as a download but instead a redirect
to the HTML page will be sent to the user.

An HTML page for edm:isShownBy will likely have the actual media object exposed
through it somehow, and so the user is unlikely to want to download that
containing HTML page.

### application/octet-stream content-type

If the target of the edm:isShownBy URL has an arbitrary binary data media type,
i.e. "application/octet-stream", then the proxy application will use the URL's
file extension (if it has one) for the downloaded file name, and set the
content-type header to a more specific one based on that file name extension.

## Error handling

The following table lists the various error conditions handled by the proxy
application and the HTTP status code it responds with in each case. Error
responses are always plain text with the standard HTTP description of the
status, e.g. "Not Found" or "Internal Server Error".

Error condition | HTTP status code
----------------|-----------------
Europeana REST API responds that the proxy application's request (for record metadata) is invalid | 400
URL path is not a Europeana record ID | 404
No Europeana record exists for the given record ID | 404
Europeana record has no edm:isShownBy data | 404
Remote provider responds with invalid or unknown media type in content-type header | 502
The maximum number of redirects is exceeded in attempting to resolve the edm:isShownBy target | 502
Remote provider is unreachable | 502
Europeana REST API returns an invalid response | 502
Request to remote provider times out | 504
Any other error preventing completion of the request | 500

## TODO

* Make the proxy:
  * usable as Rack middleware, and document installation as a gem
  * a Sinatra app
* Document in this README:
  * logger output
