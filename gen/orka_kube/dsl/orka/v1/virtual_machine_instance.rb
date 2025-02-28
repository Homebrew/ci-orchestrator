# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class VirtualMachineInstance < ::KubeDSL::DSLObject
          object_field(:metadata) { KubeDSL::DSL::Meta::V1::ObjectMeta.new }
          object_field(:spec) { OrkaKube::DSL::Orka::V1::VirtualMachineInstanceSpec.new }
          object_field(:status) { OrkaKube::DSL::Orka::V1::VirtualMachineInstanceStatus.new }

          validates :metadata, object: { kind_of: KubeDSL::DSL::Meta::V1::ObjectMeta }
          validates :spec, object: { kind_of: OrkaKube::DSL::Orka::V1::VirtualMachineInstanceSpec }
          validates :status, object: { kind_of: OrkaKube::DSL::Orka::V1::VirtualMachineInstanceStatus }

          def serialize
            {}.tap do |result|
              result[:apiVersion] = "orka.macstadium.com/v1"
              result[:kind] = "VirtualMachineInstance"
              result[:metadata] = metadata.serialize
              result[:spec] = spec.serialize
              result[:status] = status.serialize
            end
          end

          def kind_sym
            :virtual_machine_instance
          end
        end
      end
    end
  end
end