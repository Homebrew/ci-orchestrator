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

    # Dynamic allocation:
    # - If dispatch queue empty: long gets 50%
    # - If long queue empty: dispatch gets 50%
    # - If both dispatch and long have jobs: both get 25%
    # - Default fills remaining slots up to 100%
    @half_slots = T.let(@queue_type.slots / 2, Integer)
    @quarter_slots = T.let(@queue_type.slots / 4, Integer)
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

        has_long_jobs = !queue(PriorityType::Long).empty?
        has_dispatch_jobs = !queue(PriorityType::Dispatch).empty?

        long_slot_limit = if !has_dispatch_jobs
          @half_slots # Dispatch empty: long gets 50%
        elsif has_long_jobs
          @quarter_slots # Both have jobs: long gets 25%
        else
          0 # Long empty: long gets 0%
        end

        dispatch_slot_limit = if !has_long_jobs
          @half_slots # Long empty: dispatch gets 50%
        elsif has_dispatch_jobs
          @quarter_slots # Both have jobs: dispatch gets 25%
        else
          0 # Dispatch empty: dispatch gets 0%
        end

        should_schedule_long = has_long_jobs && running_long_build_count < long_slot_limit
        break T.must(queue(PriorityType::Long).shift) if should_schedule_long

        should_schedule_dispatch = has_dispatch_jobs && running_dispatch_build_count < dispatch_slot_limit
        break T.must(queue(PriorityType::Dispatch).shift) if should_schedule_dispatch

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
