# frozen_string_literal: true

require_relative "queue_types"
require_relative "shared_state"

# A variation of `Thread::Queue` that allows us to prioritise certain types of jobs.
class JobQueue
  def initialize(queue_type, logger)
    @mutex = Mutex.new
    @queue = Hash.new { |h, k| h[k] = [] }
    @queue_type = queue_type
    @condvar = ConditionVariable.new
    @logger = logger
  end

  def <<(job)
    @mutex.synchronize do
      @queue[job.group] << job
      @condvar.signal
    end
  end

  def pop
    @mutex.synchronize do
      loop do
        running_long_build_count = SharedState.instance.running_jobs(@queue_type).count(&:long_build?)
        long_build_slots = QueueTypes.slots(@queue_type) / 2
        @logger.call("Long builds: #{running_long_build_count} running, #{long_build_slots} available")

        if running_long_build_count < long_build_slots && !@queue[:long].empty?
          job = @queue[:long].shift
          @logger.call("Long build slot available. Scheduling #{job.runner_name} for deployment...")
          break job
        elsif !@queue[:default].empty?
          break @queue[:default].shift
        else
          @condvar.wait(@mutex)
        end
      end
    end
  end
end
