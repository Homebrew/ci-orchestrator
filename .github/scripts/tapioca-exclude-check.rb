#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler"
require "psych"

RBI_ALLOWLIST = %w[
  addressable
  dry-inflector
  faraday
  jwt
  kube-dsl
  octokit
  rack-session
  rack
  rake
  sinatra
].freeze

tapioca_config = Psych.safe_load_file("sorbet/tapioca/config.yml")
tapioca_excludes = tapioca_config.dig("gem", "exclude")

gem_names = Bundler.locked_gems.specs.map(&:name).uniq
gem_names.reject! { |name| name.match?(/\Asorbet(?:-(?:static(?:-.*)?|runtime))?\z/) } # Implicitly excluded

allowed_and_excluded = RBI_ALLOWLIST & tapioca_excludes
unless allowed_and_excluded.empty?
  $stderr.puts "Tapioca excludes contains gems in the allowlist!"
  $stderr.puts "Gems affected: #{allowed_and_excluded.join(", ")}"
  exit(1)
end

new_gems = gem_names - tapioca_excludes - RBI_ALLOWLIST
unless new_gems.empty?
  $stderr.puts "New gems were added that may need to be added to the Tapioca exclude list."
  $stderr.puts "Gems affected: #{new_gems.join(", ")}"
  exit(1)
end

extra_excludes = tapioca_excludes - gem_names
unless new_gems.empty?
  $stderr.puts "Tapioca exclude list contains gems that are not in the Gemfile.lock"
  $stderr.puts "Gems affected: #{extra_excludes.join(", ")}"
  exit(1)
end
