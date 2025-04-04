ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION-alpine

WORKDIR /app
COPY .ruby-version Gemfile* /app/

ENV BUNDLE_DEPLOYMENT=1

RUN apk add --no-cache --virtual .build-deps build-base && \
    bundle install && \
    apk del --no-cache .build-deps

COPY src /app
COPY gen /gen

EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--port=8080", "--env=production", "--server=Puma"]
