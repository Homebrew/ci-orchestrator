# typed: strong
# frozen_string_literal: true

# Information needed to connect a runner to GitHub.
class GitHubRunnerMetadata
  extend T::Sig

  sig { returns(T.nilable(GitHub::RunnerRegistrationToken)) }
  attr_accessor :registration_token

  sig { returns(T.nilable(T::Hash[String, T::Hash[String, GitHub::RunnerApplication]])) }
  attr_accessor :download_urls

  sig { returns(T.nilable(Time)) }
  attr_accessor :download_fetch_time

  sig { void }
  def initialize
    @registration_token = nil
    @download_urls = T.let(nil, T.nilable(T::Hash[String, T::Hash[String, GitHub::RunnerApplication]]))
    @download_fetch_time = T.let(nil, T.nilable(Time))
  end

  sig { params(job: Job).returns(GitHub::RunnerApplication) }
  def runner_application_for_job(job)
    raise "Download URLs not ready!" if @download_urls.nil?

    runner_application = @download_urls.dig("osx", job.arm64? ? "arm64" : "x64")
    raise "No runner application found for #{job.runner_name}!" if runner_application.nil?

    runner_application
  end

  sig { override.returns(String) }
  def to_s
    "Runner Metadata"
  end
  alias inspect to_s
end
