# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class OrkaNodeSpec < ::KubeDSL::DSLObject
          value_field :namespace
          value_field :tags

          validates :namespace, field: { format: :string }, presence: true
          validates :tags, field: { format: :string }, presence: true

          def serialize
            {}.tap do |result|
              result[:namespace] = namespace
              result[:tags] = tags
            end
          end

          def kind_sym
            :orka_node_spec
          end
        end
      end
    end
  end
end