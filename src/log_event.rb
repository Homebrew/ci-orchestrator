# frozen_string_literal: true

# Represents a particular logging output.
class LogEvent
  attr_reader :time, :message

  def initialize(message, error: false)
    @time = Time.now
    @message = message
    @error = error
  end

  def error?
    @error
  end

  def to_s
    "[#{time.iso8601}] [#{error? ? "ERROR" : "INFO"}] #{message}"
  end
end
