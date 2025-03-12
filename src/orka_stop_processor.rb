# typed: strong
# frozen_string_literal: true

require_relative "thread_runner"

# Thread runner responsible for destroying Orka VMs.
class OrkaStopProcessor < ThreadRunner
  sig { returns(Queue) }
  attr_reader :queue

  sig { void }
  def initialize
    super
    @queue = T.let(Queue.new, Queue)
  end

  sig { override.returns(T::Boolean) }
  def pausable?
    true
  end

  sig { override.void }
  def run
    log "Started #{name}."

    job = T.let(nil, T.nilable(Job))
    loop do
      Thread.handle_interrupt(ShutdownException => :on_blocking) do
        job = T.cast(@queue.pop, Job)
        next if job.orka_vm_id.nil?

        @pause_mutex.synchronize do
          while paused?
            log "Queue is paused. Waiting for unpause..."
            @unpause_condvar.wait(@pause_mutex)
          end
        end

        state = SharedState.instance
        Thread.handle_interrupt(ShutdownException => :never) do
          log "Deleting VM #{job.orka_vm_id} for job #{job.runner_name}..."
          begin
            state.orka_client.watch(state.orka_client.delete(OrkaKube.virtual_machine_instance do
              metadata do
                name T.must(job.orka_vm_id)
              end
            end))
          rescue Faraday::ResourceNotFound
            log "VM for job #{job.runner_name} already deleted!"
          end
          job.orka_vm_id = nil
          state.orka_start_processors.fetch(job.queue_type).signal_free(job.priority_type)
          log "VM for job #{job.runner_name} deleted."
        end

        if job.github_state == :queued
          if job.orka_start_attempts > 5
            # We've tried and failed. Move on.
            log "Giving up on job #{job.runner_name} after #{job.orka_start_attempts} start attempts."
            job.github_state = :completed
          else
            # Try deploy again.
            state.orka_start_processors.fetch(job.queue_type).queue << job
          end
        end
      end
    rescue ShutdownException
      break
    rescue => e
      @queue << job unless job&.orka_vm_id.nil? # Reschedule
      log(e.to_s, error: true)
      log(e.backtrace.to_s, error: true)
      sleep(30)
    end
  end
end
