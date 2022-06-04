# frozen_string_literal: true

# Information needed to connect a runner to GitHub.
class GitHubRunnerMetadata
  attr_accessor :registration_token, :download_urls, :download_fetch_time

  def initialize
    @registration_token = nil
    @download_urls = nil
    @download_fetch_time = nil
  end

  def to_s
    "Runner Metadata"
  end
  alias inspect to_s
end
