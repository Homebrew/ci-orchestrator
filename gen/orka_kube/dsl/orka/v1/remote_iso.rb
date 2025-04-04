# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class RemoteIso < ::KubeDSL::DSLObject
          object_field(:metadata) { KubeDSL::DSL::Meta::V1::ObjectMeta.new }
          object_field(:spec) { OrkaKube::DSL::Orka::V1::RemoteIsoSpec.new }

          validates :metadata, object: { kind_of: KubeDSL::DSL::Meta::V1::ObjectMeta }
          validates :spec, object: { kind_of: OrkaKube::DSL::Orka::V1::RemoteIsoSpec }

          def serialize
            {}.tap do |result|
              result[:apiVersion] = "orka.macstadium.com/v1"
              result[:kind] = "RemoteIso"
              result[:metadata] = metadata.serialize
              result[:spec] = spec.serialize
            end
          end

          def kind_sym
            :remote_iso
          end
        end
      end
    end
  end
end