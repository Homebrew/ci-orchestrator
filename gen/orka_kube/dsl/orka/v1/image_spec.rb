# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class ImageSpec < ::KubeDSL::DSLObject
          value_field :checksum
          value_field :destination
          value_field :owner
          value_field :source
          value_field :source_namespace
          value_field :source_type

          validates :checksum, field: { format: :string }, presence: false
          validates :destination, field: { format: :string }, presence: false
          validates :owner, field: { format: :string }, presence: false
          validates :source, field: { format: :string }, presence: false
          validates :source_namespace, field: { format: :string }, presence: false
          validates :source_type, field: { format: :string }, presence: false

          def serialize
            {}.tap do |result|
              result[:checksum] = checksum
              result[:destination] = destination
              result[:owner] = owner
              result[:source] = source
              result[:sourceNamespace] = source_namespace
              result[:sourceType] = source_type
            end
          end

          def kind_sym
            :image_spec
          end
        end
      end
    end
  end
end