# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class OrkaNode < ::KubeDSL::DSLObject
          object_field(:metadata) { KubeDSL::DSL::Meta::V1::ObjectMeta.new }
          object_field(:spec) { OrkaKube::DSL::Orka::V1::OrkaNodeSpec.new }
          object_field(:status) { OrkaKube::DSL::Orka::V1::OrkaNodeStatus.new }

          validates :metadata, object: { kind_of: KubeDSL::DSL::Meta::V1::ObjectMeta }
          validates :spec, object: { kind_of: OrkaKube::DSL::Orka::V1::OrkaNodeSpec }
          validates :status, object: { kind_of: OrkaKube::DSL::Orka::V1::OrkaNodeStatus }

          def serialize
            {}.tap do |result|
              result[:apiVersion] = "orka.macstadium.com/v1"
              result[:kind] = "OrkaNode"
              result[:metadata] = metadata.serialize
              result[:spec] = spec.serialize
              result[:status] = status.serialize
            end
          end

          def kind_sym
            :orka_node
          end
        end
      end
    end
  end
end