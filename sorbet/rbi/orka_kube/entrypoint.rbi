# typed: strict

module OrkaKube
  module Entrypoint
    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::ImageSpec) }
    def image_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::ImageStatus) }
    def image_status(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::Image) }
    def image(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::ImageList) }
    def image_list(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::IsoSpec) }
    def iso_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::IsoStatus) }
    def iso_status(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::Iso) }
    def iso(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::IsoList) }
    def iso_list(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::OrkaNodeSpec) }
    def orka_node_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::OrkaNodeStatus) }
    def orka_node_status(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::OrkaNode) }
    def orka_node(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::OrkaNodeList) }
    def orka_node_list(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::RemoteImageSpec) }
    def remote_image_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::RemoteImage) }
    def remote_image(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::RemoteImageList) }
    def remote_image_list(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::RemoteIsoSpec) }
    def remote_iso_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::RemoteIso) }
    def remote_iso(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::RemoteIsoList) }
    def remote_iso_list(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineConfigSpec) }
    def virtual_machine_config_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineConfig) }
    def virtual_machine_config(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineConfigList) }
    def virtual_machine_config_list(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineInstanceSpec) }
    def virtual_machine_instance_spec(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineInstanceStatus) }
    def virtual_machine_instance_status(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineInstance) }
    def virtual_machine_instance(&block); end

    T::Sig::WithoutRuntime.sig { params(block: T.proc.void).returns(::OrkaKube::DSL::Orka::V1::VirtualMachineInstanceList) }
    def virtual_machine_instance_list(&block); end
  end
end
