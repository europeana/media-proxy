# Europeana Media Proxy

[![Build Status](https://travis-ci.org/europeana/media-proxy.svg?branch=develop)](https://travis-ci.org/europeana/media-proxy) [![security](https://hakiri.io/github/europeana/media-proxy/develop.svg)](https://hakiri.io/github/europeana/media-proxy/develop) [![Maintainability](https://api.codeclimate.com/v1/badges/51f4d29eff1a7ee2b93b/maintainability)](https://codeclimate.com/github/europeana/media-proxy/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/51f4d29eff1a7ee2b93b/test_coverage)](https://codeclimate.com/github/europeana/media-proxy/test_coverage)

[Rack](http://rack.github.io/) app and middleware to proxy the media objects
(web resources) associated with [Europeana](https://www.europeana.eu/) records.

## Installation

1. Clone the repository: `git clone https://github.com/europeana/media-proxy.git`
2. Install dependencies with Bundler: `cd media-proxy && bundle`

## Configuration

1. Get a Europeana API key from https://pro.europeana.eu/get-api
2. Set your API key in the environment variable `EUROPEANA_API_KEY`.
3. (Optional) Set permitted CORS origins in the environment variable
  `CORS_ORIGINS`. Examples:
  * `CORS_ORIGINS=*`
  * `CORS_ORIGINS=http://localhost:3000 http://www.example.com`
4. (Optional) Set permitted API endpoints in the environment variable
 `PERMITTED_API_URLS`.
  Comma separated, will always automatically include `Europeana::API.url`. Examples:
  * `PERMITTED_API_URLS=http://test-api.example.org/api`
  * `PERMITTED_API_URLS=http://test-api.example.org/api,https://test-api.example.org/api,http://localhost:8080/api`
5. Run with Puma:
  `bundle exec puma -C config/puma.rb`

### Development environments

* **Environment variables** can be set in the file
[.env](https://github.com/bkeepers/dotenv)

* **Puma** can be run with [foreman](https://github.com/ddollar/foreman) to
detect .env environment variables:

  `foreman start`

## Usage

### Overview

1. Proxy receives HTTP request with Europeana record ID as URL path, with an
  optional `view` parameter with the URI of a web resource
2. Proxy requests record metadata from Europeana REST API
3. Proxy gets edm:isShownBy URL from record metadata, unless `view` parameter
  was specified
4. Proxy issues an HTTP request for `view` parameter URL if specified,
  otherwise edm:isShownBy URL
5. Proxy follows redirects in response from remote provider
6. If final target is HTML, user agent is redirected to it
7. If final target is not HTML, proxy constructs a file name based on record ID
  and streams it to the user agent as a file download
8. If errors are encountered at any stage of the request handling, proxy
  returns a relevant HTTP status code with plain text message

### Valid URL paths

The only URL paths accepted by the proxy application are Europeana record IDs
with an optional `view` parameter containing the URL of the required resource.

Optionally the `api_url` paramater may be supplied. If this is present, the aplication will query the specified API
endpoint. Non permitted API urls will result in a 403 Forbidden response. By default the `Europeana::API.url` will
always be permitted.

For instance, the record with ID "/09102/_GNM_693983" has the proxied download URLs:
* http://www.example.com/09102/_GNM_693983?view=http://www.mimo-db.eu/media/GNM/IMAGE/MIR1097_1279787057222_2.jpg
* http://www.example.com/09102/_GNM_693983?view=http://www.mimo-db.eu/media/GNM/VIDEO/MIR1097_Daempfer_Stein.avi
* http://www.example.com/09102/_GNM_693983?view=http://www.mimo-db.eu/media/GNM/VIDEO/MIR1097_Daempfer_Stein.avi&api_url=https://www.europeana.eu/api
* etc.
(where www.example.com is the hostname of your deployed application)

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
The API endpoint is not permitted | 403
URL path is not a Europeana record ID | 404
No Europeana record exists for the given record ID | 404
Europeana record has no edm:isShownBy data | 404
Remote provider responds with invalid or unknown media type in content-type header | 502
The maximum number of redirects is exceeded in attempting to resolve the edm:isShownBy target | 502
Remote provider is unreachable | 502
Europeana REST API returns an invalid response | 502
Request to remote provider times out | 504
Any other error preventing completion of the request | 500

## License

Licensed under the EUPL v.1.2.

For full details, see [LICENSE.md](LICENSE.md).
