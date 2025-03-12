# typed: strong
# frozen_string_literal: true

require_relative "thread_runner"
require_relative "job_queue"

require "timeout"

# Thread runner responsible for deploying Orka VMs.
class OrkaStartProcessor < ThreadRunner
  CONFIG_MAP = T.let({
    "10.11-cross"    => "monterey-1011-cross",
    "10.15"          => "catalina",
    "11"             => "bigsur",
    "11-arm64-cross" => "monterey-arm64-11-cross",
    "12-x86_64"      => "monterey",
    "12-arm64"       => "monterey-arm64",
    "13-x86_64"      => "ventura",
    "13-arm64"       => "ventura-arm64",
    "14-x86_64"      => "sonoma",
    "14-arm64"       => "sonoma-arm64",
    "15-x86_64"      => "sequoia",
    "15-arm64"       => "sequoia-arm64",
  }.freeze, T::Hash[String, String])

  sig { returns(JobQueue) }
  attr_reader :queue

  sig { params(queue_type: QueueType, name: String).void }
  def initialize(queue_type, name)
    super("#{self.class.name} (#{name})")
    @queue = T.let(JobQueue.new(queue_type), JobQueue)
    @orka_free_mutex = T.let(Mutex.new, Mutex)
    @orka_free_condvar = T.let(ConditionVariable.new, ConditionVariable)
  end

  sig { override.returns(T::Boolean) }
  def pausable?
    true
  end

  sig { params(priority_type: PriorityType).void }
  def signal_free(priority_type)
    @orka_free_condvar.signal
    @queue.signal_free(priority_type)
  end

  sig { override.void }
  def run
    log "Started #{name}."

    job = T.let(nil, T.nilable(Job))
    loop do
      Thread.handle_interrupt(ShutdownException => :on_blocking) do
        job = @queue.pop
        state = SharedState.instance
        next unless job.orka_vm_id.nil?

        github_metadata = state.github_runner_metadata
        github_mutex = state.github_mutex
        github_mutex.synchronize do
          while github_metadata.registration_token.nil? ||
                (T.must(github_metadata.registration_token).expires_at.to_i - Time.now.to_i) < 300 ||
                github_metadata.download_urls.nil?
            log "Waiting for GitHub metadata..."
            state.github_metadata_condvar.wait(github_mutex)
          end
        end

        @pause_mutex.synchronize do
          while paused?
            log "Queue is paused. Waiting for unpause..."
            @unpause_condvar.wait(@pause_mutex)
          end
        end

        @orka_free_mutex.synchronize do
          until state.free_slot?(job)
            log "Job #{job.runner_name} is waiting for a free slot."
            @orka_free_condvar.wait(@orka_free_mutex)
          end
        end

        if paused?
          @queue << job
          next
        end

        if job.github_state != :queued
          log "Job #{job.runner_name} no longer in queued state, skipping."
          next
        end

        runner_application = github_metadata.runner_application_for_job(job)
        config = CONFIG_MAP.fetch(job.os)

        definition = OrkaKube.virtual_machine_instance do
          metadata do
            generate_name "#{config}-"
            labels do
              add :"orka.macstadium.com/vm-config", config
            end
          end
          spec do
            custom_vm_metadata do
              add :runner_registration_token, T.must(github_metadata.registration_token).token
              add :runner_label, job.runner_labels.join(",")
              add :runner_name, job.runner_name
              add :runner_config_args, "--ephemeral --disableupdate --no-default-labels"
              add :runner_download, runner_application.url
              add :runner_download_sha256, runner_application.sha256
              add :orchestrator_secret, job.secret
            end
          end
        end

        job.orka_setup_time = nil

        Thread.handle_interrupt(ShutdownException => :never) do
          if job.orka_vm_id.nil?
            log "Deploying VM for job #{job.runner_name}..."
            result = state.orka_client.watch(state.orka_client.create(definition)) do |candidate|
              !candidate.status.phase.to_s.empty? && candidate.status.phase != "Pending"
            end
            job.orka_start_attempts += 1
            job.orka_vm_id = result.metadata.name
            job.orka_setup_time = Time.now.to_i
            log "VM for job #{job.runner_name} deployed (#{job.orka_vm_id})."

            if result.status.phase != "Running"
              log("Job #{job.runner_name} phase is #{result.status.phase} (errors: #{result.status.error_message})",
                  error: true)

              job.orka_setup_timeout = true
              job.orka_setup_time = Time.now.to_i
            end
          end
        rescue Faraday::TimeoutError
          log("Timeout when deploying VM for job #{job.runner_name}.", error: true)

          job.orka_setup_timeout = true
          job.orka_setup_time = Time.now.to_i
        end

        state.orka_stop_processor.queue << job if !job.orka_vm_id.nil? && job.github_state == :completed
      end
    rescue ShutdownException
      break
    rescue => e
      @queue << job if job && job.orka_vm_id.nil? # Reschedule
      log(e.to_s, error: true)
      log(e.backtrace.to_s, error: true)
      sleep(30)
    end
  end
end
