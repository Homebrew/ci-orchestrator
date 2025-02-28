# typed: true

module OrkaKube
  module DSL
    module Orka
      module V1
        class VirtualMachineInstanceStatus < ::KubeDSL::DSLObject
          value_field :error_message
          value_field :host_ip
          value_field :memory
          value_field :node_name
          value_field :phase
          value_field :port_warnings
          value_field :screen_share_port
          value_field :ssh_port
          value_field :start_time
          value_field :vnc_port

          validates :error_message, field: { format: :string }, presence: true
          validates :host_ip, field: { format: :string }, presence: true
          validates :memory, field: { format: :string }, presence: true
          validates :node_name, field: { format: :string }, presence: true
          validates :phase, field: { format: :string }, presence: false
          validates :port_warnings, field: { format: :string }, presence: true
          validates :screen_share_port, field: { format: :integer }, presence: false
          validates :ssh_port, field: { format: :integer }, presence: false
          validates :start_time, field: { format: :integer }, presence: true
          validates :vnc_port, field: { format: :integer }, presence: false

          def serialize
            {}.tap do |result|
              result[:errorMessage] = error_message
              result[:hostIP] = host_ip
              result[:memory] = memory
              result[:nodeName] = node_name
              result[:phase] = phase
              result[:portWarnings] = port_warnings
              result[:screenSharePort] = screen_share_port
              result[:sshPort] = ssh_port
              result[:startTime] = start_time
              result[:vncPort] = vnc_port
            end
          end

          def kind_sym
            :virtual_machine_instance_status
          end
        end
      end
    end
  end
end