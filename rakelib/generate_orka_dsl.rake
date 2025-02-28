# typed: strict
# frozen_string_literal: true

T.bind(self, T.all(Rake::DSL, Object))

desc "Generates OrkaKube files"
task :generate_orka_dsl do
  require "kube-dsl"
  require "tmpdir"
  require "open3"
  require "json"
  require "dry/inflector"

  Dir.mktmpdir do |dir|
    schema_dir = "#{dir}/schema"

    output, status = Open3.capture2("kubectl", "get", "--context", "orka", "--raw", "/openapi/v3")
    raise "Failed to fetch OpenAPI v3 index" unless status.success?

    openapi_v3_index = JSON.parse(output)
    orka_openapi_url = openapi_v3_index.dig("paths", "apis/orka.macstadium.com/v1", "serverRelativeURL")
    raise "Failed to find Orka APIs" if orka_openapi_url.nil?

    output, status = Open3.capture2("kubectl", "get", "--context", "orka", "--raw", orka_openapi_url)
    raise "Failed to fetch Orka OpenAPI v3" unless status.success?

    File.write("#{dir}/orka-openapi.json", output)

    system "python3", "-m", "venv", "#{dir}/venv"
    system "#{dir}/venv/bin/pip", "install", "openapi2jsonschema2"
    system "#{dir}/venv/bin/openapi2jsonschema2", "#{dir}/orka-openapi.json",
           "--kubernetes",
           "--expanded",
           "--output", schema_dir

    # Don't generate base k8s files
    all = JSON.load_file("#{schema_dir}/all.json")
    all["oneOf"].select! do |type|
      type["$ref"].start_with?("com.macstadium.")
    end
    File.write("#{schema_dir}/all.json", JSON.pretty_generate(all))

    Dir.each_child(schema_dir) do |file|
      next if file == "all.json"

      json = JSON.load_file("#{schema_dir}/#{file}")

      # Add enum values to apiVersion and kind
      if json.key?("x-kubernetes-group-version-kind")
        json["x-kubernetes-group-version-kind"].each do |gvk|
          group, version, kind = gvk.values_at("group", "version", "kind")

          if json["properties"].key?("apiVersion")
            api_version = if group
              "#{group}/#{version}"
            else
              version
            end
            enum = (json["properties"]["apiVersion"]["enum"] ||= [])
            enum << api_version unless enum.include?(api_version)
          end

          if json["properties"].key?("kind")
            enum = (json["properties"]["kind"]["enum"] ||= [])
            enum << kind unless enum.include?(kind)
          end
        end
      end

      # Convert references to older OpenAPI 2 format that kube-dsl understands
      if json.key?("properties")
        json["properties"].each_value do |property|
          if property.key?("allOf") && !property.key?("$ref") && property["allOf"].length == 1
            property["$ref"] = property["allOf"].first["$ref"]
          end
        end
      end

      File.write("#{schema_dir}/#{file}", JSON.pretty_generate(json))
    end

    generator = KubeDSL::Generator.new(
      schema_dir:,
      output_dir:           "gen",
      autoload_prefix:      "orka_kube/dsl",
      dsl_namespace:        %w[OrkaKube DSL],
      entrypoint_namespace: %w[OrkaKube],
      inflector:            Dry::Inflector.new do |inflections|
        inflections.acronym("DSL")
      end,
    )
    generator.builder.register_resolver("") do |ref|
      ref = ref.delete_suffix(".json")

      if ref.start_with?("com.macstadium.")
        generator.builder.parse_ref(ref)
      else
        # Use base KubeDSL types otherwise
        KubeDSL::Ref.new(
          ref,
          %w[KubeDSL DSL],
          generator.builder.inflector,
          schema_dir,
          generator.builder.autoload_prefix,
          generator.builder.serialize_handlers,
        )
      end
    end

    rm_f "gen/orka_kube.rb"
    rm_rf "gen/orka_kube"
    rm_rf "sorbet/rbi/orka_kube"

    generator.generate

    cp "sorbet/rbi/gems/.gitattributes", "sorbet/rbi/orka_kube/"

    # Fix entrypoint
    autoload_lines = File.read("gen/orka_kube.rb").strip.split("\n")
    autoload_lines.insert(
      -2,
      "  autoload :Entrypoint, 'orka_kube/entrypoint'",
      "",
      "  extend Entrypoint",
    )
    File.write("gen/orka_kube.rb", autoload_lines.join("\n"))
  end
end
