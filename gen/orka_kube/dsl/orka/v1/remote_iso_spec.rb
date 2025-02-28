# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class RemoteIsoSpec < ::KubeDSL::DSLObject
          value_field :iso_name

          validates :iso_name, field: { format: :string }, presence: true

          def serialize
            {}.tap do |result|
              result[:isoName] = iso_name
            end
          end

          def kind_sym
            :remote_iso_spec
          end
        end
      end
    end
  end
end