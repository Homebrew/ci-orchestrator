# typed: strict

module OrkaKube
  module DSL
    module Orka
      module V1
        class OrkaNodeList < ::KubeDSL::DSLObject
          extend KubeDSL::ValueFields::ClassMethods
          extend KubeDSL::Validations::ClassMethods
          include KubeDSL::ValueFields::InstanceMethods

          T::Sig::WithoutRuntime.sig {
            returns(
              T::Hash[Symbol, T.any(String, Integer, Float, T::Boolean, T::Array[T.untyped], T::Hash[Symbol, T.untyped])]
            )
          }
          def serialize; end

          T::Sig::WithoutRuntime.sig { returns(Symbol) }
          def kind_sym; end


          T::Sig::WithoutRuntime.sig {
            params(
              elem_name: T.nilable(Symbol),
              block: T.nilable(T.proc.returns(OrkaKube::DSL::Orka::V1::OrkaNode))
            ).returns(T::Array[OrkaKube::DSL::Orka::V1::OrkaNode])
          }
          def items(elem_name = nil, &block); end


          T::Sig::WithoutRuntime.sig { params(block: T.nilable(T.proc.bind(KubeDSL::DSL::Meta::V1::ListMeta).void)).returns(KubeDSL::DSL::Meta::V1::ListMeta) }
          def metadata(&block); end
          
          T::Sig::WithoutRuntime.sig { returns(T::Boolean) }
          def metadata_present?; end
        end
      end
    end
  end
end