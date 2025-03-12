# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class RemoteImageSpec < ::KubeDSL::DSLObject
          value_field :image_name

          validates :image_name, field: { format: :string }, presence: true

          def serialize
            {}.tap do |result|
              result[:imageName] = image_name
            end
          end

          def kind_sym
            :remote_image_spec
          end
        end
      end
    end
  end
end