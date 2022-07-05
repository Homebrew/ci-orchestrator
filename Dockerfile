FROM ruby:3.1-alpine

# Currently need git as some dependencies are defined with git repos at the moment
RUN apk add --no-cache --virtual .build-deps git build-base

WORKDIR /app
COPY Gemfile* ./
RUN bundle install --deployment && apk del .build-deps

COPY src ./

# Needed on Ruby 3.1 until Sinatra 3.0
ENV RUBYOPT=--disable-error_highlight
EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--port=8080", "--env=production", "--server=Puma"]
