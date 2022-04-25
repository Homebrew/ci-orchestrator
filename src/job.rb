# frozen_string_literal: true

# Information representing a CI job.
class Job
  attr_reader :runner_name
  attr_accessor :github_state, :orka_vm_id

  def initialize(runner_name)
    @runner_name = runner_name
    @github_state = :queued
    @orka_vm_id = nil
  end

  def os
    @runner_name[/^\d+(?:\.\d+)?(?:-arm64)?/]
  end

  def arm64?
    os.end_with?("-arm64")
  end

  def self.json_create(object)
    job = new(object["runner_name"])
    job.github_state = object["github_state"].to_sym
    job.orka_vm_id = object["orka_vm_id"]
    job
  end

  def to_json(*args)
    {
      JSON.create_id => self.class.name,
      "runner_name"  => @runner_name,
      "github_state" => @github_state,
      "orka_vm_id"   => @orka_vm_id,
    }.to_json(*args)
  end
end
