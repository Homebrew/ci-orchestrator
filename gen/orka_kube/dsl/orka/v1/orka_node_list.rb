# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class OrkaNodeList < ::KubeDSL::DSLObject
          array_field(:item) { OrkaKube::DSL::Orka::V1::OrkaNode.new }
          object_field(:metadata) { KubeDSL::DSL::Meta::V1::ListMeta.new }

          validates :items, array: { kind_of: OrkaKube::DSL::Orka::V1::OrkaNode }, presence: false
          validates :metadata, object: { kind_of: KubeDSL::DSL::Meta::V1::ListMeta }

          def serialize
            {}.tap do |result|
              result[:apiVersion] = "orka.macstadium.com/v1"
              result[:items] = items.map(&:serialize)
              result[:kind] = "OrkaNodeList"
              result[:metadata] = metadata.serialize
            end
          end

          def kind_sym
            :orka_node_list
          end
        end
      end
    end
  end
end