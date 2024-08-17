# typed: strong
# frozen_string_literal: true

module GitHub
  # @see https://docs.github.com/en/rest/apps/webhooks?apiVersion=2022-11-28#list-deliveries-for-an-app-webhook
  class AppHookDelivery < T::Struct
    prop :id, Integer
    prop :delivered_at, Time
    prop :status_code, Integer
    prop :event, String
  end
end
