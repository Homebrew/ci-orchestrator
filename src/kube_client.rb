# typed: strong
# frozen_string_literal: true

require "dry-inflector"
require "kube-dsl"
require "yaml"

# Client for K8s API.
class KubeClient
  extend T::Sig
  extend T::Helpers

  abstract!

  sig { params(base_uri: String, token: String).void }
  def initialize(base_uri, token:)
    @base_uri = base_uri
    @token = token
    @mutex = T.let(Mutex.new, Mutex)
    @inflector = T.let(Dry::Inflector.new, Dry::Inflector)
  end

  sig do
    type_parameters(:U).params(
      dsl: T.all(T.type_parameter(:U), KubeDSL::DSLObject),
    ).returns(T.type_parameter(:U))
  end
  def get(dsl)
    T.cast(request(:get, dsl.to_resource), T.type_parameter(:U))
  end

  sig do
    type_parameters(:U).params(
      dsl:   T.all(T.type_parameter(:U), KubeDSL::DSLObject),
      block: T.nilable(T.proc.params(candidate: T.type_parameter(:U)).returns(T::Boolean)),
    ).returns(T.type_parameter(:U))
  end
  def watch(dsl, &block)
    result = dsl
    catch :finished do
      request(:watch, dsl.to_resource) do |req|
        req.options.read_timeout = 600

        buffer = +""
        req.options.on_data = lambda do |chunk, _, _|
          buffer += T.let(chunk, String)
          while (line = buffer.slice!(/.+\n/))
            data = T.let(JSON.parse(line), T::Hash[String, T.untyped])

            response = T.cast(
              parse_repsonse(T.let(data["object"], Object)),
              T.all(T.type_parameter(:U), KubeDSL::DSLObject),
            )
            result = response
            throw :finished if T.let(data["type"], T.nilable(String)) == "DELETED" || block&.call(response)
          end
        end
      end
    end
    result
  end

  sig { params(dsl: KubeDSL::DSLObject).returns(KubeDSL::DSLObject) }
  def list(dsl)
    request(:list, dsl.to_resource)
  end

  sig do
    type_parameters(:U).params(
      dsl: T.all(T.type_parameter(:U), KubeDSL::DSLObject),
    ).returns(T.type_parameter(:U))
  end
  def create(dsl)
    T.cast(request(:post, dsl.to_resource), T.type_parameter(:U))
  end

  sig { params(dsl: KubeDSL::DSLObject).returns(KubeDSL::DSLObject) }
  def delete(dsl)
    request(:delete, dsl.to_resource)
  end

  private

  sig do
    params(
      method:   Symbol,
      resource: KubeDSL::Resource,
      block:    T.nilable(T.proc.params(req: Faraday::Request).void),
    ).returns(KubeDSL::DSLObject)
  end
  def request(method, resource, &block)
    retried = T.let(false, T::Boolean)

    begin
      data = resource.serialize
      raise ArgumentError, "Invalid resource" unless data.is_a?(Hash)

      api_version = T.let(data["apiVersion"], T.nilable(String))
      kind = T.let(data["kind"], T.nilable(String))
      raise ArgumentError, "Invalid resource" if api_version.nil? || kind.nil?

      url = +if api_version.include?("/")
        "/apis/"
      else
        "/api/"
      end
      url << api_version

      metadata = T.let(data["metadata"], Object)
      namespace = T.let(metadata["namespace"], T.nilable(String)) if metadata.is_a?(Hash)
      namespace ||= default_namespace
      url << "/namespaces/#{ERB::Util.url_encode(namespace)}" if namespace

      # This is probably not entirely safe but it's good enough for our use case
      url << "/#{ERB::Util.url_encode(@inflector.pluralize(kind.downcase))}"

      if method == :watch
        if metadata.is_a?(Hash)
          name = T.let(metadata["name"], T.nilable(String))
          resource_version = T.let(metadata["resourceVersion"], T.nilable(String))
        end
        raise ArgumentError, "Invalid resource" if name.nil? || resource_version.nil?

        url << "?watch=1" \
            << "&fieldSelector=#{ERB::Util.url_encode("metadata.name=#{name}")}" \
            << "&resourceVersion=#{ERB::Util.url_encode(resource_version)}"
      elsif Faraday::METHODS_WITH_QUERY.include?(method.to_s)
        name = T.let(metadata["name"], T.nilable(String)) if metadata.is_a?(Hash)
        raise ArgumentError, "Invalid resource" if name.nil?

        url << "/#{ERB::Util.url_encode(name)}"
      end

      method = :get if [:list, :watch].include?(method)

      response = T.let(
        client.run_request(method, url, Faraday::METHODS_WITH_BODY.include?(method.to_s) ? data : nil, nil, &block),
        Faraday::Response,
      )
      parse_repsonse(T.let(response.body, Object))
    rescue OpenSSL::SSL::SSLError
      raise if retried

      retried = true
      @mutex.synchronize do
        clear
      end
      retry
    end
  end

  sig { returns(Faraday::Connection) }
  def client
    @mutex.synchronize do
      @client ||= T.let(Faraday.new(
        url: @base_uri,
        ssl: {
          cert_store:,
          min_version: OpenSSL::SSL::TLS1_3_VERSION,
        },
      ) do |faraday|
        faraday.request :authorization, "Bearer", @token
        faraday.request :json
        faraday.response :json
        faraday.response :raise_error
      end, T.nilable(Faraday::Connection))
    end
  end

  sig { abstract.returns(OpenSSL::X509::Store) }
  def cert_store; end

  sig { returns(T.nilable(String)) }
  def default_namespace
    nil
  end

  sig { void }
  def clear
    @client = nil
  end

  sig { params(data: Object).returns(KubeDSL::DSLObject) }
  def parse_repsonse(data)
    raise ArgumentError, "Invalid response" unless data.is_a?(Hash)

    api_version = T.let(data["apiVersion"], T.nilable(String))
    kind = T.let(data["kind"], T.nilable(String))
    raise ArgumentError, "Invalid response" if api_version.nil? || kind.nil?

    dsl_gem = if api_version.start_with?("orka.macstadium.com/")
      OrkaKube
    else
      KubeDSL
    end
    method = T.let(KubeDSL::StringHelpers.underscore(kind), String)

    unless T.let(dsl_gem.const_get(:Entrypoint), Module).method_defined?(method, false) # rubocop:disable Sorbet/ConstantsFromStrings
      raise ArgumentError, "Unsupported response #{kind}"
    end

    parse_field = method(:parse_field)
    T.let(dsl_gem.public_send(method) do
      T.bind(self, KubeDSL::DSLObject)

      data.each do |key, value|
        parse_field.call(self, key, value)
      end
    end, KubeDSL::DSLObject)
  end

  sig { params(obj: KubeDSL::DSLObject, key: String, value: Object).void }
  def parse_field(obj, key, value)
    key = T.let(KubeDSL::StringHelpers.unkeywordify(KubeDSL::StringHelpers.underscore(key)), String)

    fields = T.let(obj.class.__fields__, T::Hash[Symbol, T::Array[T.any(Symbol, T::Hash[Symbol, Symbol])]])
    type, field_key, = fields.lazy.filter_map do |candidate_type, list|
      mapped_key = if candidate_type == :array
        definition = T.cast(
          list,
          T::Array[T::Hash[Symbol, Symbol]],
        ).find { |array_info| array_info[:accessor] == key.to_sym }
        definition[:field].to_s if definition
      elsif list.include?(key.to_sym)
        key
      end
      [candidate_type, mapped_key] if mapped_key
    end.first
    return if type.nil?

    key = T.must(field_key)

    parse_field = method(:parse_field)
    case type
    when :object, :key_value
      obj.public_send(key) do
        T.cast(value, T::Hash[String, T.untyped]).each do |inner_key, inner_value|
          if type == :key_value
            T.bind(self, KubeDSL::KeyValueFields)

            add inner_key.to_sym, T.let(inner_value, String)
          else
            T.bind(self, KubeDSL::DSLObject)

            parse_field.call(self, inner_key, inner_value)
          end
        end
      end
    when :array
      T.cast(value, T::Array[T::Hash[String, T.untyped]]).each do |item|
        obj.public_send(key) do
          item.each do |inner_key, inner_value|
            parse_field.call(self, inner_key, inner_value)
          end
        end
      end
    else
      obj.public_send(key, value)
    end
  end
end
