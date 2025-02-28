# typed: strong
# frozen_string_literal: true

require_relative "thread_runner"

# Thread runner responsible for dealing with timed out Orka deploys.
class OrkaTimeoutProcessor < ThreadRunner
  TIMEOUT_SECONDS = 900

  sig { override.returns(T::Boolean) }
  def pausable?
    true
  end

  sig { override.void }
  def run
    log "Started #{name}."

    loop do
      check_orka
      check_jobs
      sleep(60)
    end
  rescue ShutdownException
    # Exit gracefully
  end

  private

  sig { void }
  def check_orka
    Thread.handle_interrupt(ShutdownException => :on_blocking) do
      @pause_mutex.synchronize do
        while paused?
          log "Queue is paused. Waiting for unpause..."
          @unpause_condvar.wait(@pause_mutex)
        end
      end

      state = SharedState.instance
      Thread.handle_interrupt(ShutdownException => :never) do
        instances = T.cast(
          state.orka_client.list(OrkaKube.virtual_machine_instance),
          OrkaKube::DSL::Orka::V1::VirtualMachineInstanceList,
        ).items
        instances.each do |instance|
          next if Time.parse(instance.metadata.creation_timestamp) > (Time.now - TIMEOUT_SECONDS)
          next if state.jobs.any? { |job| instance.metadata.name == job.orka_vm_id }

          log "Deleting VM #{instance.metadata.name} as unassigned for longer than 15 minutes."
          state.orka_client.watch(state.orka_client.delete(instance))
        end

        nil
      end
    end
  rescue ShutdownException
    raise
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
  def check_jobs
    Thread.handle_interrupt(ShutdownException => :never) do
      state = SharedState.instance
      current_time = Time.now.to_i
      state.jobs.each do |job|
        next unless job.orka_setup_timeout?
        next if job.github_state != :queued
        next if T.must(job.orka_setup_time) > (current_time - TIMEOUT_SECONDS)

        log "Rescheduling deploy of #{job.runner_name} after 15 minute timeout."
        job.orka_setup_time = nil
        job.orka_setup_timeout = false
        state.orka_start_processors.fetch(job.queue_type).queue << job
      end
    end
  rescue ShutdownException
    raise
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end
end
