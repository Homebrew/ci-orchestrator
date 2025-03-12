# typed: strict

module OrkaKube
  module Entrypoint
    def image_spec(&block)
      ::OrkaKube::DSL::Orka::V1::ImageSpec.new(&block)
    end

    def image_status(&block)
      ::OrkaKube::DSL::Orka::V1::ImageStatus.new(&block)
    end

    def image(&block)
      ::OrkaKube::DSL::Orka::V1::Image.new(&block)
    end

    def image_list(&block)
      ::OrkaKube::DSL::Orka::V1::ImageList.new(&block)
    end

    def iso_spec(&block)
      ::OrkaKube::DSL::Orka::V1::IsoSpec.new(&block)
    end

    def iso_status(&block)
      ::OrkaKube::DSL::Orka::V1::IsoStatus.new(&block)
    end

    def iso(&block)
      ::OrkaKube::DSL::Orka::V1::Iso.new(&block)
    end

    def iso_list(&block)
      ::OrkaKube::DSL::Orka::V1::IsoList.new(&block)
    end

    def orka_node_spec(&block)
      ::OrkaKube::DSL::Orka::V1::OrkaNodeSpec.new(&block)
    end

    def orka_node_status(&block)
      ::OrkaKube::DSL::Orka::V1::OrkaNodeStatus.new(&block)
    end

    def orka_node(&block)
      ::OrkaKube::DSL::Orka::V1::OrkaNode.new(&block)
    end

    def orka_node_list(&block)
      ::OrkaKube::DSL::Orka::V1::OrkaNodeList.new(&block)
    end

    def remote_image_spec(&block)
      ::OrkaKube::DSL::Orka::V1::RemoteImageSpec.new(&block)
    end

    def remote_image(&block)
      ::OrkaKube::DSL::Orka::V1::RemoteImage.new(&block)
    end

    def remote_image_list(&block)
      ::OrkaKube::DSL::Orka::V1::RemoteImageList.new(&block)
    end

    def remote_iso_spec(&block)
      ::OrkaKube::DSL::Orka::V1::RemoteIsoSpec.new(&block)
    end

    def remote_iso(&block)
      ::OrkaKube::DSL::Orka::V1::RemoteIso.new(&block)
    end

    def remote_iso_list(&block)
      ::OrkaKube::DSL::Orka::V1::RemoteIsoList.new(&block)
    end

    def virtual_machine_config_spec(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineConfigSpec.new(&block)
    end

    def virtual_machine_config(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineConfig.new(&block)
    end

    def virtual_machine_config_list(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineConfigList.new(&block)
    end

    def virtual_machine_instance_spec(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineInstanceSpec.new(&block)
    end

    def virtual_machine_instance_status(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineInstanceStatus.new(&block)
    end

    def virtual_machine_instance(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineInstance.new(&block)
    end

    def virtual_machine_instance_list(&block)
      ::OrkaKube::DSL::Orka::V1::VirtualMachineInstanceList.new(&block)
    end
  end
end
