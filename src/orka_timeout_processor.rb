# frozen_string_literal: true

require_relative "thread_runner"

# Thread runner responsible for dealing with timed out Orka deploys.
class OrkaTimeoutProcessor < ThreadRunner
  TIMEOUT_SECONDS = 900

  def pausable?
    true
  end

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

  def check_orka
    Thread.handle_interrupt(ShutdownException => :on_blocking) do
      @pause_mutex.synchronize do
        while paused?
          log "Queue is paused. Waiting for unpause..."
          @unpause_condvar.wait(@pause_mutex)
        end
      end

      state = SharedState.instance
      state.orka_mutex.synchronize do
        return if paused?

        Thread.handle_interrupt(ShutdownException => :never) do
          state.orka_client.vm_resources.each do |resource|
            resource.instances.each do |instance|
              if instance.ip == "N/A"
                log "Deleting stuck deployment #{instance.id} (#{instance.name})."
                instance.delete
              elsif instance.creation_time.to_time <= (Time.now - TIMEOUT_SECONDS) &&
                    state.jobs.none? { |job| instance.id == job.orka_vm_id }
                log "Deleting VM #{instance.id} (#{instance.name}) as unassigned for longer than 15 minutes."
                instance.delete
              end
            end
          end
        end
      end
    end
  rescue ShutdownException
    raise
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end

  def check_jobs
    Thread.handle_interrupt(ShutdownException => :never) do
      state = SharedState.instance
      current_time = Time.now.to_i
      state.jobs.each do |job|
        next unless job.orka_setup_timeout?
        next if job.github_state != :queued
        next if job.orka_setup_time > (current_time - TIMEOUT_SECONDS)

        log "Rescheduling deploy of #{job.runner_name} after 15 minute timeout."
        job.orka_setup_time = nil
        job.orka_setup_timeout = false
        state.orka_start_processors[job.queue_type].queue << job
      end
    end
  rescue ShutdownException
    raise
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end
end
