ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION-alpine

# Currently need git as some dependencies are defined with git repos at the moment
RUN apk add --no-cache --virtual .build-deps git build-base

WORKDIR /app
COPY .ruby-version Gemfile* ./
ENV BUNDLE_DEPLOYMENT=1
RUN bundle install && apk del --no-cache .build-deps

COPY src ./

EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--port=8080", "--env=production", "--server=Puma"]
