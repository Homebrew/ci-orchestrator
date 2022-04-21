# frozen_string_literal: true

# Thread runner responsible for managing connection to GitHub.
class GitHubWatcher
  def run
    puts "Started #{self.class.name}."

    loop do
      refresh_token
      refresh_download_url
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

  def delete_runners
    state = SharedState.instance
    github_client = state.github_client
    begin
      runners = github_client.org_runners(state.config.github_organisation).runners
    rescue Octokit::Error
      return
    end

    state.jobs.delete_if do |job|
      next false if job.github_state == :queued
      next false unless job.orka_vm_id.nil?

      runner = runners.find { |candidate| candidate.name == job.runner_name }
      next true if runner.nil?

      begin
        github_client.delete_org_runner(state.config.github_organisation, runner.id)
      rescue Octokit::Error
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
