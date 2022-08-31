# frozen_string_literal: true

module Octokit
  # Client extensions
  class Client
    # Methods for the Actions Workflows runs API (extension)
    module ActionsWorkflowRunAttempt
      def workflow_run_attempt(repo, id, attempt_number, options = {})
        get "#{Repository.path repo}/actions/runs/#{id}/attempts/#{attempt_number}", options
      end
    end

    include ActionsWorkflowRunAttempt
  end
end
