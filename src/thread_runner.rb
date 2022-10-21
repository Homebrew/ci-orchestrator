# frozen_string_literal: true

require_relative "ring"
require_relative "log_event"

# The base thread runner class.
class ThreadRunner
  attr_reader :name, :log_history

  def initialize(name = self.class.name)
    @name = name
    @log_history = Ring.new
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
