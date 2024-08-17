# typed: strong
# frozen_string_literal: true

require "securerandom"

require_relative "queue_type"

# Information representing a CI job.
class Job
  extend T::Sig

  NAME_REGEX = /
    \A
      (?<runner>\d+(?:\.\d+)?(?:-(?:arm|x86_)64)?(?:-cross)?)
      -(?<run_id>\d+)
      (?:-(?<run_attempt>\d+))?
      (?:-(?<tags>[-a-z]+))?
    \z
  /x

  sig { returns(String) }
  attr_reader :runner_name

  sig { returns(String) }
  attr_reader :repository

  sig { returns(Integer) }
  attr_reader :github_id

  sig { returns(String) }
  attr_reader :secret

  sig { returns(PriorityType) }
  attr_reader :priority_type

  sig { params(orka_setup_timeout: T::Boolean).returns(T::Boolean) }
  attr_writer :orka_setup_timeout

  sig { returns(Symbol) }
  attr_accessor :github_state

  sig { returns(T.nilable(String)) }
  attr_accessor :orka_vm_id

  sig { returns(T.nilable(Integer)) }
  attr_accessor :orka_setup_time

  sig { returns(Integer) }
  attr_accessor :orka_start_attempts

  sig { returns(T.nilable(Integer)) }
  attr_accessor :runner_completion_time

  sig { params(runner_name: String, repository: String, github_id: Integer, secret: T.nilable(String)).void }
  def initialize(runner_name, repository, github_id, secret: nil)
    raise ArgumentError, "Runner name needs a run attempt" if runner_name[NAME_REGEX, :run_attempt].nil?

    @runner_name = runner_name
    @repository = repository
    @github_id = github_id
    @github_state = T.let(:queued, Symbol)
    @orka_vm_id = nil
    @orka_setup_time = nil
    @orka_setup_timeout = T.let(false, T::Boolean)
    @orka_start_attempts = T.let(0, Integer)
    @secret = T.let(secret || SecureRandom.hex(32), String)
    @runner_completion_time = nil

    priority_type = if dispatch_job?
      PriorityType::Dispatch
    elsif long_build?
      PriorityType::Long
    else
      PriorityType::Default
    end
    @priority_type = T.let(priority_type, PriorityType)
  end

  sig { returns(String) }
  def os
    T.must(@runner_name[NAME_REGEX, :runner])
  end

  sig { returns(T::Boolean) }
  def arm64?
    os.split("-").include?("arm64")
  end

  sig { returns(Integer) }
  def run_id
    T.must(@runner_name[NAME_REGEX, :run_id]).to_i
  end

  sig { returns(Integer) }
  def run_attempt
    T.must(@runner_name[NAME_REGEX, :run_attempt]).to_i
  end

  sig { returns(T::Array[String]) }
  def tags
    @runner_name[NAME_REGEX, :tags]&.split("-").to_a
  end

  sig { returns(T::Boolean) }
  def dispatch_job?
    tags.include?("dispatch")
  end

  sig { returns(T::Boolean) }
  def long_build?
    tags.include?("long")
  end

  sig { returns(T::Array[String]) }
  def runner_labels
    @runner_labels ||= T.let(begin
      runner_name_no_attempt = runner_name.sub(NAME_REGEX) do |match|
        start_off, end_off = T.cast(T.must(Regexp.last_match).offset(:run_attempt), [Integer, Integer])
        match.slice!((start_off - 1)...end_off)
        match
      end
      [@runner_name, runner_name_no_attempt].freeze
    end, T.nilable(T::Array[String]))
  end

  sig { returns(T::Boolean) }
  def orka_setup_complete?
    !@orka_setup_time.nil? && !@orka_setup_timeout
  end

  sig { returns(T::Boolean) }
  def orka_setup_timeout?
    @orka_setup_timeout
  end

  sig { returns(QueueType) }
  def queue_type
    if arm64?
      QueueType::MacOS_Arm64
    elsif os.partition("-").first < "13"
      QueueType::MacOS_x86_64_Legacy
    else
      QueueType::MacOS_x86_64
    end
  end

  sig { params(object: T::Hash[String, T.untyped]).returns(T.attached_class) }
  def self.json_create(object)
    job = new(
      T.cast(object["runner_name"], String),
      T.cast(object["repository"], String),
      T.cast(object["github_id"], Integer),
      secret: T.cast(object["secret"], T.nilable(String)),
    )
    job.github_state = T.cast(object["github_state"], String).to_sym
    job.orka_vm_id = T.cast(object["orka_vm_id"], T.nilable(String))
    job.orka_setup_time = T.cast(object["orka_setup_time"], T.nilable(Integer))
    job.orka_setup_timeout = T.cast(object["orka_setup_timeout"], T::Boolean)
    job.orka_start_attempts = T.cast(object["orka_start_attempts"], Integer)
    job.runner_completion_time = T.cast(object["runner_completion_time"], T.nilable(Integer))
    job
  end

  sig { params(state: T.nilable(JSON::State)).returns(String) }
  def to_json(state)
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
    }.to_json(state)
  end
end
