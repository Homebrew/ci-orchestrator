FROM ruby:3.2-alpine

# Currently need git as some dependencies are defined with git repos at the moment
RUN apk add --no-cache --virtual .build-deps git build-base

WORKDIR /app
COPY Gemfile* ./
RUN bundle install --deployment && apk del .build-deps

COPY src ./

EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--port=8080", "--env=production", "--server=Puma"]
