# typed: strong
# frozen_string_literal: true

require_relative "ring"
require_relative "log_event"

# The base thread runner class.
class ThreadRunner
  extend T::Sig

  sig { returns(String) }
  attr_reader :name

  sig { returns(Ring[LogEvent]) }
  attr_reader :log_history

  sig { params(name: String).void }
  def initialize(name = T.unsafe(self.class.name))
    @name = name
    @log_history = T.let(Ring.new, Ring[LogEvent])
    @paused = T.let(false, T::Boolean)
    @pause_mutex = T.let(Mutex.new, Mutex)
    @unpause_condvar = T.let(ConditionVariable.new, ConditionVariable)
  end

  sig { returns(T::Boolean) }
  def pausable?
    false
  end

  sig { returns(T::Boolean) }
  def paused?
    raise "Runner not pausable." unless pausable?

    @paused
  end

  sig { void }
  def pause
    raise "Runner not pausable." unless pausable?

    @pause_mutex.synchronize do
      @paused = true
    end
  end

  sig { void }
  def unpause
    raise "Runner not pausable." unless pausable?

    @pause_mutex.synchronize do
      @paused = false
      @unpause_condvar.broadcast
    end
  end

  sig { void }
  def run
    raise "Implement me!"
  end

  private

  sig { params(message: String, error: T::Boolean).void }
  def log(message, error: false)
    @log_history << LogEvent.new(message, error:)

    if error
      T.cast($stderr, IO).puts(message)
    else
      puts message
    end
  end
end
