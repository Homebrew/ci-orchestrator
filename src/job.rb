# frozen_string_literal: true

require "securerandom"

require_relative "queue_types"

# Information representing a CI job.
class Job
  NAME_REGEX =
    /\A(?<runner>\d+(?:\.\d+)?(?:-arm64|-cross)?)-(?<run_id>\d+)(?:-(?<run_attempt>\d+))?(?:-(?<tag>[a-z]+))?\z/

  attr_reader :runner_name, :repository, :github_id, :secret
  attr_writer :orka_setup_timeout
  attr_accessor :github_state, :orka_vm_id, :orka_setup_time, :orka_start_attempts, :runner_completion_time

  def initialize(runner_name, repository, github_id, secret: nil)
    raise ArgumentError, "Runner name needs a run attempt" if runner_name[NAME_REGEX, :run_attempt].nil?

    @runner_name = runner_name
    @repository = repository
    @github_id = github_id
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

  def tag
    @runner_name[NAME_REGEX, :tag]
  end

  def runner_labels
    @runner_labels ||= begin
      runner_name_no_attempt = runner_name.sub(NAME_REGEX) do |match|
        start_off, end_off = Regexp.last_match.offset(:run_attempt)
        match.slice!((start_off - 1)...end_off)
        match
      end
      [@runner_name, runner_name_no_attempt].freeze
    end
  end

  def orka_setup_complete?
    !@orka_setup_time.nil? && !@orka_setup_timeout
  end

  def orka_setup_timeout?
    @orka_setup_timeout
  end

  def queue_type
    if arm64?
      QueueTypes::MACOS_ARM64
    elsif os.partition("-").first < "13"
      QueueTypes::MACOS_X86_64_LEGACY
    else
      QueueTypes::MACOS_X86_64
    end
  end

  def self.json_create(object)
    job = new(object["runner_name"], object["repository"], object["github_id"], secret: object["secret"])
    job.github_state = object["github_state"].to_sym
    job.orka_vm_id = object["orka_vm_id"]
    job.orka_setup_time = object["orka_setup_time"]
    job.orka_setup_timeout = object["orka_setup_timeout"]
    job.orka_start_attempts = object["orka_start_attempts"]
    job.runner_completion_time = object["runner_completion_time"]
    job
  end

  def to_json(*)
    {
      JSON.create_id           => self.class.name,
      "runner_name"            => @runner_name,
      "repository"             => @repository,
      "github_id"              => @github_id,
      "github_state"           => @github_state,
      "orka_vm_id"             => @orka_vm_id,
      "orka_setup_time"        => @orka_setup_time,
      "orka_setup_timeout"     => @orka_setup_timeout,
      "orka_start_attempts"    => @orka_start_attempts,
      "secret"                 => @secret,
      "runner_completion_time" => @runner_completion_time,
    }.to_json(*)
  end
end
