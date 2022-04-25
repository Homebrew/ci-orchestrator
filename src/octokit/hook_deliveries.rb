# frozen_string_literal: true

module Octokit
  # Client extensions
  class Client
    # Methods for the Hooks API (extension)
    module HookDeliveries
      def app_hook_deliveries(options = {})
        paginate "app/hook/deliveries", options
      end
      alias list_app_hook_deliveries app_hook_deliveries

      def redeliver_app_hook(delivery_id, options = {})
        boolean_from_response :post, "app/hook/deliveries/#{delivery_id}/attempts", options
      end
    end

    include HookDeliveries
  end
end
