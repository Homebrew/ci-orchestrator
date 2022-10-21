# frozen_string_literal: true

require "securerandom"

require_relative "queue_types"

# Information representing a CI job.
class Job
  NAME_REGEX = /\A(?<runner>\d+(?:\.\d+)?(?:-arm64|-cross)?)-(?<run_id>\d+)-(?<run_attempt>\d+)\z/

  attr_reader :runner_name, :repository, :secret
  attr_writer :orka_setup_timeout
  attr_accessor :github_state, :orka_vm_id, :orka_setup_time, :orka_start_attempts, :runner_completion_time

  def initialize(runner_name, repository, secret: nil)
    @runner_name = runner_name
    @repository = repository
    @github_state = :queued
    @orka_vm_id = nil
    @orka_setup_time = nil
    @orka_setup_timeout = false
    @orka_start_attempts = 0
    @secret = secret || SecureRandom.hex(32)
    @runner_completion_time = nil
  end

  def os
    @runner_name[NAME_REGEX, :runner]
  end

  def arm64?
    os.end_with?("-arm64")
  end

  def run_id
    @runner_name[NAME_REGEX, :run_id]
  end

  def run_attempt
    @runner_name[NAME_REGEX, :run_attempt]
  end

  def orka_setup_complete?
    !@orka_setup_time.nil?
  end

  def orka_setup_timeout?
    @orka_setup_timeout
  end

  def queue_type
    arm64? ? QueueTypes::MACOS_ARM64 : QueueTypes::MACOS_X86_64
  end

  def self.json_create(object)
    job = new(object["runner_name"], object["repository"], secret: object["secret"])
    job.github_state = object["github_state"].to_sym
    job.orka_vm_id = object["orka_vm_id"]
    job.orka_setup_time = if (setup_time = object["orka_setup_time"])
      setup_time
    elsif object["orka_setup_complete"] # backcompat - can be removed after deployment
      Time.now.to_i
    end
    job.orka_start_attempts = object["orka_start_attempts"]
    job.runner_completion_time = object["runner_completion_time"]
    job
  end

  def to_json(*args)
    {
      JSON.create_id           => self.class.name,
      "runner_name"            => @runner_name,
      "repository"             => @repository,
      "github_state"           => @github_state,
      "orka_vm_id"             => @orka_vm_id,
      "orka_setup_time"        => @orka_setup_time,
      "orka_start_attempts"    => @orka_start_attempts,
      "secret"                 => @secret,
      "runner_completion_time" => @runner_completion_time,
    }.to_json(*args)
  end
end
