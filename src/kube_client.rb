# typed: strong
# frozen_string_literal: true

require "kube-dsl"
require "yaml"

# Client for K8s API.
class KubeClient
  extend T::Sig

  sig { params(base_uri: String).void }
  def initialize(base_uri)
    @base_uri = base_uri
    @inflector = T.let(Dry::Inflector.new, Dry::Inflector)
  end

  sig { params(resource: KubeDSL::Resource).void }
  def create(resource)
    data = resource.serialize
    raise ArgumentError, "Invalid resource" unless data.is_a?(Hash)

    apiVersion = T.cast(data["apiVersion"], T.nilable(String))
    kind = T.cast(data["kind"], T.nilable(String))
    raise ArgumentError, "Invalid resource" if apiVersion.nil? || kind.nil?

    url = +if apiVersion.include?("/")
      "/apis/"
    else
      "/api/"
    end
    url << apiVersion

    metadata = T.cast(data["metadata"], Object)
    namespace = T.cast(metadata["namespace"], T.nilable(String)) if metadata.is_a?(Hash)
    url << "/namespaces/#{namespace}" if namespace

    # This is probably not entirely safe but it's good enough for our use case
    url << "/#{@inflector.pluralize(kind.downcase)}"

    response = client.post(url, data)
    # p response
    # p response.body
  end

  private

  sig { returns(Faraday::Connection) }
  def client
    @client ||= T.let(Faraday.new(
      url:     @base_uri,
      ssl:     {
        cert_store:,
        min_version: OpenSSL::SSL::TLS1_3_VERSION,
      },
    ) do |faraday|
      faraday.request :authorization, "Bearer", "TODO"

      faraday.request :json
      faraday.response :json
      faraday.response :raise_error
    end, T.nilable(Faraday::Connection))
  end

  sig { returns(T.nilable(OpenSSL::X509::Store)) }
  def cert_store
    nil
  end
end
