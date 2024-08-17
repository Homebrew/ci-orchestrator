# typed: strong
# frozen_string_literal: true

# Represents a particular logging output.
class LogEvent
  extend T::Sig

  sig { returns(Time) }
  attr_reader :time

  sig { returns(String) }
  attr_reader :message

  sig { params(message: String, error: T::Boolean).void }
  def initialize(message, error: false)
    @time = T.let(Time.now, Time)
    @message = T.let(message, String)
    @error = T.let(error, T::Boolean)
  end

  sig { returns(T::Boolean) }
  def error?
    @error
  end

  sig { override.returns(String) }
  def to_s
    "[#{time.iso8601}] [#{error? ? "ERROR" : "INFO"}] #{message}"
  end
end
