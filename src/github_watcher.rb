# typed: strong
# frozen_string_literal: true

require_relative "thread_runner"

# Thread runner responsible for managing connection to GitHub.
class GitHubWatcher < ThreadRunner
  sig { override.void }
  def run
    log "Started #{name}."

    loop do
      refresh_download_urls
      redeliver_webhooks
      Thread.handle_interrupt(ShutdownException => :never) do
        delete_runners
        timeout_queued_and_deployed
        timeout_completed_jobs
        cleanup_expired_jobs
        save_state
      end
      sleep(60)
    end
  rescue ShutdownException
    # Exit gracefully
  end

  private

  sig { void }
  def refresh_download_urls
    state = SharedState.instance
    metadata = state.github_runner_metadata
    if metadata.download_urls.nil? || (Time.now.to_i - metadata.download_fetch_time.to_i) > 86400
      begin
        download_urls = state.github_client.org_runner_applications(state.config.github_organisation)
      rescue Octokit::Error
        log("Error retrieving runner download URL.", error: true)
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
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
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

    current_time = Time.now.to_i
    deliveries = state.github_client.app_hook_deliveries(since: lookback_time)

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
      state.github_client.deliver_app_hook(delivery.id)
    rescue Octokit::Error
      log("Failed to redeliver #{delivery.id}.", error: true)
    end
    log "Redelivery requests sent." unless failed_deliveries.empty?
  rescue ShutdownException
    Thread.current.kill
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
  def delete_runners
    state = SharedState.instance
    begin
      runners = state.github_client.org_runners(state.config.github_organisation)
    rescue Octokit::Error
      log("Error retrieving organisation runner list.", error: true)
      return
    end

    expired_jobs, jobs_left = state.jobs.partition do |job|
      next false if job.github_state == :queued
      next false unless job.orka_vm_id.nil?

      runner = runners.find { |candidate| candidate.name == job.runner_name }
      next true if runner.nil?

      log "Deleting organisation runner for #{job.runner_name}..."
      begin
        state.github_client.delete_org_runner(state.config.github_organisation, runner)
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
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
  def timeout_queued_and_deployed
    state = SharedState.instance
    current_time = Time.now.to_i
    run_statuses = T.let({}, T::Hash[String, String])
    state.jobs.each do |job|
      next if job.orka_setup_timeout?
      next if (orka_setup_time = job.orka_setup_time).nil? || (current_time - orka_setup_time) < 900
      next if job.github_state != :queued
      next if job.orka_vm_id.nil?

      run_key = "#{job.run_id}-#{job.run_attempt}"
      repo = "#{state.config.github_organisation}/#{job.repository}"

      unless run_statuses.key?(run_key)
        begin
          run_statuses[run_key] = state.github_client.workflow_run_attempt_status(repo, job.run_id, job.run_attempt)
        rescue Octokit::Error
          log("Error retrieving workflow run information for #{run_key}.", error: true)
          next
        end
      end

      job_state = if run_statuses[run_key] == "completed"
        "completed"
      else
        state.github_client.workflow_run_job_status(repo, job.github_id)
      end

      case job_state
      when "queued"
        log "Job #{run_key} has likely stuck #{job.os} runner. Redeploying..."
        job.orka_setup_time = nil
        state.orka_stop_processor.queue << job
      when "in_progress"
        log "Job #{run_key} in progress, but #{job.os} runner still queued. Marking as in progress..."
        job.github_state = :in_progress
      when "completed"
        log "Job #{run_key} completed, but #{job.os} runner still queued. Destroying..."
        job.github_state = :completed
        state.orka_stop_processor.queue << job
      end
    end
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
  def timeout_completed_jobs
    state = SharedState.instance
    current_time = Time.now.to_i
    state.jobs.each do |job|
      next if (completion_time = job.runner_completion_time).nil? || (current_time - completion_time) < 600
      next if job.github_state == :completed
      next if job.orka_vm_id.nil?

      log "#{job.runner_name} reported completion 10 minutes ago but GitHub hasn't reported back. Stopping runner..."

      job.github_state = :completed
      state.orka_stop_processor.queue << job
    end
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
  def cleanup_expired_jobs
    current_time = Time.now.to_i
    SharedState.instance.expired_jobs.delete_if do |job|
      job.expired_at < (current_time - 86400) # Forget after one day.
    end
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end

  sig { void }
  def save_state
    SharedState.instance.save
  rescue => e
    log(e.to_s, error: true)
    log(e.backtrace.to_s, error: true)
  end
end
