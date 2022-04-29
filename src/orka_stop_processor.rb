# frozen_string_literal: true

# Thread runner responsible for destroying Orka VMs.
class OrkaStopProcessor
  attr_reader :queue

  def initialize
    @queue = Queue.new
  end

  def run
    puts "Started #{self.class.name}."

    job = nil
    loop do
      Thread.handle_interrupt(ShutdownException => :on_blocking) do
        job = @queue.pop
        next if job.orka_vm_id.nil?

        state = SharedState.instance
        state.orka_mutex.synchronize do
          Thread.handle_interrupt(ShutdownException => :never) do
            puts "Deleting VM for job #{job.runner_name}..."
            begin
              state.orka_client.vm_resource(job.orka_vm_id).delete_all_instances
            rescue OrkaAPI::ResourceNotFoundError
              puts("VM for job #{job.runner_name} already deleted!")
            end
            job.orka_vm_id = nil
            state.orka_free_condvar.broadcast
            puts "VM for job #{job.runner_name} deleted."
          end
        end

        if job.github_state == :queued
          if orka.orka_start_attempts > 5
            # We've tried and failed. Move on.
            job.github_state = :completed
          else
            # Try deploy again.
            state.orka_start_processor.queue << job
          end
        end
      end
    rescue ShutdownException
      break
    rescue => e
      @queue << job unless job&.orka_vm_id.nil? # Reschedule
      $stderr.puts(e)
      $stderr.puts(e.backtrace)
      sleep(30)
    end
  end
end
