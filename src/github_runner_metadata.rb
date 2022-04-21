# frozen_string_literal: true

# Information needed to connect a runner to GitHub.
class GitHubRunnerMetadata
  attr_accessor :registration_token, :download_url, :download_fetch_time

  def initialize
    @registration_token = nil
    @download_url = nil
    @download_fetch_time = nil
  end
end
