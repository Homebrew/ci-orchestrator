# typed: strict

module OrkaKube
  module DSL
    module Orka
      module V1
        class VirtualMachineInstance < ::KubeDSL::DSLObject
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



          T::Sig::WithoutRuntime.sig { params(block: T.nilable(T.proc.bind(KubeDSL::DSL::Meta::V1::ObjectMeta).void)).returns(KubeDSL::DSL::Meta::V1::ObjectMeta) }
          def metadata(&block); end
          
          T::Sig::WithoutRuntime.sig { returns(T::Boolean) }
          def metadata_present?; end

          T::Sig::WithoutRuntime.sig { params(block: T.nilable(T.proc.bind(OrkaKube::DSL::Orka::V1::VirtualMachineInstanceSpec).void)).returns(OrkaKube::DSL::Orka::V1::VirtualMachineInstanceSpec) }
          def spec(&block); end
          
          T::Sig::WithoutRuntime.sig { returns(T::Boolean) }
          def spec_present?; end

          T::Sig::WithoutRuntime.sig { params(block: T.nilable(T.proc.bind(OrkaKube::DSL::Orka::V1::VirtualMachineInstanceStatus).void)).returns(OrkaKube::DSL::Orka::V1::VirtualMachineInstanceStatus) }
          def status(&block); end
          
          T::Sig::WithoutRuntime.sig { returns(T::Boolean) }
          def status_present?; end
        end
      end
    end
  end
end