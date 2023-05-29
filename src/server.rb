# frozen_string_literal: true

require "sinatra/base"
require "logger"
require "openssl"
require "json"
require "securerandom"

require_relative "shared_state"

# The app to listen to incoming webhook events.
class CIOrchestratorApp < Sinatra::Base
  configure do
    set :sessions, expire_after: 28800, same_site: :lax, skip: true
    set :session_store, Rack::Session::Pool
    set :protection, reaction: :deny, logger: Logger.new($stderr)
  end

  helpers ERB::Util

  set(:require_auth) do |enabled|
    return unless enabled

    condition do
      request.session_options[:skip] = false

      if (auth_failed = session.delete(:auth_failed))
        halt auth_failed[:code], auth_failed[:message]
      end

      if settings.development?
        session[:username] = "localhost"
        return
      end

      state = SharedState.instance

      if session[:github_access_token] && (session[:github_access_token][:expires] - Time.now.to_i) >= 300
        if session[:auth_validated_at] && (Time.now.to_i - session[:auth_validated_at]) < 600
          return if session[:username]

          halt 403, "Forbidden."
        end

        client = Octokit::Client.new(access_token: session[:github_access_token][:token])
        user_info = begin
          client.user
        rescue Octokit::Error => e
          if e.response_status >= 500 || (Time.now.to_i - session[:github_access_token][:issued]) < 30
            halt 500, "Auth failed."
          end

          nil
        end

        unless user_info.nil?
          username = user_info.login
          begin
            org_member = state.github_client.organization_member?(state.config.github_organisation, username)
          rescue Octokit::Error
            halt 500, "Auth failed."
          end

          session[:auth_validated_at] = Time.now.to_i
          if org_member
            session[:username] = username
            return
          end

          session[:username] = nil
          halt 403, "Forbidden."
        end
      end

      client_id = state.config.github_client_id
      auth_state = SecureRandom.hex(32)
      session[:auth_state] = auth_state
      url = "https://github.com/login/oauth/authorize?client_id=#{client_id}&state=#{auth_state}&allow_signup=false"
      redirect url, 302
    end
  end

  get "/auth/github" do
    request.session_options[:skip] = false

    if params["state"] == session[:auth_state]
      state = SharedState.instance
      client = Octokit::Client.new(client_id:     state.config.github_client_id,
                                   client_secret: state.config.github_client_secret)

      begin
        token_response = client.exchange_code_for_token(params["code"])
      rescue Octokit::Error => e
        session[:auth_failed] = {
          code:    e.response_status,
          message: "Auth failed.",
        }
      else
        session[:github_access_token] = {
          token:   token_response.access_token,
          issued:  Time.now.to_i,
          expires: Time.now.to_i + token_response.expires_in,
        }
      end
    else
      session[:auth_failed] = {
        code:    400,
        message: "Invalid auth state.",
      }
    end

    redirect "/", 302
  end

  get "/", require_auth: true do
    erb :index, locals: { state: SharedState.instance, username: session[:username] }
  end

  get "/robots.txt" do
    content_type :txt
    <<~TEXT
      User-agent: *
      Disallow: /
    TEXT
  end

  post "/pause", require_auth: true do
    thread_runner_name = params["thread_runner"]
    if thread_runner_name
      thread_runner = SharedState.instance.thread_runners.find { |runner| runner.name == thread_runner_name }
      if thread_runner&.pausable?
        thread_runner.pause
      else
        halt 400, "Invalid thread runner."
      end
    else
      SharedState.instance.thread_runners.each { |runner| runner.pause if runner.pausable? }
    end
    redirect "/", 302
  end

  post "/unpause", require_auth: true do
    thread_runner_name = params["thread_runner"]
    if thread_runner_name
      thread_runner = SharedState.instance.thread_runners.find { |runner| runner.name == thread_runner_name }
      if thread_runner&.pausable?
        thread_runner.unpause
      else
        halt 400, "Invalid thread runner."
      end
    else
      SharedState.instance.thread_runners.each { |runner| runner.unpause if runner.pausable? }
    end
    redirect "/", 302
  end

  post "/hooks/github" do
    payload_body = request.body.read
    verify_webhook_signature(payload_body)
    payload = JSON.parse(payload_body)

    event = request.env["HTTP_X_GITHUB_EVENT"]
    return if %w[ping installation github_app_authorization].include?(event)

    halt 400, "Unsupported event \"#{event}\"!" if event != "workflow_job"

    workflow_job = payload["workflow_job"]
    return if workflow_job.nil? # GitHub rarely sends webhooks with the workflow_job payload set to null.

    state = SharedState.instance

    case payload["action"]
    when "queued"
      runner = runner_for_job(workflow_job, only_unassigned: true)
      next if runner.nil?

      # If we've seen this job before, don't queue again.
      next if state.expired_jobs.include?(runner)

      # Job already exists?
      job = state.job(runner)
      unless job.nil?
        $stderr.puts("Job #{runner} already known.")
        next
      end

      job = Job.new(runner, payload["repository"]["name"], workflow_job["id"])
      state.jobs << job
      state.orka_start_processors[job.queue_type].queue << job
    when "in_progress"
      runner = runner_for_job(workflow_job)
      next if runner.nil?

      job = state.job(runner)
      if job.nil?
        expire_missed_job(runner)
        next
      end

      job.github_state = :in_progress if job.github_state != :completed
    when "completed"
      runner = runner_for_job(workflow_job)
      next if runner.nil?

      job = state.job(runner)
      if job.nil?
        expire_missed_job(runner)
        next
      end

      if job.github_state != :completed
        job.github_state = :completed
        state.orka_stop_processor.queue << job unless job.orka_vm_id.nil?
      end
    end

    "Accepted"
  end

  post "/hooks/runner_ready" do
    job = verify_runner_hook(params)
    return if job.nil?

    vm_id = params["orka_vm_id"]

    if job.orka_vm_id.nil?
      return if job.github_state == :completed && job.orka_setup_complete?

      job.orka_vm_id = vm_id
      job.orka_setup_time = Time.now.to_i
      job.orka_setup_timeout = false
    elsif job.orka_vm_id != vm_id
      $stderr.puts("Got ready request for #{runner_name} from an unexpected VM (#{job.orka_vm_id} != #{vm_id}).")
      return
    end

    "Accepted"
  end

  post "/hooks/runner_job_completed" do
    job = verify_runner_hook(params)
    return if job.nil?

    if job.orka_vm_id.nil?
      $stderr.puts("Got stop request for #{runner_name} from a VM that shouldn't exist.")
      return
    end

    job.runner_completion_time = Time.now.to_i

    "Accepted"
  end

  private

  def verify_webhook_signature(payload_body)
    secret = SharedState.instance.config.github_webhook_secret
    signature = "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload_body)}"
    return if Rack::Utils.secure_compare(signature, request.env["HTTP_X_HUB_SIGNATURE_256"])

    halt 400, "Signatures didn't match!"
  end

  def verify_runner_hook(params)
    runner_name = params["runner_name"]
    halt 400, "Invalid request." if runner_name.to_s.strip.empty?

    job = SharedState.instance.job(runner_name)
    return if job.nil?

    if job.secret != params["orchestrator_secret"]
      $stderr.puts("Secret mismatch for #{runner_name}!")
      halt 403, "Forbidden."
    end

    job
  end

  def runner_for_job(workflow_job, only_unassigned: false)
    if workflow_job["runner_name"].to_s.empty?
      workflow_job["labels"].filter_map do |label|
        match_data = label.match(Job::NAME_REGEX)
        next if match_data.nil?
        next label unless match_data[:run_attempt].nil?

        _, end_off = match_data.offset(:run_id)
        label.dup.insert(end_off, "-#{workflow_job["run_attempt"]}")
      end.first
    elsif !only_unassigned
      workflow_job["runner_name"]
    end
  end

  def expire_missed_job(runner)
    return unless runner.match?(Job::NAME_REGEX)

    state = SharedState.instance
    return if state.expired_jobs.include?(runner)

    state.expired_jobs << ExpiredJob.new(runner, expired_at: Time.now.to_i)
  end
end
