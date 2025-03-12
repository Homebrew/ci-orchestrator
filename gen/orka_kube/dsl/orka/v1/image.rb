# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class Image < ::KubeDSL::DSLObject
          object_field(:metadata) { KubeDSL::DSL::Meta::V1::ObjectMeta.new }
          object_field(:spec) { OrkaKube::DSL::Orka::V1::ImageSpec.new }
          object_field(:status) { OrkaKube::DSL::Orka::V1::ImageStatus.new }

          validates :metadata, object: { kind_of: KubeDSL::DSL::Meta::V1::ObjectMeta }
          validates :spec, object: { kind_of: OrkaKube::DSL::Orka::V1::ImageSpec }
          validates :status, object: { kind_of: OrkaKube::DSL::Orka::V1::ImageStatus }

          def serialize
            {}.tap do |result|
              result[:apiVersion] = "orka.macstadium.com/v1"
              result[:kind] = "Image"
              result[:metadata] = metadata.serialize
              result[:spec] = spec.serialize
              result[:status] = status.serialize
            end
          end

          def kind_sym
            :image
          end
        end
      end
    end
  end
end