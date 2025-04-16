# typed: strong
# frozen_string_literal: true

module GitHub
  # @see https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-configuration-for-a-just-in-time-runner-for-an-organization
  class GeneratedJITConfig < T::Struct
    extend T::Sig

    prop :runner_id, Integer
    prop :encoded_jit_config, String, sensitivity: ["token"]

    sig { params(object: T::Hash[String, T.untyped]).returns(T.attached_class) }
    def self.json_create(object)
      T.let(from_hash(object), T.attached_class)
    end

    sig { params(state: T.nilable(JSON::State)).returns(String) }
    def to_json(state)
      hash = T.let(serialize, T::Hash[T.untyped, T.untyped])
      hash[JSON.create_id] = self.class.name

      T.let(hash.to_json(state), String)
    end
  end
end
