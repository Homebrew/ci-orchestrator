# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class VirtualMachineConfigList < ::KubeDSL::DSLObject
          array_field(:item) { OrkaKube::DSL::Orka::V1::VirtualMachineConfig.new }
          object_field(:metadata) { KubeDSL::DSL::Meta::V1::ListMeta.new }

          validates :items, array: { kind_of: OrkaKube::DSL::Orka::V1::VirtualMachineConfig }, presence: false
          validates :metadata, object: { kind_of: KubeDSL::DSL::Meta::V1::ListMeta }

          def serialize
            {}.tap do |result|
              result[:apiVersion] = "orka.macstadium.com/v1"
              result[:items] = items.map(&:serialize)
              result[:kind] = "VirtualMachineConfigList"
              result[:metadata] = metadata.serialize
            end
          end

          def kind_sym
            :virtual_machine_config_list
          end
        end
      end
    end
  end
end