# frozen_string_literal: true

require_relative "thread_runner"

require "net/ssh"
require "timeout"

# Thread runner responsible for deploying Orka VMs.
class OrkaStartProcessor < ThreadRunner
  CONFIG_MAP = {
    "10.11-cross" => "highsierra-xcode7",
    "10.15"       => "catalina",
    "11"          => "bigsur",
    "12"          => "monterey",
    "12-arm64"    => "monterey-arm64",
  }.freeze

  attr_reader :queue

  def initialize
    super
    @queue = Queue.new
  end

  def run
    log "Started #{self.class.name}."

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

        vm_metadata = unless job.arm64?
          {
            token:       github_metadata.registration_token.token,
            label:       job.runner_name,
            name:        job.runner_name,
            config_args: "--ephemeral",
            download:    github_metadata.download_urls["osx"]["x64"],
          }
        end

        # TODO: node?
        result = nil
        state.orka_mutex.synchronize do
          until state.free_slot?(job)
            log "Job #{job.runner_name} is waiting for a free slot."
            state.orka_free_condvar.wait(state.orka_mutex)
          end

          if job.github_state != :queued
            log "Job #{job.runner_name} no longer in queued state, skipping."
            next
          end

          state.pause_mutex.synchronize do
            while state.paused?
              log "Queue is paused. Waiting for unpause..."
              state.unpause_condvar.wait(state.pause_mutex)
            end
          end

          config = CONFIG_MAP[job.os]
          job.orka_setup_complete = false

          Thread.handle_interrupt(ShutdownException => :never) do
            log "Deploying VM for job #{job.runner_name}..."
            result = state.orka_client
                          .vm_configuration(config)
                          .deploy(vm_metadata:)
            job.orka_start_attempts += 1
            job.orka_vm_id = result.resource.name
            job.orka_setup_complete = true unless vm_metadata.nil?
            log "VM for job #{job.runner_name} deployed (#{job.orka_vm_id})."
          rescue Faraday::TimeoutError
            log("Timeout when deploying VM for job #{job.runner_name}.", error: true)

            # Clean up the stuck deployment.
            state.orka_client.vm_resource(config).instances.each do |instance|
              next if instance.ip != "N/A"

              log("Deleting stuck deployment #{instance.id}.", error: true)
              instance.delete
            end

            result = nil
            @queue << job # Reschedule
          end
        end

        next if result.nil?

        Thread.handle_interrupt(ShutdownException => :never) do
          success = if vm_metadata.nil?
            setup_actions_runner(result, job, github_metadata.registration_token.token)
          else
            true
          end
          job.orka_setup_complete = true if success
          state.orka_stop_processor.queue << job if !success || job.github_state == :completed
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

  private

  def setup_actions_runner(deployment, job, token)
    state = SharedState.instance
    mapping = state.config.orka_ssh_map.fetch(deployment.ip, {})
    ip = mapping.fetch("ip", deployment.ip)
    port = deployment.ssh_port + mapping.fetch("port_offset", 0)

    log "Connecting to VM for job #{job.runner_name} via SSH (#{ip}:#{port})..."

    attempts = 0
    begin
      conn = Net::SSH.start(ip,
                            "brew",
                            password:        state.config.brew_vm_password,
                            port:,
                            non_interactive: true,
                            verify_host_key: :never,
                            timeout:         5)
    rescue Net::SSH::Exception, SocketError, Errno::ECONNREFUSED,
           Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ECONNRESET,
           Errno::ENETDOWN
      attempts += 1
      raise if attempts > 15 || job.orka_vm_id.nil?

      sleep(15)
      retry
    end

    log "Connected to VM for job #{job.runner_name} via SSH, configuring..."

    url = state.github_runner_metadata.download_urls["osx"]["arm64"]
    org = state.config.github_organisation
    config_args = %W[
      --url "https://github.com/#{org}"
      --token "#{token}"
      --work _work
      --unattended
      --labels "#{job.runner_name}"
      --name "#{job.runner_name}"
      --replace
      --ephemeral
    ]

    cmd = "mkdir -p actions-runner && " \
          "cd actions-runner && " \
          "curl -L \"#{url}\" | tar xz && " \
          "echo 'GITHUB_ACTIONS_HOMEBREW_SELF_HOSTED=1' >> .env && " \
          "./config.sh #{config_args.join(" ")} && " \
          "./svc.sh install && " \
          "./svc.sh start"

    # Net::SSH doesn't handle timeouts well :(
    Timeout.timeout(120) do
      conn.exec!(cmd)
    end

    log "VM for job #{job.runner_name} configured."
    true
  rescue => e
    log("VM configuration for job #{job.runner_name} failed.", error: true)
    log(e, error: true)
    log(e.backtrace, error: true)
    false
  ensure
    conn.close if conn && !conn.closed?
  end
end
