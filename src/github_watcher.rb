# frozen_string_literal: true

# Thread runner responsible for managing connection to GitHub.
class GitHubWatcher
  def run
    puts "Started #{self.class.name}."

    loop do
      refresh_token
      refresh_download_url
      redeliver_webhooks
      Thread.handle_interrupt(Object => :never) do
        delete_runners
        save_state
      end
      sleep(60)
    end
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
        $stderr.puts("Error retriving runner registration token.")
        return
      end

      metadata.registration_token = token
      state.github_mutex.synchronize do
        state.github_metadata_condvar.broadcast
      end
    end
  rescue => e
    $stderr.puts(e)
    $stderr.puts(e.backtrace)
  end

  def refresh_download_url
    state = SharedState.instance
    metadata = state.github_runner_metadata
    download = metadata.download_url
    if download.nil? || (Time.now.to_i - metadata.download_fetch_time.to_i) > 86400
      begin
        downloads = state.github_client
                         .org_runner_applications(state.config.github_organisation)
        download = downloads.select { |candidate| candidate.os == "osx" && candidate.architecture == "x64" }.first
      rescue Octokit::Error
        $stderr.puts("Error retriving runner download URL.")
        return
      end

      metadata.download_url = download
      metadata.download_fetch_time = Time.now
      state.github_mutex.synchronize do
        state.github_metadata_condvar.broadcast
      end
    end
  rescue => e
    $stderr.puts(e)
    $stderr.puts(e.backtrace)
  end

  def redeliver_webhooks
    state = SharedState.instance
    lookback_time = state.last_webhook_check_time

    # Limit to production and the last 6 hours
    if ENV.fetch("RACK_ENV") == "development" || (Time.now.to_i - lookback_time) > 21600
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

    failed_deliveries.each do |delivery|
      client.redeliver_app_hook(delivery.id)
    rescue Octokit::Error
      $stderr.puts("Failed to redeliver #{delivery.id}.")
    end
  rescue => e
    $stderr.puts(e)
    $stderr.puts(e.backtrace)
  end

  def delete_runners
    state = SharedState.instance
    begin
      runners = state.github_client.org_runners(state.config.github_organisation).runners
    rescue Octokit::Error
      $stderr.puts("Error retriving organisation runner list.")
      return
    end

    state.jobs.delete_if do |job|
      next false if job.github_state == :queued
      next false unless job.orka_vm_id.nil?

      runner = runners.find { |candidate| candidate.name == job.runner_name }
      next true if runner.nil?

      begin
        state.github_client.delete_org_runner(state.config.github_organisation, runner.id)
      rescue Octokit::Error
        $stderr.puts("Error deleting organisation runner for \"#{job.runner_name}\".")
        next false
      end

      true
    end
  rescue => e
    $stderr.puts(e)
    $stderr.puts(e.backtrace)
  end

  def save_state
    SharedState.instance.save
  rescue => e
    $stderr.puts(e)
    $stderr.puts(e.backtrace)
  end
end
