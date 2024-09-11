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
        running_jobs = SharedState.instance.running_jobs(@queue_type)
        running_long_build_count = running_jobs.count(&:long_build?)
        running_dispatch_build_count = running_jobs.count(&:dispatch_job)

        # TODO: Change this to `/ 2` when Sequoia bottling is done.
        non_default_build_slots = QueueTypes.slots(@queue_type) / 3

        if running_long_build_count < non_default_build_slots && !@queue[:long].empty?
          break @queue[:long].shift
        elsif running_dispatch_build_count < non_default_build_slots && !@queue[:dispatch].empty?
          break @queue[:dispatch].shift
        elsif !@queue[:default].empty?
          break @queue[:default].shift
        else
          @condvar.wait(@mutex)
        end
      end
    end
  end
end
