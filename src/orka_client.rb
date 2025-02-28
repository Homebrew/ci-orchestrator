# typed: strong
# frozen_string_literal: true

require_relative "kube_client"
require "orka_kube"

# Client for Orka K8s API.
class OrkaClient < KubeClient
  sig { params(base_uri: String).void }
  def initialize(base_uri)
    @cluster_client = T.let(Faraday.new(base_uri) do |faraday|
      faraday.response :json
      faraday.response :raise_error
    end, Faraday::Connection)

    endpoint = T.cast(cluster_info["apiEndpoint"], T.nilable(String))
    raise "No API endpoint found" if endpoint.nil?

    super(endpoint)
  end

  private

  sig { returns(T::Hash[String, T.untyped]) }
  def cluster_info
    @cluster_info ||= T.let(begin
      response = T.cast(@cluster_client.get("/api/v1/cluster-info"), Faraday::Response)
      T.cast(response.body, T::Hash[String, T.untyped])
    end, T.nilable(T::Hash[String, T.untyped]))
  end

  sig { override.returns(OpenSSL::X509::Store) }
  def cert_store
    @cert_store ||= T.let(begin
      cert_data = T.cast(cluster_info["certData"], T.nilable(String))
      raise "No cert data found" if cert_data.nil?

      store = OpenSSL::X509::Store.new
      store.add_cert(OpenSSL::X509::Certificate.new(cert_data))
      store
    end, T.nilable(OpenSSL::X509::Store))
  end
end
