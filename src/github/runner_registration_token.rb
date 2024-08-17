# typed: strong
# frozen_string_literal: true

module GitHub
  # @see https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-a-registration-token-for-an-organization
  class RunnerRegistrationToken < T::Struct
    prop :token, String
    prop :expires_at, Time
  end
end
