# typed: strict
# frozen_string_literal: true

require "octokit"
# TODO: upstream these
require_relative "octokit/self_hosted_runner"
require_relative "octokit/actions_workflow_run_attempt"

require_relative "github/app_hook_delivery"
require_relative "github/generated_jit_config"
require_relative "github/runner_application"
require_relative "github/runner"

# Type-safe wrapper for Octokit.
class GitHubClient
  extend T::Sig

  sig { params(org: String, username: String).returns(T::Boolean) }
  def organization_member?(org, username)
    octokit_client.organization_member?(org, username)
  end

  sig { params(org: String, name: String, labels: T::Array[String]).returns(GitHub::GeneratedJITConfig) }
  def generate_jitconfig(org, name:, labels:)
    result = octokit_client.generate_jit_config(org, name:, labels:, runner_group_id: 1)
    GitHub::GeneratedJITConfig.new(runner_id: result.runner.id, encoded_jit_config: result.encoded_jit_config)
  end

  sig { params(org: String).returns(T::Hash[String, T::Hash[String, GitHub::RunnerApplication]]) }
  def org_runner_applications(org)
    applications = octokit_client.org_runner_applications(org)
    download_urls = T.let({}, T::Hash[String, T::Hash[String, GitHub::RunnerApplication]])
    applications.each do |candidate|
      os_map = (download_urls[candidate.os] ||= {})
      os_map[candidate.architecture] = GitHub::RunnerApplication.new(
        url:    candidate.download_url,
        sha256: candidate.sha256_checksum,
      )
    end
    download_urls
  end

  sig { params(since: Integer).returns(T::Array[GitHub::AppHookDelivery]) }
  def app_hook_deliveries(since:)
    client = jwt_octokit_client
    client.per_page = 100

    deliveries = T.let([], T::Array[GitHub::AppHookDelivery])
    page = client.list_app_hook_deliveries
    loop do
      filtered = page.select { |delivery| delivery.delivered_at.to_i >= since }
      deliveries += filtered.map do |delivery|
        GitHub::AppHookDelivery.new(
          id:           delivery.id,
          delivered_at: delivery.delivered_at,
          status_code:  delivery.status_code,
          event:        delivery.event,
        )
      end

      break if page.length != filtered.length # We found the cut-off

      next_rel = client.last_response.rels[:next]
      break if next_rel.nil? # No more pages

      page = client.get(next_rel.href)
    end

    deliveries
  end

  sig { params(id: Integer).void }
  def deliver_app_hook(id)
    jwt_octokit_client.deliver_app_hook(id)
  end

  sig { params(org: String, id: Integer).returns(GitHub::Runner) }
  def org_runner(org, id:)
    runner = octokit_client.org_runner(org, id)
    GitHub::Runner.new(
      id:   runner.id,
      name: runner.name,
    )
  end

  sig { params(org: String).returns(T::Array[GitHub::Runner]) }
  def org_runners(org)
    octokit_client.org_runners(org).runners.map do |runner|
      GitHub::Runner.new(
        id:   runner.id,
        name: runner.name,
      )
    end
  end

  sig { params(org: String, runner: GitHub::Runner).void }
  def delete_org_runner(org, runner)
    octokit_client.delete_org_runner(org, runner.id)
  end

  sig { params(repo: String, run_id: Integer, run_attempt: Integer).returns(String) }
  def workflow_run_attempt_status(repo, run_id, run_attempt)
    octokit_client.workflow_run_attempt(repo, run_id, run_attempt).status
  end

  sig { params(repo: String, job_id: Integer).returns(String) }
  def workflow_run_job_status(repo, job_id)
    octokit_client.workflow_run_job(repo, job_id).status
  end

  private

  sig { returns(Octokit::Client) }
  def jwt_octokit_client
    config = SharedState.instance.config
    payload = {
      iat: Time.now.to_i - 60,
      exp: Time.now.to_i + (9 * 60), # 10 is the max, but let's be safe with 9.
      iss: config.github_client_id,
    }
    token = JWT.encode(payload, config.github_app_private_key, "RS256")

    Octokit::Client.new(bearer_token: token)
  end

  sig { returns(Octokit::Client) }
  def octokit_client
    @octokit_client = nil if @octokit_client_expiry.nil? || (@octokit_client_expiry.to_i - Time.now.to_i) < 300

    @octokit_client ||= T.let(begin
      installation_id = SharedState.instance.config.github_installation_id
      jwt = jwt_octokit_client.create_app_installation_access_token(installation_id)

      client = Octokit::Client.new(bearer_token: jwt.token)
      client.auto_paginate = true
      @octokit_client_expiry = T.let(jwt.expires_at, T.nilable(Time))
      client
    end, T.nilable(Octokit::Client))
  end
end
