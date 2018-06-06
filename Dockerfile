FROM ruby:2.2.3

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# Set an environment variable where the Rails app is installed to inside of Docker image
ENV RAILS_ROOT /var/www/app_name
RUN mkdir -p $RAILS_ROOT

# Set working directory
WORKDIR $RAILS_ROOT

# Setting env up
ENV RACK_ENV="production"
ENV PORT="80"

# Adding gems
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN bundle install --jobs 20 --retry 5 --without development test 

# Adding project files
COPY config ./config
COPY lib ./lib
COPY config.ru LICENSE.md Rakefile README.md ./

# RUN bundle exec rake assets:precompile

EXPOSE 80
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
