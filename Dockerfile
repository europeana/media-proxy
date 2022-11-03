FROM ruby:2.5.5-alpine AS base

MAINTAINER Europeana Foundation <development@europeana.eu>

ENV RACK_ENV=production \
    BUNDLER_VERSION=2.1.4 \
    PORT=8080 \
    WEB_CONCURRENCY=1 \
    ELASTIC_APM_SERVICE_NAME=media-proxy \
    ELASTIC_APM_ENVIRONMENT=development

ENTRYPOINT ["bundle", "exec", "puma"]
CMD ["-C", "config/puma.rb", "-v"]
EXPOSE 8080

WORKDIR /app

RUN apk add --update \
  libcurl

RUN gem install bundler -v ${BUNDLER_VERSION}


FROM base as dependencies

RUN apk add --update \
  build-base

COPY Gemfile Gemfile.lock ./

RUN bundle config set without "development test" && \
    bundle install --jobs=3 --retry=3

FROM base

COPY --from=dependencies /usr/local/bundle/ /usr/local/bundle/

COPY . ./
