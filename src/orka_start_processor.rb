# frozen_string_literal: true

require_relative "thread_runner"
require_relative "job_queue"

require "timeout"

# Thread runner responsible for deploying Orka VMs.
class OrkaStartProcessor < ThreadRunner
  CONFIG_MAP = {
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
    "12"             => "monterey", # TODO: Remove me after a week or two
    "13"             => "ventura",  # TODO: Remove me after a week or two
    "14"             => "sonoma",   # TODO: Remove me after a week or two
  }.freeze

  attr_reader :queue

  def initialize(queue_type, name)
    super("#{self.class.name} (#{name})")
    @queue = JobQueue.new(queue_type, method(:log))
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
        state = SharedState.instance
        next unless job.orka_vm_id.nil?

        github_metadata = state.github_runner_metadata
        github_mutex = state.github_mutex
        github_mutex.synchronize do
          while github_metadata.registration_token.nil? ||
                (github_metadata.registration_token.expires_at.to_i - Time.now.to_i) < 300 ||
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

        state.orka_mutex.synchronize do
          until state.free_slot?(job)
            log "Job #{job.runner_name} is waiting for a free slot."
            state.orka_free_condvar.wait(state.orka_mutex)
          end

          if paused?
            @queue << job
            next
          end

          if job.github_state != :queued
            log "Job #{job.runner_name} no longer in queued state, skipping."
            next
          end

          runner_download = github_metadata.download_urls["osx"][job.arm64? ? "arm64" : "x64"]

          vm_metadata = {
            runner_registration_token: github_metadata.registration_token.token,
            runner_label:              job.runner_labels.join(","),
            runner_name:               job.runner_name,
            runner_config_args:        "--ephemeral --disableupdate --no-default-labels",
            runner_download:           runner_download[:url],
            runner_download_sha256:    runner_download[:sha256],
            orchestrator_secret:       job.secret,
          }

          config = CONFIG_MAP[job.os]
          job.orka_setup_time = nil

          full_host_retry_count = 0
          Thread.handle_interrupt(ShutdownException => :never) do
            if job.orka_vm_id.nil?
              log "Deploying VM for job #{job.runner_name}..."
              result = state.orka_client
                            .vm_configuration(config)
                            .deploy(vm_metadata:)
              job.orka_start_attempts += 1
              job.orka_vm_id = result.resource.name
              job.orka_setup_time = Time.now.to_i
              log "VM for job #{job.runner_name} deployed (#{job.orka_vm_id})."
            end
          rescue Faraday::ServerError => e
            if e.response_body.include?("Cannot deploy more than 2 VMs on an ARM host") && full_host_retry_count < 3
              full_host_retry_count += 1
              log "Host full. Retrying..."
              sleep(10)
              retry
            end

            log("Error 500 deploying VM for job #{job.runner_name}: #{e.response_body}", error: true)

            job.orka_setup_timeout = true
            job.orka_setup_time = Time.now.to_i
          rescue Faraday::TimeoutError
            log("Timeout when deploying VM for job #{job.runner_name}.", error: true)

            job.orka_setup_timeout = true
            job.orka_setup_time = Time.now.to_i
          end

          state.orka_stop_processor.queue << job if !job.orka_vm_id.nil? && job.github_state == :completed
        end
      end
    rescue ShutdownException
      break
    rescue => e
      @queue << job if job && job.orka_vm_id.nil? # Reschedule
      log(e, error: true)
      log(e.backtrace, error: true)
      sleep(30)
    end
  end
end
