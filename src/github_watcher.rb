# frozen_string_literal: true

require_relative "thread_runner"

# Thread runner responsible for managing connection to GitHub.
class GitHubWatcher < ThreadRunner
  def run
    log "Started #{self.class.name}."

    loop do
      refresh_token
      refresh_download_urls
      redeliver_webhooks
      Thread.handle_interrupt(ShutdownException => :never) do
        delete_runners
        cleanup_expired_jobs
        save_state
      end
      sleep(60)
    end
  rescue ShutdownException
    # Exit gracefully
  end

  private

  def refresh_token
    state = SharedState.instance
    metadata = state.github_runner_metadata
    token = metadata.registration_token
    if token.nil? || (token.expires_at.to_i - Time.now.to_i) < 600
      begin
        token = state.github_client
                     .create_org_runner_registration_token(state.config.github_organisation)
      rescue Octokit::Error
        log("Error retriving runner registration token.", error: true)
        return
      end

      metadata.registration_token = token
      state.github_mutex.synchronize do
        state.github_metadata_condvar.broadcast
      end
    end
  rescue ShutdownException
    Thread.current.kill
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end

  def refresh_download_urls
    state = SharedState.instance
    metadata = state.github_runner_metadata
    if metadata.download_urls.nil? || (Time.now.to_i - metadata.download_fetch_time.to_i) > 86400
      begin
        applications = state.github_client
                            .org_runner_applications(state.config.github_organisation)
        download_urls = {}
        applications.each do |candidate|
          download_urls[candidate.os] ||= {}
          download_urls[candidate.os][candidate.architecture] = candidate.download_url
        end
      rescue Octokit::Error
        log("Error retriving runner download URL.", error: true)
        return
      end

      if download_urls.dig("osx", "x64").nil? || download_urls.dig("osx", "arm64").nil?
        log("Did not find all expected runner downloads.", error: true)
        return
      end

      metadata.download_urls = download_urls
      metadata.download_fetch_time = Time.now
      state.github_mutex.synchronize do
        state.github_metadata_condvar.broadcast
      end
    end
  rescue ShutdownException
    Thread.current.kill
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end

  def redeliver_webhooks
    state = SharedState.instance
    lookback_time = state.last_webhook_check_time

    # Limit to production and the last 6 hours
    if ENV.fetch("RACK_ENV") == "development" ||
       (Time.now.to_i - lookback_time) > SharedState::MAX_WEBHOOK_REDELIVERY_WINDOW
      log "Not attempting to redeliver webhooks."
      state.last_webhook_check_time = Time.now.to_i
      return
    end

    client = state.jwt_github_client
    client.per_page = 100

    current_time = Time.now.to_i

    deliveries = []
    page = client.app_hook_deliveries
    loop do
      filtered = page.select { |delivery| delivery.delivered_at.to_i >= lookback_time }
      deliveries += filtered

      break if page.length != filtered.length # We found the cut-off

      next_rel = client.last_response.rels[:next]
      break if next_rel.nil? # No more pages

      page = client.get(next_rel.href)
    end

    # Fetch successful, mark the last check time.
    state.last_webhook_check_time = current_time

    failed_deliveries = deliveries.select do |delivery|
      # No need to redeliver if successful.
      next false if delivery.status_code < 400

      # Don't care if it's not a workflow_job
      next false if delivery.event != "workflow_job"

      true
    end

    log "Asking for redelivery of #{failed_deliveries.length} hook events..." unless failed_deliveries.empty?
    failed_deliveries.each do |delivery|
      client.redeliver_app_hook(delivery.id)
    rescue Octokit::Error
      log("Failed to redeliver #{delivery.id}.", error: true)
    end
    log "Redelivery requests sent." unless failed_deliveries.empty?
  rescue ShutdownException
    Thread.current.kill
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end

  def delete_runners
    state = SharedState.instance
    begin
      runners = state.github_client.org_runners(state.config.github_organisation).runners
    rescue Octokit::Error
      log("Error retriving organisation runner list.", error: true)
      return
    end

    expired_jobs, jobs_left = state.jobs.partition do |job|
      next false if job.github_state == :queued
      next false unless job.orka_vm_id.nil?

      runner = runners.find { |candidate| candidate.name == job.runner_name }
      next true if runner.nil?

      log "Deleting organisation runner for #{job.runner_name}..."
      begin
        state.github_client.delete_org_runner(state.config.github_organisation, runner.id)
        log "Organisation runner for #{job.runner_name} deleted."
      rescue Octokit::Error
        log("Error deleting organisation runner for \"#{job.runner_name}\".", error: true)
        next false
      end

      true
    end

    state.jobs.replace(jobs_left)

    log "Marking #{expired_jobs.length} jobs as expired." unless expired_jobs.empty?
    expired_jobs.map! do |job|
      ExpiredJob.new(job.runner_name, expired_at: Time.now.to_i)
    end
    state.expired_jobs.concat(expired_jobs)
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end

  def cleanup_expired_jobs
    current_time = Time.now.to_i
    SharedState.instance.expired_jobs.delete_if do |job|
      job.expired_at < (current_time - 86400) # Forget after one day.
    end
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end

  def save_state
    SharedState.instance.save
  rescue => e
    log(e, error: true)
    log(e.backtrace, error: true)
  end
end
