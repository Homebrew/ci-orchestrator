# frozen_string_literal: true

require "net/ssh"
require "timeout"

# Thread runner responsible for deploying Orka VMs.
class OrkaStartProcessor
  CONFIG_MAP = {
    "10.15"    => "catalina",
    "11"       => "bigsur",
    "12"       => "monterey",
    "12-arm64" => "monterey-arm64",
  }.freeze

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
        state = SharedState.instance
        next unless job.orka_vm_id.nil?

        github_metadata = state.github_runner_metadata
        github_mutex = state.github_mutex
        github_mutex.synchronize do
          while github_metadata.registration_token.nil? ||
                (github_metadata.registration_token.expires_at.to_i - Time.now.to_i) < 300 ||
                github_metadata.download_url.nil?
            puts "Waiting for GitHub metadata..."
            state.github_metadata_condvar.wait(github_mutex)
          end
        end

        vm_metadata = unless job.arm64?
          {
            token:       github_metadata.registration_token.token,
            label:       job.runner_name,
            name:        job.runner_name,
            config_args: "--ephemeral",
            download:    github_metadata.download_url,
          }
        end

        # TODO: node?
        result = nil
        state.orka_mutex.synchronize do
          until state.free_slot?(job)
            puts "Job #{job.runner_name} is waiting for a free slot."
            state.orka_free_condvar.wait(state.orka_mutex)
          end

          if job.github_state != :queued
            puts "Job #{job.runner_name} no longer in queued state, skipping."
            next
          end

          Thread.handle_interrupt(ShutdownException => :never) do
            puts "Deploying VM for job #{job.runner_name}..."
            result = state.orka_client
                          .vm_configuration(CONFIG_MAP[job.os])
                          .deploy(vm_metadata: vm_metadata)
            job.orka_start_attempts += 1
            job.orka_vm_id = result.resource.name
            job.orka_setup_complete = true unless vm_metadata.nil?
            puts "VM for job #{job.runner_name} deployed (#{job.orka_vm_id})."
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
      $stderr.puts(e)
      $stderr.puts(e.backtrace)
      sleep(30)
    end
  end

  private

  def setup_actions_runner(deployment, job, token)
    state = SharedState.instance
    mapping = state.config.orka_ssh_map.fetch(deployment.ip, {})
    ip = mapping.fetch("ip", deployment.ip)
    port = deployment.ssh_port + mapping.fetch("port_offset", 0)

    puts "Connecting to VM for job #{job.runner_name} via SSH (#{ip}:#{port})..."

    attempts = 0
    begin
      conn = Net::SSH.start(ip,
                            "brew",
                            password:        state.config.brew_vm_password,
                            port:            port,
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

    puts "Connected to VM for job #{job.runner_name} via SSH, configuring..."

    url = "https://github.com/Bo98/runner/releases/download/v2.290.1/actions-runner-osx-arm64-2.290.1.tar.gz"
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

    # COMPlus_ReadyToRun=0 needed because of https://github.com/dotnet/runtime/issues/64103
    cmd = "mkdir -p actions-runner && " \
          "cd actions-runner && " \
          "curl -L \"#{url}\" | tar xz && " \
          "echo 'GITHUB_ACTIONS_HOMEBREW_SELF_HOSTED=1' >> .env && " \
          "plutil -insert EnvironmentVariables.COMPlus_ReadyToRun -string 0 bin/actions.runner.plist.template && " \
          "COMPlus_ReadyToRun=0 ./config.sh #{config_args.join(" ")} && " \
          "./svc.sh install && " \
          "./svc.sh start"

    # Net::SSH doesn't handle timeouts well :(
    Timeout.timeout(120) do
      conn.exec!(cmd)
    end

    puts "VM for job #{job.runner_name} configured."
    true
  rescue => e
    $stderr.puts("VM configuration for job #{job.runner_name} failed.")
    $stderr.puts(e)
    $stderr.puts(e.backtrace)
    false
  ensure
    conn.close if conn && !conn.closed?
  end
end
