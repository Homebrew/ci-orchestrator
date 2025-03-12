# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class VirtualMachineConfigSpec < ::KubeDSL::DSLObject
          value_field :cpu
          value_field :gpu_passthrough
          value_field :image
          value_field :iso
          value_field :memory
          value_field :net_boost
          value_field :node_name
          value_field :scheduler
          value_field :system_serial
          value_field :tag
          value_field :tag_required
          value_field :vnc_console

          validates :cpu, field: { format: :integer }, presence: true
          validates :gpu_passthrough, field: { format: :boolean }, presence: false
          validates :image, field: { format: :string }, presence: true
          validates :iso, field: { format: :string }, presence: false
          validates :memory, field: { format: :number }, presence: false
          validates :net_boost, field: { format: :boolean }, presence: false
          validates :node_name, field: { format: :string }, presence: false
          validates :scheduler, field: { format: :string }, presence: false
          validates :system_serial, field: { format: :string }, presence: false
          validates :tag, field: { format: :string }, presence: false
          validates :tag_required, field: { format: :boolean }, presence: false
          validates :vnc_console, field: { format: :boolean }, presence: false

          def serialize
            {}.tap do |result|
              result[:cpu] = cpu
              result[:gpuPassthrough] = gpu_passthrough
              result[:image] = image
              result[:iso] = iso
              result[:memory] = memory
              result[:netBoost] = net_boost
              result[:nodeName] = node_name
              result[:scheduler] = scheduler
              result[:systemSerial] = system_serial
              result[:tag] = tag
              result[:tagRequired] = tag_required
              result[:vncConsole] = vnc_console
            end
          end

          def kind_sym
            :virtual_machine_config_spec
          end
        end
      end
    end
  end
end