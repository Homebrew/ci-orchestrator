# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class IsoStatus < ::KubeDSL::DSLObject
          value_field :error_message
          value_field :last_updated_timestamp
          value_field :state

          validates :error_message, field: { format: :string }, presence: false
          validates :last_updated_timestamp, field: { format: :string }, presence: false
          validates :state, field: { format: :string }, presence: false

          def serialize
            {}.tap do |result|
              result[:errorMessage] = error_message
              result[:lastUpdatedTimestamp] = last_updated_timestamp
              result[:state] = state
            end
          end

          def kind_sym
            :iso_status
          end
        end
      end
    end
  end
end