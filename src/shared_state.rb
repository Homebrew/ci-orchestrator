# frozen_string_literal: true

require "singleton"

require "orka_api_client"

require "octokit"
# TODO: upstream these
require_relative "octokit/self_hosted_runner"
require_relative "octokit/hook_deliveries"
require_relative "octokit/actions_workflow_run_attempt"

require "openssl"
require "jwt"
require "base64"

require_relative "github_runner_metadata"
require_relative "job"
require_relative "expired_job"

require_relative "shutdown_exception"
require_relative "orka_start_processor"
require_relative "orka_stop_processor"
require_relative "github_watcher"

# Shared singleton state class used by all other files.
class SharedState
  include Singleton

  # Environment configuration.
  class Config
    attr_reader :state_file,
                :orka_base_url, :orka_token, :orka_ssh_map,
                :github_app_id, :github_app_private_key,
                :github_client_id, :github_client_secret,
                :github_webhook_secret,
                :github_organisation, :github_installation_id,
                :brew_vm_password

    def initialize
      @state_file = ENV.fetch("STATE_FILE")
      @orka_base_url = ENV.fetch("ORKA_BASE_URL")
      @orka_token = ENV.fetch("ORKA_TOKEN")
      @orka_ssh_map = JSON.parse(ENV.fetch("ORKA_SSH_MAP", "{}"))
      @github_app_id = ENV.fetch("GITHUB_APP_ID")
      @github_app_private_key = OpenSSL::PKey::RSA.new(Base64.strict_decode64(ENV.fetch("GITHUB_APP_PRIVATE_KEY")))
      @github_client_id = ENV.fetch("GITHUB_CLIENT_ID")
      @github_client_secret = ENV.fetch("GITHUB_CLIENT_SECRET")
      @github_webhook_secret = ENV.fetch("GITHUB_WEBHOOK_SECRET")
      @github_organisation = ENV.fetch("GITHUB_ORGANISATION")
      @github_installation_id = ENV.fetch("GITHUB_INSTALLATION_ID")
      @brew_vm_password = ENV.fetch("BREW_VM_PASSWORD")
    end

    def to_s
      "Shared Configuration"
    end
    alias inspect to_s
  end

  STATE_VERSION = 1

  MAX_WEBHOOK_REDELIVERY_WINDOW = 21600

  MAX_INTEL_SLOTS = 12
  MAX_ARM_SLOTS = 0

  attr_reader :config,
              :orka_client,
              :orka_mutex, :orka_free_condvar, :github_mutex, :github_metadata_condvar,
              :orka_start_processor, :orka_stop_processor, :github_watcher,
              :github_runner_metadata,
              :jobs, :expired_jobs,
              :pause_mutex, :unpause_condvar

  attr_accessor :last_webhook_check_time

  def initialize
    @config = Config.new

    @orka_client = OrkaAPI::Client.new(@config.orka_base_url, token: @config.orka_token)

    @orka_mutex = Mutex.new
    @orka_free_condvar = ConditionVariable.new
    @github_mutex = Mutex.new
    @github_metadata_condvar = ConditionVariable.new
    @file_mutex = Mutex.new

    @orka_start_processor = OrkaStartProcessor.new
    @orka_stop_processor = OrkaStopProcessor.new
    @github_watcher = GitHubWatcher.new

    @github_runner_metadata = GitHubRunnerMetadata.new

    @jobs = []
    @expired_jobs = []
    @last_webhook_check_time = Time.now.to_i
    @loaded = false
    @paused = false

    @pause_mutex = Mutex.new
    @unpause_condvar = ConditionVariable.new
  end

  def load
    raise "Already loaded state." if @loaded
    raise "Too late to load state." unless @jobs.empty?

    @file_mutex.synchronize do
      state = JSON.parse(File.read(@config.state_file), create_additions: true)
      if state["version"] == STATE_VERSION
        @jobs = state["jobs"]
        @expired_jobs = state["expired_jobs"]
        @last_webhook_check_time = state["last_webhook_check_time"]

        pause if state["paused"]
      end
      @loaded = true
      puts "Loaded #{jobs.count} jobs from state file."
    rescue Errno::ENOENT
      @loaded = true
      puts "No state file found. Assuming fresh start."
      return
    end

    return if @jobs.empty?

    @orka_mutex.synchronize do
      puts "Checking for VMs deleted during downtime..."
      instances = @orka_client.vm_resources.flat_map(&:instances)
      ids = instances.map(&:id)
      @jobs.each do |job|
        # Some VMs might have been deleted while we were in downtime.
        if !job.orka_vm_id.nil? && !ids.include?(job.orka_vm_id)
          puts "Job #{job.runner_name} no longer has a VM."
          job.orka_vm_id = nil
        end

        if job.orka_vm_id.nil?
          if job.github_state == :queued
            if (Time.now.to_i - @last_webhook_check_time) > MAX_WEBHOOK_REDELIVERY_WINDOW
              # Just assume we're done if we've been gone for a while.
              puts "Marking #{job.runner_name} as completed as we've been gone for a while."
              job.github_state = :completed
            else
              puts "Queueing #{job.runner_name} for deployment..."
              @orka_start_processor.queue << job
            end
          else
            puts "Ready to expire #{job.runner_name}."
          end
        elsif job.github_state == :completed || !job.orka_setup_complete?
          puts "Queueing #{job.runner_name} for teardown..."
          @orka_stop_processor.queue << job
        end
      end

      puts "Checking for stuck deployments..."
      instances.each do |instance|
        next if instance.ip != "N/A"

        puts "Deleting stuck deployment #{instance.id}."
        instance.delete
      end
    end
  end

  def save
    @file_mutex.synchronize do
      state = {
        version:                 STATE_VERSION,
        jobs:                    @jobs,
        expired_jobs:            @expired_jobs,
        last_webhook_check_time: @last_webhook_check_time,
        paused:                  @paused,
      }
      File.write(@config.state_file, state.to_json)
    end
  end

  def loaded?
    @loaded
  end

  def pause
    @pause_mutex.synchronize do
      @paused = true
    end
  end

  def unpause
    @pause_mutex.synchronize do
      @paused = false
      @unpause_condvar.broadcast
    end
  end

  def paused?
    @paused
  end

  def jwt_github_client
    payload = {
      iat: Time.now.to_i - 60,
      exp: Time.now.to_i + (9 * 60), # 10 is the max, but let's be safe with 9.
      iss: @config.github_app_id,
    }
    token = JWT.encode(payload, @config.github_app_private_key, "RS256")

    Octokit::Client.new(bearer_token: token)
  end

  def github_client
    return @github_client if @github_client_expiry && (@github_client_expiry.to_i - Time.now.to_i) >= 300

    jwt = jwt_github_client.create_app_installation_access_token(@config.github_installation_id)

    @github_client = Octokit::Client.new(bearer_token: jwt.token)
    @github_client.auto_paginate = true
    @github_client_expiry = jwt.expires_at
    @github_client
  end

  def thread_runners
    [@orka_start_processor, @orka_stop_processor, @github_watcher].freeze
  end

  def job(runner_name)
    @jobs.find { |job| job.runner_name == runner_name }
  end

  def free_slot?(waiting_job)
    max_slots = waiting_job.arm64? ? MAX_ARM_SLOTS : MAX_INTEL_SLOTS
    @jobs.count { |job| job.arm64? == waiting_job.arm64? && !job.orka_vm_id.nil? } < max_slots
  end
end
