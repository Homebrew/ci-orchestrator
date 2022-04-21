# frozen_string_literal: true

module Octokit
  # Client extensions
  class Client
    # Methods for the Actions Self-hosted Runners API
    #
    # @see https://developer.github.com/v3/actions/self-hosted-runners
    module ActionsSelfHostedRunners
      def create_org_runner_registration_token(org, options = {})
        post "#{Organization.path org}/actions/runners/registration-token", options
      end

      def org_runners(org, options = {})
        paginate "#{Organization.path org}/actions/runners", options
      end

      def delete_org_runner(org, runner_id, options = {})
        boolean_from_response :delete, "#{Organization.path org}/actions/runners/#{runner_id}", options
      end

      def org_runner_applications(org, options = {})
        get "#{Organization.path org}/actions/runners/downloads", options
      end
      alias list_org_runner_applications org_runner_applications
    end

    include ActionsSelfHostedRunners
  end
end
