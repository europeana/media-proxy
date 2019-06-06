FROM ruby:2.5.0-alpine

MAINTAINER Europeana Foundation <development@europeana.eu>

ENV BUNDLE_WITHOUT development:test
ENV RACK_ENV production
ENV PORT 80

WORKDIR /app

COPY Gemfile Gemfile.lock ./

# Install dependencies
RUN apk update && \
    apk add --no-cache --virtual .build-deps \
      build-base \
      git && \
    apk add --no-cache --virtual .runtime-deps \
      libcurl && \
    echo "gem: --no-document" >> /etc/gemrc && \
    bundle install --deployment --without ${BUNDLE_WITHOUT} --jobs=4 --retry=4 && \
    rm -rf vendor/bundle/ruby/2.5.0/bundler/gems/*/.git && \
    rm -rf vendor/bundle/ruby/2.5.0/cache && \
    rm -rf /root/.bundle && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/*

# Copy code
COPY . .

EXPOSE 80

ENTRYPOINT ["bundle", "exec", "puma"]
CMD ["-C", "config/puma.rb", "-v"]
