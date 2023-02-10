# frozen_string_literal: true

# Information representing a CI job that we are no longer tracking.
class ExpiredJob
  attr_reader :runner_name, :expired_at

  def initialize(runner_name, expired_at:)
    @runner_name = runner_name
    @expired_at = expired_at
  end

  def ==(other)
    if other.is_a?(String)
      runner_name == other
    else
      self.class == other.class && runner_name == other.runner_name
    end
  end

  def eql?(other)
    self.class == other.class && self == other
  end

  def self.json_create(object)
    new(object["runner_name"], expired_at: object["expired_at"])
  end

  def to_json(*)
    {
      JSON.create_id => self.class.name,
      "runner_name"  => @runner_name,
      "expired_at"   => @expired_at,
    }.to_json(*)
  end
end
