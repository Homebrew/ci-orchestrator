# frozen_string_literal: true

require_relative "ring"
require_relative "log_event"

# The base thread runner class.
class ThreadRunner
  attr_reader :name, :log_history

  def initialize(name = self.class.name)
    @name = name
    @log_history = Ring.new
    @paused = false
    @pause_mutex = Mutex.new
    @unpause_condvar = ConditionVariable.new
  end

  def pausable?
    false
  end

  def paused?
    raise "Runner not pausable." unless pausable?

    @paused
  end

  def pause
    raise "Runner not pausable." unless pausable?

    @pause_mutex.synchronize do
      @paused = true
    end
  end

  def unpause
    raise "Runner not pausable." unless pausable?

    @pause_mutex.synchronize do
      @paused = false
      @unpause_condvar.broadcast
    end
  end

  def run
    raise "Implement me!"
  end

  private

  def log(message, error: false)
    @log_history << LogEvent.new(message.to_s, error:)

    if error
      $stderr.puts(message)
    else
      puts message
    end
  end
end
