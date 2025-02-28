# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class OrkaNodeStatus < ::KubeDSL::DSLObject
          value_field :allocatable_cpu
          value_field :allocatable_gpu
          value_field :allocatable_memory
          value_field :available_cpu
          value_field :available_gpu
          value_field :available_memory
          value_field :node_ip
          value_field :node_type
          value_field :phase

          validates :allocatable_cpu, field: { format: :integer }, presence: true
          validates :allocatable_gpu, field: { format: :integer }, presence: true
          validates :allocatable_memory, field: { format: :string }, presence: true
          validates :available_cpu, field: { format: :integer }, presence: true
          validates :available_gpu, field: { format: :integer }, presence: true
          validates :available_memory, field: { format: :string }, presence: true
          validates :node_ip, field: { format: :string }, presence: true
          validates :node_type, field: { format: :string }, presence: true
          validates :phase, field: { format: :string }, presence: true

          def serialize
            {}.tap do |result|
              result[:allocatableCpu] = allocatable_cpu
              result[:allocatableGpu] = allocatable_gpu
              result[:allocatableMemory] = allocatable_memory
              result[:availableCpu] = available_cpu
              result[:availableGpu] = available_gpu
              result[:availableMemory] = available_memory
              result[:nodeIP] = node_ip
              result[:nodeType] = node_type
              result[:phase] = phase
            end
          end

          def kind_sym
            :orka_node_status
          end
        end
      end
    end
  end
end