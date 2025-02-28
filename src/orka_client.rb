# typed: strong
# frozen_string_literal: true

require_relative "kube_client"
require "orka_kube"

# Client for Orka K8s API.
class OrkaClient < KubeClient
  sig { params(base_uri: String, token: String).void }
  def initialize(base_uri, token:)
    @cluster_client = T.let(Faraday.new(base_uri) do |faraday|
      faraday.response :json
      faraday.response :raise_error
    end, Faraday::Connection)

    api_domain = T.let(cluster_info["apiDomain"], T.nilable(String))
    raise "No API domain found" if api_domain.nil?

    # TEMPORARY WORKAROUND
    endpoint = T.let(cluster_info["apiEndpoint"], String)
    port = URI(endpoint).port

    super("https://#{api_domain}:#{port}", token:)
  end

  private

  sig { returns(T::Hash[String, T.untyped]) }
  def cluster_info
    @cluster_info ||= T.let(begin
      response = T.let(@cluster_client.get("/api/v1/cluster-info"), Faraday::Response)
      T.let(response.body, T::Hash[String, T.untyped])
    end, T.nilable(T::Hash[String, T.untyped]))
  end

  sig { override.returns(OpenSSL::X509::Store) }
  def cert_store
    cert_data = T.let(cluster_info["certData"], T.nilable(String))
    raise "No cert data found" if cert_data.nil?

    store = OpenSSL::X509::Store.new
    store.add_cert(OpenSSL::X509::Certificate.new(cert_data))
    store
  end

  sig { override.returns(T.nilable(String)) }
  def default_namespace
    "orka-default"
  end

  sig { override.void }
  def clear
    super
    @cluster_info = nil
  end
end
