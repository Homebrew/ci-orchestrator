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

    # Ideally, @long_build_slots + @dispatch_build_slots < QueueTypes.slots(@queue_type).
    @long_build_slots = T.let(@queue_type.slots / 2, Integer)
    @dispatch_build_slots = T.let(@queue_type.slots / 4, Integer)
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

        if running_long_build_count < @long_build_slots && !queue(PriorityType::Long).empty?
          break T.must(queue(PriorityType::Long).shift)
        elsif running_dispatch_build_count < @dispatch_build_slots && !queue(PriorityType::Dispatch).empty?
          break T.must(queue(PriorityType::Dispatch).shift)
        elsif !queue(PriorityType::Default).empty?
          break T.must(queue(PriorityType::Default).shift)
        else
          @condvar.wait(@mutex)
        end
      end
    end
  end

  private

  sig { params(type: PriorityType).returns(T::Array[Job]) }
  def queue(type)
    T.must(@queue[type])
  end
end
