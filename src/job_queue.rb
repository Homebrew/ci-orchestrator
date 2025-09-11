# typed: strong
# frozen_string_literal: true

require_relative "priority_type"
require_relative "queue_type"
require_relative "shared_state"

# A variation of `Thread::Queue` that allows us to prioritise certain types of jobs.
class JobQueue
  extend T::Sig

  sig { params(queue_type: QueueType).void }
  def initialize(queue_type)
    @mutex = T.let(Mutex.new, Mutex)
    @queue = T.let(Hash.new { |h, k| h[k] = [] }, T::Hash[PriorityType, T::Array[Job]])
    @queue_type = queue_type
    @condvar = T.let(ConditionVariable.new, ConditionVariable)

    # Ideally, long + dispatch slots < QueueTypes.slots(@queue_type).
    # Combined long + dispatch slots should not exceed 50% of total slots.
    # Dispatch can use up to 50% if long queue is empty.
    @combined_priority_slots = T.let(@queue_type.slots / 2, Integer)
  end

  sig { params(job: Job).returns(T.self_type) }
  def <<(job)
    @mutex.synchronize do
      T.must(@queue[job.priority_type]) << job
      @condvar.signal
    end
    self
  end

  sig { params(priority_type: PriorityType).void }
  def signal_free(priority_type)
    # No need to signal for types without slot limits.
    return if priority_type == PriorityType::Default

    @condvar.signal
  end

  sig { returns(Job) }
  def pop
    @mutex.synchronize do
      loop do
        running_jobs = SharedState.instance.running_jobs(@queue_type)
        running_long_build_count = running_jobs.count(&:long_build?)
        running_dispatch_build_count = running_jobs.count(&:dispatch_job?)
        combined_priority_count = running_long_build_count + running_dispatch_build_count

        if combined_priority_count < @combined_priority_slots
          # Prioritize long jobs first
          if !queue(PriorityType::Long).empty?
            break T.must(queue(PriorityType::Long).shift)
          # If no long jobs, dispatch can use the remaining priority slots
          elsif !queue(PriorityType::Dispatch).empty?
            break T.must(queue(PriorityType::Dispatch).shift)
          end
        end

        # Fill remaining slots with default jobs
        break T.must(queue(PriorityType::Default).shift) unless queue(PriorityType::Default).empty?

        @condvar.wait(@mutex)
      end
    end
  end

  private

  sig { params(type: PriorityType).returns(T::Array[Job]) }
  def queue(type)
    T.must(@queue[type])
  end
end
