# typed: strong
# frozen_string_literal: true

require "singleton"

require "openssl"
require "jwt"
require "base64"

require_relative "orka_client"
require_relative "github_client"
require_relative "github_runner_metadata"
require_relative "job"
require_relative "expired_job"

require_relative "shutdown_exception"
require_relative "orka_start_processor"
require_relative "orka_stop_processor"
require_relative "orka_timeout_processor"
require_relative "github_watcher"

# Shared singleton state class used by all other files.
class SharedState
  extend T::Sig
  include Singleton

  # Environment configuration.
  class Config
    extend T::Sig

    sig { returns(String) }
    attr_reader :state_file

    sig { returns(String) }
    attr_reader :orka_base_url

    sig { returns(String) }
    attr_reader :orka_token

    sig { returns(OpenSSL::PKey::RSA) }
    attr_reader :github_app_private_key

    sig { returns(String) }
    attr_reader :github_client_id

    sig { returns(String) }
    attr_reader :github_client_secret

    sig { returns(String) }
    attr_reader :github_webhook_secret

    sig { returns(String) }
    attr_reader :github_organisation

    sig { returns(String) }
    attr_reader :github_installation_id

    sig { void }
    def initialize
      @state_file = T.let(ENV.fetch("STATE_FILE"), String)
      @orka_base_url = T.let(ENV.fetch("ORKA_BASE_URL"), String)
      @orka_token = T.let(ENV.fetch("ORKA_TOKEN"), String)
      @github_app_private_key = T.let(
        OpenSSL::PKey::RSA.new(Base64.strict_decode64(ENV.fetch("GITHUB_APP_PRIVATE_KEY"))),
        OpenSSL::PKey::RSA,
      )
      @github_client_id = T.let(ENV.fetch("GITHUB_CLIENT_ID"), String)
      @github_client_secret = T.let(ENV.fetch("GITHUB_CLIENT_SECRET"), String)
      @github_webhook_secret = T.let(ENV.fetch("GITHUB_WEBHOOK_SECRET"), String)
      @github_organisation = T.let(ENV.fetch("GITHUB_ORGANISATION"), String)
      @github_installation_id = T.let(ENV.fetch("GITHUB_INSTALLATION_ID"), String)
    end

    sig { override.returns(String) }
    def to_s
      "Shared Configuration"
    end
    alias inspect to_s
  end

  STATE_VERSION = 1

  MAX_WEBHOOK_REDELIVERY_WINDOW = 21600

  sig { returns(Config) }
  attr_reader :config

  sig { returns(OrkaClient) }
  attr_reader :orka_client

  sig { returns(GitHubClient) }
  attr_reader :github_client

  sig { returns(Mutex) }
  attr_reader :github_mutex

  sig { returns(ConditionVariable) }
  attr_reader :github_metadata_condvar

  sig { returns(T::Hash[QueueType, OrkaStartProcessor]) }
  attr_reader :orka_start_processors

  sig { returns(OrkaStopProcessor) }
  attr_reader :orka_stop_processor

  sig { returns(OrkaTimeoutProcessor) }
  attr_reader :orka_timeout_processor

  sig { returns(GitHubWatcher) }
  attr_reader :github_watcher

  sig { returns(GitHubRunnerMetadata) }
  attr_reader :github_runner_metadata

  sig { returns(T::Array[Job]) }
  attr_reader :jobs

  sig { returns(T::Array[ExpiredJob]) }
  attr_reader :expired_jobs

  sig { returns(Integer) }
  attr_accessor :last_webhook_check_time

  sig { void }
  def initialize
    @config = T.let(Config.new, Config)

    @orka_client = T.let(OrkaClient.new(@config.orka_base_url, token: @config.orka_token), OrkaClient)
    @github_client = T.let(GitHubClient.new, GitHubClient)

    @github_mutex = T.let(Mutex.new, Mutex)
    @github_metadata_condvar = T.let(ConditionVariable.new, ConditionVariable)
    @file_mutex = T.let(Mutex.new, Mutex)

    @orka_start_processors = T.let(QueueType.values.to_h do |type|
      [type, OrkaStartProcessor.new(type, type.name)]
    end, T::Hash[QueueType, OrkaStartProcessor])
    @orka_stop_processor = T.let(OrkaStopProcessor.new, OrkaStopProcessor)
    @orka_timeout_processor = T.let(OrkaTimeoutProcessor.new, OrkaTimeoutProcessor)
    @github_watcher = T.let(GitHubWatcher.new, GitHubWatcher)

    @github_runner_metadata = T.let(GitHubRunnerMetadata.new, GitHubRunnerMetadata)

    @jobs = T.let([], T::Array[Job])
    @expired_jobs = T.let([], T::Array[ExpiredJob])
    @last_webhook_check_time = T.let(Time.now.to_i, Integer)
    @loaded = T.let(false, T::Boolean)
  end

  sig { void }
  def load
    raise "Already loaded state." if @loaded
    raise "Too late to load state." unless @jobs.empty?

    @file_mutex.synchronize do
      state = T.cast(JSON.parse(File.read(@config.state_file), create_additions: true), T::Hash[String, T.untyped])
      if T.cast(state["version"], Integer) == STATE_VERSION
        @jobs = state["jobs"]
        @expired_jobs = state["expired_jobs"]
        @last_webhook_check_time = state["last_webhook_check_time"]

        load_pause_data T.cast(state["paused"], T::Array[String])
      end
      @loaded = true
      puts "Loaded #{jobs.count} jobs from state file."
    rescue Errno::ENOENT
      @loaded = true
      puts "No state file found. Assuming fresh start."
      return
    end

    return if @jobs.empty?

    puts "Checking for VMs deleted during downtime..."

    instances = T.cast(
      @orka_client.list(OrkaKube.virtual_machine_instance),
      OrkaKube::DSL::Orka::V1::VirtualMachineInstanceList,
    ).items
    ids = instances.map { |instance| instance.metadata.name }
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
          elsif !job.orka_setup_timeout?
            puts "Queueing #{job.runner_name} for deployment..."
            @orka_start_processors.fetch(job.queue_type).queue << job
          end
        else
          puts "Ready to expire #{job.runner_name}."
        end
      elsif job.github_state == :completed || !job.orka_setup_complete?
        puts "Queueing #{job.runner_name} for teardown..."
        @orka_stop_processor.queue << job
      end
    end
  end

  sig { void }
  def save
    @file_mutex.synchronize do
      state = {
        version:                 STATE_VERSION,
        jobs:                    @jobs,
        expired_jobs:            @expired_jobs,
        last_webhook_check_time: @last_webhook_check_time,
        paused:                  thread_runners.filter_map do |thread_runner|
          next unless thread_runner.pausable?
          next unless thread_runner.paused?

          thread_runner.name
        end,
      }
      File.write(@config.state_file, state.to_json)
    end
  end

  sig { returns(T::Boolean) }
  def loaded?
    @loaded
  end

  sig { returns(T::Array[ThreadRunner]) }
  def thread_runners
    [*@orka_start_processors.values, @orka_stop_processor, @orka_timeout_processor, @github_watcher].freeze
  end

  sig { params(runner_name: String).returns(T.nilable(Job)) }
  def job(runner_name)
    @jobs.find { |job| job.runner_name == runner_name }
  end

  sig { params(waiting_job: Job).returns(T::Boolean) }
  def free_slot?(waiting_job)
    max_slots = waiting_job.queue_type.slots
    @jobs.count { |job| job.queue_type == waiting_job.queue_type && !job.orka_vm_id.nil? } < max_slots
  end

  sig { params(queue_type: QueueType).returns(T::Array[Job]) }
  def running_jobs(queue_type)
    jobs.select { |job| job.queue_type == queue_type && !job.orka_vm_id.nil? }
  end

  private

  sig { params(pause_data: T::Array[String]).void }
  def load_pause_data(pause_data)
    pause_data.each do |key|
      thread_runner = thread_runners.find { |runner| runner.name == key }
      if thread_runner.nil?
        T.cast($stderr, IO).puts("Can't find thread runner #{key} to pause.")
      elsif thread_runner.pausable?
        thread_runner.pause
      end
    end
  end
end
