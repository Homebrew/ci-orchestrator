# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "faraday-retry" # for octokit
gem "jwt"
gem "kube-dsl"
gem "octokit"
gem "puma"
gem "rackup"
gem "sinatra"
gem "sorbet-runtime"

group :development, optional: true do
  gem "rake"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-sorbet"
  gem "sorbet-static-and-runtime"
  gem "tapioca"
end
