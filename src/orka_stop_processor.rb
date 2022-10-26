# frozen_string_literal: true

require_relative "thread_runner"

# Thread runner responsible for destroying Orka VMs.
class OrkaStopProcessor < ThreadRunner
  attr_reader :queue

  def initialize
    super
    @queue = Queue.new
  end

  def pausable?
    true
  end

  def run
    log "Started #{name}."

    job = nil
    loop do
      Thread.handle_interrupt(ShutdownException => :on_blocking) do
        job = @queue.pop
        next if job.orka_vm_id.nil?

        @pause_mutex.synchronize do
          while paused?
            log "Queue is paused. Waiting for unpause..."
            @unpause_condvar.wait(@pause_mutex)
          end
        end

        state = SharedState.instance
        state.orka_mutex.synchronize do
          if paused?
            @queue << job
            next
          end

          Thread.handle_interrupt(ShutdownException => :never) do
            log "Deleting VM for job #{job.runner_name}..."
            begin
              state.orka_client.vm_resource(job.orka_vm_id).delete_all_instances
            rescue OrkaAPI::ResourceNotFoundError
              log "VM for job #{job.runner_name} already deleted!"
            end
            job.orka_vm_id = nil
            state.orka_free_condvar.broadcast
            log "VM for job #{job.runner_name} deleted."
          end
        end

        if job.github_state == :queued
          if job.orka_start_attempts > 5
            # We've tried and failed. Move on.
            log "Giving up on job #{job.runner_name} after #{job.orka_start_attempts} start attempts."
            job.github_state = :completed
          else
            # Try deploy again.
            state.orka_start_processors[job.queue_type].queue << job
          end
        end
      end
    rescue ShutdownException
      break
    rescue => e
      @queue << job unless job&.orka_vm_id.nil? # Reschedule
      log(e, error: true)
      log(e.backtrace, error: true)
      sleep(30)
    end
  end
end
