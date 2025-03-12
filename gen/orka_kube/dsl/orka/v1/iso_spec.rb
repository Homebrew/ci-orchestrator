# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class IsoSpec < ::KubeDSL::DSLObject
          value_field :source
          value_field :source_type

          validates :source, field: { format: :string }, presence: false
          validates :source_type, field: { format: :string }, presence: false

          def serialize
            {}.tap do |result|
              result[:source] = source
              result[:sourceType] = source_type
            end
          end

          def kind_sym
            :iso_spec
          end
        end
      end
    end
  end
end