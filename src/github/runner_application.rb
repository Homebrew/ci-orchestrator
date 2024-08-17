# typed: strong
# frozen_string_literal: true

module GitHub
  # @see https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#list-runner-applications-for-an-organization
  class RunnerApplication < T::Struct
    prop :url, String
    prop :sha256, String
  end
end
