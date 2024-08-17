# typed: strong
# frozen_string_literal: true

module GitHub
  # @see https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#list-self-hosted-runners-for-an-organization
  class Runner < T::Struct
    prop :id, Integer
    prop :name, String
  end
end
