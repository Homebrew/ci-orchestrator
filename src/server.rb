# frozen_string_literal: true

require "sinatra/base"
require "openssl"
require "json"

require_relative "shared_state"

# The app to listen to incoming webhook events.
class CIOrchestratorApp < Sinatra::Base
  LABEL_REGEX = /\A\d+(?:\.\d+)?(?:-arm64)?-\d+-\d+\z/.freeze

  get "/ping" do
    "pong"
  end

  post "/hooks/github" do
    payload_body = request.body.read
    verify_webhook_signature(payload_body)
    payload = JSON.parse(payload_body)

    event = request.env["HTTP_X_GITHUB_EVENT"]
    return if %w[ping installation].include?(event)

    halt 400, "Unsupported event \"#{event}\"!" if event != "workflow_job"

    workflow_job = payload["workflow_job"]
    case payload["action"]
    when "queued"
      workflow_job["labels"].each do |label|
        next unless label =~ LABEL_REGEX

        job = Job.new(runner_name: label)
        SharedState.instance.jobs << job
        SharedState.instance.orka_start_processor.queue << job
      end
    when "in_progress"
      runners_for_job(workflow_job).each do |runner|
        SharedState.instance.job(runner)&.github_state = :in_progress
      end
    when "completed"
      runners_for_job(workflow_job).each do |runner|
        job = SharedState.instance.job(runner)
        next if job.nil?

        job.github_state = :completed
        SharedState.instance.orka_stop_processor.queue << job unless job.orka_vm_id.nil?
      end
    end
  end

  private

  def verify_webhook_signature(payload_body)
    secret = SharedState.instance.config.github_webhook_secret
    signature = "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, payload_body)}"
    return if Rack::Utils.secure_compare(signature, request.env["HTTP_X_HUB_SIGNATURE_256"])

    halt 400, "Signatures didn't match!"
  end

  def runners_for_job(workflow_job)
    if workflow_job["runner_name"]
      [workflow_job["runner_name"]]
    else
      workflow_job["labels"].grep(LABEL_REGEX)
    end
  end
end
