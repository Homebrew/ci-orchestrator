# typed: strong
# frozen_string_literal: true

Regexp.timeout = 1.0

require "sorbet-runtime"
require_relative "server"

T.bind(self, Rack::Builder)

# We have a second pod that assigns the correct IP.
# Let's wait on that to avoid race conditions. Is it hacky? Probably.
# This IP assignment is however necessary for Orka requests to succeed.
public_ip = ENV.fetch("PUBLIC_IP", nil)
unless public_ip.nil?
  current_ip = T.let(nil, T.nilable(String))
  loop do
    begin
      current_ip = Net::HTTP.get(URI("https://api.ipify.org"))
    rescue
      # continue
    end
    break if current_ip == public_ip

    puts("Waiting for public IP match...")
    sleep(5)
  end
end

puts("Starting application...")

threads = T.let([], T::Array[Thread])

warmup do
  state = SharedState.instance
  state.load

  puts "Starting background worker threads..."

  threads += state.thread_runners.map { |runner| Thread.new { runner.run } }
end

at_exit do
  puts "Shutting down background worker threads... this may take a while."

  threads.each { |thread| thread.raise ShutdownException }
  while (thread = threads.shift)
    thread.join
  end

  state = SharedState.instance
  state.save if state.loaded?
end

run CIOrchestratorApp
