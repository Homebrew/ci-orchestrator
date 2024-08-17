# typed: strong
# frozen_string_literal: true

# Information representing a CI job that we are no longer tracking.
class ExpiredJob
  extend T::Sig

  sig { returns(String) }
  attr_reader :runner_name

  sig { returns(Integer) }
  attr_reader :expired_at

  sig { params(runner_name: String, expired_at: Integer).void }
  def initialize(runner_name, expired_at:)
    @runner_name = runner_name
    @expired_at = expired_at
  end

  sig { override.params(other: BasicObject).returns(T::Boolean) }
  def ==(other)
    case other
    when String
      runner_name == other
    when self.class
      runner_name == other.runner_name
    else
      false
    end
  end

  sig { override.params(other: BasicObject).returns(T::Boolean) }
  def eql?(other)
    case other
    when self.class
      self == other
    else
      false
    end
  end

  sig { params(object: T::Hash[String, T.untyped]).returns(T.attached_class) }
  def self.json_create(object)
    new(T.cast(object["runner_name"], String), expired_at: T.cast(object["expired_at"], Integer))
  end

  sig { params(state: T.nilable(JSON::State)).returns(String) }
  def to_json(state)
    {
      JSON.create_id => self.class.name,
      "runner_name"  => @runner_name,
      "expired_at"   => @expired_at,
    }.to_json(state)
  end
end
