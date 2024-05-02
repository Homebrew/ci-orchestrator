# frozen_string_literal: true

require_relative "shared_state"

# A variation of `Thread::Queue` that allows us to prioritise certain types of jobs.
class JobQueue
  def initialize(queue_type)
    @mutex = Mutex.new
    @queue = Hash.new { |h, k| h[k] = [] }
    @queue_type = queue_type
    @condvar = ConditionVariable.new
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

        if running_long_build_count < 2 && !@queue[:long].empty?
          break @queue[:long].shift
        elsif !@queue[:default].empty?
          break @queue[:default].shift
        else
          @condvar.wait(@mutex)
        end
      end
    end
  end
end
