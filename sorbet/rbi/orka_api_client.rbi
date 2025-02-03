# typed: strong
module OrkaAPI
  module Models
    # @private
    module AttrPredicate
    end

    # The base class for lazily-loaded objects.
    class LazyModel
      # _@param_ `lazy_initialized`
      sig { params(lazy_initialized: T::Boolean).void }
      def initialize(lazy_initialized); end

      # Forces this lazily-loaded object to be fully loaded, performing any necessary network operations.
      sig { returns(T.self_type) }
      def eager; end

      # Re-fetches this object's data from the Orka API. This will raise an error if the object no longer exists.
      sig { void }
      def refresh; end
    end

    # An +.iso+ disk image used exclusively for the installation of macOS on a virtual machine. You must attach the
    # ISO to the VM during deployment. After the installation is complete and the VM has booted successfully, you
    # need to restart the VM to detach the ISO.
    #
    # @note All ISO requests are supported for Intel nodes only.
    class ISO < OrkaAPI::Models::LazyModel
      # _@param_ `name`
      #
      # _@param_ `conn`
      sig { params(name: String, conn: Connection).returns(ISO) }
      def self.lazy_prepare(name:, conn:); end

      # _@param_ `hash`
      #
      # _@param_ `conn`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection).returns(ISO) }
      def self.from_hash(hash, conn:); end

      # _@param_ `conn`
      #
      # _@param_ `name`
      #
      # _@param_ `hash`
      sig { params(conn: Connection, name: T.nilable(String), hash: T.nilable(T::Hash[T.untyped, T.untyped])).void }
      def initialize(conn:, name: nil, hash: nil); end

      # Rename this ISO.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `new_name` — The new name for this ISO.
      #
      # _@note_ — Make sure that the ISO is not in use. Any VMs that have the ISO of the old name attached will no longer
      # be able to boot from it.
      sig { params(new_name: String).void }
      def rename(new_name); end

      # Copy this ISO to a new one.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `new_name` — The name for the copy of this ISO.
      #
      # _@return_ — The lazily-loaded ISO copy.
      sig { params(new_name: String).returns(Image) }
      def copy(new_name); end

      # Delete this ISO from the local Orka storage.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Make sure that the ISO is not in use. Any VMs that have the ISO attached will no longer be able to boot
      # from it.
      sig { void }
      def delete; end

      # _@return_ — The name of this ISO.
      sig { returns(String) }
      attr_reader :name

      # _@return_ — The size of this ISO.
      sig { returns(String) }
      attr_reader :size

      # _@return_ — The time this image was last modified.
      sig { returns(DateTime) }
      attr_reader :modification_time
    end

    # Information on a disk attached to a VM.
    class Disk
      # _@param_ `type`
      #
      # _@param_ `device`
      #
      # _@param_ `target`
      #
      # _@param_ `source`
      sig do
        params(
          type: String,
          device: String,
          target: String,
          source: String
        ).void
      end
      def initialize(type:, device:, target:, source:); end

      sig { returns(String) }
      attr_reader :type

      sig { returns(String) }
      attr_reader :device

      sig { returns(String) }
      attr_reader :target

      sig { returns(String) }
      attr_reader :source
    end

    # A physical or logical host that provides computational resources for your VMs. Usually, an Orka node is a
    # genuine Apple physical host with a host OS on top. You have no direct access (via VNC, SSH, or Screen Sharing)
    # to your nodes.
    class Node < OrkaAPI::Models::LazyModel
      # _@param_ `name`
      #
      # _@param_ `conn`
      #
      # _@param_ `admin`
      sig { params(name: String, conn: Connection, admin: T::Boolean).returns(Node) }
      def self.lazy_prepare(name:, conn:, admin: false); end

      # _@param_ `hash`
      #
      # _@param_ `conn`
      #
      # _@param_ `admin`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection, admin: T::Boolean).returns(Node) }
      def self.from_hash(hash, conn:, admin: false); end

      # _@param_ `conn`
      #
      # _@param_ `name`
      #
      # _@param_ `hash`
      #
      # _@param_ `admin`
      sig do
        params(
          conn: Connection,
          name: T.nilable(String),
          hash: T.nilable(T::Hash[T.untyped, T.untyped]),
          admin: T::Boolean
        ).void
      end
      def initialize(conn:, name: nil, hash: nil, admin: false); end

      # Get a detailed list of all reserved ports on this node. Orka lists them as port mappings between
      # {ProtocolPortMapping#host_port host_port} and {ProtocolPortMapping#guest_port guest_port}.
      # {ProtocolPortMapping#host_port host_port} indicates a port on the node, {ProtocolPortMapping#guest_port
      # guest_port} indicates a port on a VM on this node.
      #
      # This method requires the client to be configured with a token.
      # The network operation is not performed immediately upon return of this method. The request is performed when
      # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
      #
      # _@return_ — The enumerator of the reserved ports list.
      sig { returns(T::Enumerator[ProtocolPortMapping]) }
      def reserved_ports; end

      # Tag this node as sandbox. This limits deployment management from the Orka CLI. You can perform only
      # Kubernetes deployment management with +kubectl+, {https://helm.sh/docs/helm/#helm Helm}, and Tiller.
      #
      # This method requires the client to be configured with both a token and a license key.
      #
      # _@note_ — This request is supported for Intel nodes only.
      sig { void }
      def enable_sandbox; end

      # Remove the sandbox tag from this node. This re-enables deployment management with the Orka CLI.
      #
      # This method requires the client to be configured with both a token and a license key.
      #
      # _@note_ — This request is supported for Intel nodes only.
      sig { void }
      def disable_sandbox; end

      # Dedicate this node to a specified user group. Only users from this user group will be able to deploy to the
      # node.
      #
      # This method requires the client to be configured with both a token and a license key.
      #
      # _@param_ `group` — The user group to dedicate the node to.
      sig { params(group: T.nilable(String)).void }
      def dedicate_to_group(group); end

      # Make this node available to all users.
      #
      # This method requires the client to be configured with both a token and a license key.
      sig { void }
      def remove_group_dedication; end

      # Assign the specified tag to the specified node (enable node affinity). When node affinity is configured,
      # Orka first attempts to deploy to the specified node or group of nodes, before moving to any other nodes.
      #
      # This method requires the client to be configured with both a token and a license key.
      #
      # _@param_ `tag_name` — The name of the tag.
      sig { params(tag_name: String).void }
      def tag(tag_name); end

      # Remove the specified tag from the specified node.
      #
      # This method requires the client to be configured with both a token and a license key.
      #
      # _@param_ `tag_name` — The name of the tag.
      sig { params(tag_name: String).void }
      def untag(tag_name); end

      # _@return_ — The name of this node.
      sig { returns(String) }
      attr_reader :name

      # _@return_ — The host name of this node.
      sig { returns(String) }
      attr_reader :host_name

      # _@return_ — The IP address of this node.
      sig { returns(String) }
      attr_reader :address

      # _@return_ — The host IP address of this node.
      sig { returns(String) }
      attr_reader :host_ip

      # _@return_ — The number of free CPU cores on this node.
      sig { returns(Integer) }
      attr_reader :available_cpu_cores

      # _@return_ — The total number of CPU cores on this node that are allocatable to VMs.
      sig { returns(Integer) }
      attr_reader :allocatable_cpu_cores

      # _@return_ — The number of free GPUs on this node.
      sig { returns(Integer) }
      attr_reader :available_gpu_count

      # _@return_ — The total number of GPUs on this node that are allocatable to VMs.
      sig { returns(Integer) }
      attr_reader :allocatable_gpu_count

      # _@return_ — The amount of free RAM on this node.
      sig { returns(String) }
      attr_reader :available_memory

      # _@return_ — The total number of CPU cores on this node.
      sig { returns(Integer) }
      attr_reader :total_cpu_cores

      # _@return_ — The total amount of RAM on this node.
      sig { returns(String) }
      attr_reader :total_memory

      # _@return_ — The type of this node (WORKER, FOUNDATION, SANDBOX).
      sig { returns(String) }
      attr_reader :type

      # _@return_ — The state of this node.
      sig { returns(String) }
      attr_reader :state

      # _@return_ — The user group this node is dedicated to, if any.
      sig { returns(T.nilable(String)) }
      attr_reader :orka_group

      # _@return_ — The list of tags this node has been assigned.
      sig { returns(T::Array[String]) }
      attr_reader :tags
    end

    # To work with Orka, you need to have a user with an assigned license. You will use this user and the respective
    # credentials to authenticate against the Orka service. After being authenticated against the service, you can
    # run Orka API calls.
    class User < OrkaAPI::Models::LazyModel
      # _@param_ `email`
      #
      # _@param_ `conn`
      sig { params(email: String, conn: Connection).returns(User) }
      def self.lazy_prepare(email:, conn:); end

      # _@param_ `conn`
      #
      # _@param_ `email`
      #
      # _@param_ `group`
      sig { params(conn: Connection, email: String, group: T.nilable(String)).void }
      def initialize(conn:, email:, group: nil); end

      # Delete the user in the endpoint. The user must have no Orka resources associated with them (other than their
      # authentication tokens). This operation invalidates all tokens associated with the user.
      #
      # This method requires the client to be configured with both a token and a license key.
      sig { void }
      def delete; end

      # Reset the password for the user. This operation is intended for administrators.
      #
      # This method requires the client to be configured with both a token and a license key.
      #
      # _@param_ `password` — The new password for the user.
      sig { params(password: String).void }
      def reset_password(password); end

      # Apply a group label to the user.
      #
      # This method requires the client to be configured with a license key.
      #
      # _@param_ `group` — The new group for the user.
      #
      # _@note_ — This is a BETA feature.
      sig { params(group: String).void }
      def change_group(group); end

      # Remove a group label from the user.
      #
      # This method requires the client to be configured with a license key.
      #
      # _@note_ — This is a BETA feature.
      sig { void }
      def remove_group; end

      # _@return_ — The email address for the user.
      sig { returns(String) }
      attr_reader :email

      # _@return_ — The group the user is in, if any.
      sig { returns(T.nilable(String)) }
      attr_reader :group
    end

    # A disk image that represents a VM's storage and its contents, including the OS and any installed software.
    class Image < OrkaAPI::Models::LazyModel
      # _@param_ `name`
      #
      # _@param_ `conn`
      sig { params(name: String, conn: Connection).returns(Image) }
      def self.lazy_prepare(name:, conn:); end

      # _@param_ `hash`
      #
      # _@param_ `conn`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection).returns(Image) }
      def self.from_hash(hash, conn:); end

      # _@param_ `conn`
      #
      # _@param_ `name`
      #
      # _@param_ `hash`
      sig { params(conn: Connection, name: T.nilable(String), hash: T.nilable(T::Hash[T.untyped, T.untyped])).void }
      def initialize(conn:, name: nil, hash: nil); end

      # Rename this image.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `new_name` — The new name for this image.
      #
      # _@note_ — After you rename a base image, you can no longer deploy any VM configurations that are based on the
      # image of the old name.
      sig { params(new_name: String).void }
      def rename(new_name); end

      # Copy this image to a new one.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `new_name` — The name for the copy of this image.
      #
      # _@return_ — The lazily-loaded image copy.
      sig { params(new_name: String).returns(Image) }
      def copy(new_name); end

      # Delete this image from the local Orka storage.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Make sure that the image is not in use.
      sig { void }
      def delete; end

      # Download this image from Orka cluster storage to your local filesystem.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `to` — An open IO, or a String/Pathname file path to the file or directory where you want the image to be written.
      #
      # _@note_ — This request is supported for Intel images only. Intel images have +.img+ extension.
      sig { params(to: T.any(String, Pathname, IO)).void }
      def download(to:); end

      # Request the MD5 file checksum for this image in Orka cluster storage. The checksum can be used to verify file
      # integrity for a downloaded or uploaded image.
      #
      # This method requires the client to be configured with a token.
      #
      # _@return_ — The MD5 checksum of the image, or nil if the calculation is in progress and has not
      # completed.
      #
      # _@note_ — This request is supported for Intel images only. Intel images have +.img+ extension.
      sig { returns(T.nilable(String)) }
      def checksum; end

      # _@return_ — The name of this image.
      sig { returns(String) }
      attr_reader :name

      # _@return_ — The size of this image. Orka lists generated empty storage disks with a fixed size of ~192k.
      # When attached to a VM and formatted, the disk will appear with its correct size in the OS.
      sig { returns(String) }
      attr_reader :size

      # _@return_ — The time this image was last modified.
      sig { returns(DateTime) }
      attr_reader :modification_time

      # _@return_ — The time this image was first created, if available.
      sig { returns(T.nilable(DateTime)) }
      attr_reader :creation_time

      sig { returns(String) }
      attr_reader :owner
    end

    # Enumerator subclass for networked operations.
    class Enumerator < ::Enumerator
      Elem = type_member

      sig { void }
      def initialize; end

      # Forces this lazily-loaded enumerator to be fully loaded, performing any necessary network operations.
      sig { returns(T.self_type) }
      def eager; end
    end

    # Represents an ISO which exists in the Orka remote repo rather than local storage.
    class RemoteISO
      # _@param_ `name`
      #
      # _@param_ `conn`
      sig { params(name: String, conn: Connection).void }
      def initialize(name, conn:); end

      # Pull an ISO from the remote repo. You can retain the ISO name or change it during the operation. This is a
      # long-running operation and might take a while.
      #
      # The operation copies the ISO to the local storage of your Orka environment. The ISO will be available for use
      # by all users of the environment.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `new_name` — The name for the local copy of this ISO.
      #
      # _@return_ — The lazily-loaded local ISO.
      sig { params(new_name: String).returns(ISO) }
      def pull(new_name); end

      # _@return_ — The name of this remote ISO.
      sig { returns(String) }
      attr_reader :name
    end

    # Provides information on the client's token.
    class TokenInfo
      extend OrkaAPI::Models::AttrPredicate

      # _@param_ `hash`
      #
      # _@param_ `conn`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection).void }
      def initialize(hash, conn:); end

      # _@return_ — True if the tokeb is valid for authentication.
      sig { returns(T::Boolean) }
      def authenticated?; end

      # _@return_ — True if the token has been revoked.
      sig { returns(T::Boolean) }
      def token_revoked?; end

      # _@return_ — The user associated with the token.
      sig { returns(User) }
      attr_reader :user
    end

    # A virtual machine deployed on a {Node node} from an existing {VMConfiguration VM configuration} or cloned from
    # an existing virtual machine. In the case of macOS VMs, this is a full macOS VM inside of a
    # {https://www.docker.com/resources/what-container Docker container}.
    class VMInstance
      extend OrkaAPI::Models::AttrPredicate

      # _@param_ `hash`
      #
      # _@param_ `conn`
      #
      # _@param_ `admin`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection, admin: T::Boolean).void }
      def initialize(hash, conn:, admin: false); end

      # Remove the VM instance.
      #
      # If the VM instance belongs to the user associated with the client's token then the client only needs to be
      # configured with a token. Otherwise, if you are removing a VM instance associated with another user, you need
      # to configure the client with both a token and a license key.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # attributes like {#status}. You must fetch a new object instance from the client to refresh this data.
      sig { void }
      def delete; end

      # Power ON the VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # attributes like {#status}. You must fetch a new object instance from the client to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def start; end

      # Power OFF the VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # attributes like {#status}. You must fetch a new object instance from the client to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def stop; end

      # Suspend the VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # attributes like {#status}. You must fetch a new object instance from the client to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def suspend; end

      # Resume the VM. The VM must already be suspended.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # attributes like {#status}. You must fetch a new object instance from the client to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def resume; end

      # Revert the VM to the latest state of its base image. This operation restarts the VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # attributes like {#status}. You must fetch a new object instance from the client to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def revert; end

      # List the disks attached to the VM. The VM must be non-scaled.
      #
      # This method requires the client to be configured with a token.
      # The network operation is not performed immediately upon return of this method. The request is performed when
      # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
      #
      # _@return_ — The enumerator of the disk list.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { returns(T::Enumerator[Disk]) }
      def disks; end

      # Attach a disk to the VM. The VM must be non-scaled.
      #
      # You can attach any of the following disks:
      #
      # * Any disks created with {Client#generate_empty_image}
      # * Any non-bootable images available in your Orka storage and listed by {Client#images}
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `image` — The disk to attach to the VM.
      #
      # _@param_ `mount_point` — The mount point to attach the VM to.
      #
      # _@note_ — Before you can use the attached disk, you need to restart the VM with a {#stop manual stop} of the VM,
      # followed by a {#start manual start} VM. A software reboot from the OS will not trigger macOS to recognize
      # the disk.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { params(image: T.any(Image, String), mount_point: String).void }
      def attach_disk(image:, mount_point:); end

      # Save the VM configuration state (disk and memory).
      #
      # If VM state is previously saved, it is overwritten. To overwrite the VM state, it must not be used by any
      # deployed VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — Saving VM state is restricted only to VMs that have GPU passthrough disabled.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def save_state; end

      # Apply the current state of the VM's image to the original base image in the Orka storage. Use this operation
      # to modify an existing base image. All VM configs that reference this base image will be affected.
      #
      # The VM must be non-scaled. The base image to which you want to commit changes must be in use by only one VM.
      # The base image to which you want to commit changes must not be in use by a VM configuration with saved VM
      # state.
      #
      # This method requires the client to be configured with a token.
      sig { void }
      def commit_to_base_image; end

      # Save the current state of the VM's image to a new base image in the Orka storage. Use this operation to
      # create a new base image.
      #
      # The VM must be non-scaled. The base image name that you specify must not be in use.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `image_name` — The name to give to the new base image.
      #
      # _@return_ — The lazily-loaded new base image.
      sig { params(image_name: String).returns(Image) }
      def save_new_base_image(image_name); end

      # Resize the current disk of the VM and save it as a new base image. This does not affect the original base
      # image of the VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `username` — The username of the VM user.
      #
      # _@param_ `password` — The password of the VM user.
      #
      # _@param_ `image_name` — The new name for the resized image.
      #
      # _@param_ `image_size` — The size of the new image (in k, M, G, or T), for example +"100G"+.
      #
      # _@return_ — The lazily-loaded new base image.
      sig do
        params(
          username: String,
          password: String,
          image_name: String,
          image_size: String
        ).returns(Image)
      end
      def resize_image(username:, password:, image_name:, image_size:); end

      # _@return_ — The ID of the VM.
      sig { returns(String) }
      attr_reader :id

      # _@return_ — The name of the VM.
      sig { returns(String) }
      attr_reader :name

      # _@return_ — The node the VM is deployed on.
      sig { returns(Node) }
      attr_reader :node

      # _@return_ — The owner of the VM, i.e. the user which deployed it.
      sig { returns(User) }
      attr_reader :owner

      # _@return_ — The state of the node the VM is deployed on.
      sig { returns(String) }
      attr_reader :node_status

      # _@return_ — The IP of the VM.
      sig { returns(String) }
      attr_reader :ip

      # _@return_ — The port used to connect to the VM via VNC.
      sig { returns(Integer) }
      attr_reader :vnc_port

      # _@return_ — The port used to connect to the VM via macOS Screen Sharing.
      sig { returns(Integer) }
      attr_reader :screen_sharing_port

      # _@return_ — The port used to connect to the VM via SSH.
      sig { returns(Integer) }
      attr_reader :ssh_port

      # _@return_ — The number of CPU cores allocated to the VM.
      sig { returns(Integer) }
      attr_reader :cpu_cores

      # _@return_ — The number of vCPUs allocated to the VM.
      sig { returns(Integer) }
      attr_reader :vcpu_count

      # _@return_ — The number of GPUs allocated to the VM.
      sig { returns(Integer) }
      attr_reader :gpu_count

      # _@return_ — The amount of RAM allocated to the VM.
      sig { returns(String) }
      attr_reader :ram

      # _@return_ — The base image the VM was deployed from.
      sig { returns(Image) }
      attr_reader :base_image

      # _@return_ — The VM configuration object this instance is based on.
      sig { returns(VMConfiguration) }
      attr_reader :config

      sig { returns(String) }
      attr_reader :configuration_template

      # _@return_ — The status of the VM, at the time this class was initialized.
      sig { returns(String) }
      attr_reader :status

      # _@return_ — True if IO boost is enabled for this VM.
      sig { returns(T::Boolean) }
      def io_boost?; end

      # _@return_ — True if network boost is enabled for this VM.
      sig { returns(T::Boolean) }
      def net_boost?; end

      # _@return_ — True if this VM is using a prior saved state rather than a clean base image.
      sig { returns(T::Boolean) }
      def use_saved_state?; end

      # _@return_ — The port mappings established for this VM.
      sig { returns(T::Array[ProtocolPortMapping]) }
      attr_reader :reserved_ports

      # _@return_ — The time when this VM was deployed.
      sig { returns(DateTime) }
      attr_reader :creation_time

      # _@return_ — The tag that was requested this VM be deployed to, if any.
      sig { returns(T.nilable(String)) }
      attr_reader :tag

      # _@return_ — Whether it was mandatory that this VM was deployed to the requested tag.
      sig { returns(T::Boolean) }
      def tag_required?; end
    end

    # A general representation of {VMConfiguration VM configurations} and the {VMInstance VMs} deployed from those
    # configurations.
    class VMResource < OrkaAPI::Models::LazyModel
      # _@param_ `name`
      #
      # _@param_ `conn`
      #
      # _@param_ `admin`
      sig { params(name: String, conn: Connection, admin: T::Boolean).returns(VMResource) }
      def self.lazy_prepare(name:, conn:, admin: false); end

      # _@param_ `hash`
      #
      # _@param_ `conn`
      #
      # _@param_ `admin`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection, admin: T::Boolean).returns(VMResource) }
      def self.from_hash(hash, conn:, admin: false); end

      # _@param_ `conn`
      #
      # _@param_ `name`
      #
      # _@param_ `hash`
      #
      # _@param_ `admin`
      sig do
        params(
          conn: Connection,
          name: T.nilable(String),
          hash: T.nilable(T::Hash[T.untyped, T.untyped]),
          admin: T::Boolean
        ).void
      end
      def initialize(conn:, name: nil, hash: nil, admin: false); end

      # Deploy an existing VM configuration to a node. If you don't specify a node, Orka chooses a node based on the
      # available resources.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — The node on which to deploy the VM. The node must have sufficient CPU and memory to accommodate the VM.
      #
      # _@param_ `replicas` — The scale at which to deploy the VM configuration. If not specified, defaults to +1+ (non-scaled). The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `reserved_ports` — One or more port mappings that forward traffic to the specified ports on the VM. The following ports and port ranges are reserved and cannot be used: +22+, +443+, +6443+, +5000-5014+, +5999-6013+, +8822-8836+.
      #
      # _@param_ `iso_install` — Set to +true+ if you want to use an ISO. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `iso_image` — An ISO to attach to the VM during deployment. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override any ISO specified in the VM configuration. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `attach_disk` — Set to +true+ if you want to attach additional storage during deployment. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `attached_disk` — An additional storage disk to attach to the VM during deployment. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override any storage specified in the VM configuration. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `vnc_console` — Enables or disables VNC for the VM. If not set in the VM configuration or here, defaults to +true+. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override the VNC setting specified in the VM configuration.
      #
      # _@param_ `vm_metadata` — Inject custom metadata to the VM. If not set, only the built-in metadata is injected into the VM.
      #
      # _@param_ `system_serial` — Assign an owned macOS system serial number to the VM. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `gpu_passthrough` — Enables or disables GPU passthrough for the VM. If not set in the VM configuration or here, defaults to +false+. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override the GPU passthrough setting specified in the VM configuration. When enabled, +vnc_console+ is automatically disabled. The option is supported for VMs deployed on Intel nodes only. GPU passthrough must first be enabled in your cluster.
      #
      # _@param_ `tag` — When specified, the VM is preferred to be deployed to a node marked with this tag.
      #
      # _@param_ `tag_required` — By default, +false+. When set to +true+, the VM is required to be deployed to a node marked with this tag.
      #
      # _@param_ `scheduler` — Possible values are +:default+ and +:most-allocated+. By default, +:default+. When set to +:most-allocated+ the deployed VM will be scheduled to nodes having most of their resources allocated. +:default+ keeps used vs free resources balanced between the nodes.
      #
      # _@return_ — Details of the just-deployed VM.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      sig do
        params(
          node: T.nilable(T.any(Node, String)),
          replicas: T.nilable(Integer),
          reserved_ports: T.nilable(T::Array[PortMapping]),
          iso_install: T.nilable(T::Boolean),
          iso_image: T.nilable(T.any(Models::ISO, String)),
          attach_disk: T.nilable(T::Boolean),
          attached_disk: T.nilable(T.any(Models::Image, String)),
          vnc_console: T.nilable(T::Boolean),
          vm_metadata: T.nilable(T::Hash[String, String]),
          system_serial: T.nilable(String),
          gpu_passthrough: T.nilable(T::Boolean),
          tag: T.nilable(String),
          tag_required: T.nilable(T::Boolean),
          scheduler: T.nilable(Symbol)
        ).returns(VMDeploymentResult)
      end
      def deploy(node: nil, replicas: nil, reserved_ports: nil, iso_install: nil, iso_image: nil, attach_disk: nil, attached_disk: nil, vnc_console: nil, vm_metadata: nil, system_serial: nil, gpu_passthrough: nil, tag: nil, tag_required: nil, scheduler: nil); end

      # Removes all VM instances.
      #
      # If the VM instances belongs to the user associated with the client's token then the client only needs to be
      # configured with a token. Otherwise, if you are removing VM instances associated with another user, you need
      # to configure the client with both a token and a license key.
      #
      # _@param_ `node` — If specified, only remove VM deployments on that node.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      sig { params(node: T.nilable(T.any(Node, String))).void }
      def delete_all_instances(node: nil); end

      # Remove all VM instances and the VM configuration.
      #
      # If the VM resource belongs to the user associated with the client's token then the client only needs to be
      # configured with a token. Otherwise, if you are removing a VM resource associated with another user, you need
      # to configure the client with both a token and a license key.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      sig { void }
      def purge; end

      # Power ON all VM instances on a particular node that are associated with this VM resource.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — All deployments of this VM located on this node will be started.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { params(node: T.any(Node, String)).void }
      def start_all_on_node(node); end

      # Power OFF all VM instances on a particular node that are associated with this VM resource.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — All deployments of this VM located on this node will be stopped.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { params(node: T.any(Node, String)).void }
      def stop_all_on_node(node); end

      # Suspend all VM instances on a particular node that are associated with this VM resource.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — All deployments of this VM located on this node will be suspended.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { params(node: T.any(Node, String)).void }
      def suspend_all_on_node(node); end

      # Resume all VM instances on a particular node that are associated with this VM resource.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — All deployments of this VM located on this node will be resumed.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { params(node: T.any(Node, String)).void }
      def resume_all_on_node(node); end

      # Revert all VM instances on a particular node that are associated with this VM resource to the latest state of
      # its base image. This operation restarts the VMs.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — All deployments of this VM located on this node will be reverted.
      #
      # _@note_ — Calling this will not change the state of this object, and thus not change the return values of
      # {#deployed?} and {#instances}, if the object already been loaded. You must fetch a new object instance or
      # call {#refresh} to refresh this data.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { params(node: T.any(Node, String)).void }
      def revert_all_on_node(node); end

      # _@return_ — The name of this VM resource.
      sig { returns(String) }
      attr_reader :name

      # _@return_ — True if there are associated deployed VM instances.
      sig { returns(T::Boolean) }
      def deployed?; end

      # _@return_ — The list of deployed VM instances.
      sig { returns(T::Array[VMInstance]) }
      attr_reader :instances

      # _@return_ — The owner of the associated VM configuration. This is +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(User)) }
      attr_reader :owner

      # _@return_ — The number of CPU cores to use, specified by the associated VM configuration. This is
      # +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(Integer)) }
      attr_reader :cpu_cores

      # _@return_ — The number of vCPUs to use, specified by the associated VM configuration. This is
      # +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(Integer)) }
      attr_reader :vcpu_count

      # _@return_ — The base image to use, specified by the associated VM configuration. This is +nil+ if
      # {#deployed?} is +true+.
      sig { returns(T.nilable(Image)) }
      attr_reader :base_image

      # _@return_ — The matching VM configuration object. This is +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(VMConfiguration)) }
      attr_reader :config

      # _@return_ — True if IO boost is enabled, specified by the associated VM configuration. This is
      # +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(T::Boolean)) }
      def io_boost?; end

      # _@return_ — True if network boost is enabled, specified by the associated VM configuration. This is
      # +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(T::Boolean)) }
      def net_boost?; end

      # _@return_ — True if the saved state should be used rather than cleanly from the base image,
      # specified by the associated VM configuration. This is +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(T::Boolean)) }
      def use_saved_state?; end

      # _@return_ — True if GPU passthrough is enabled, specified by the associated VM configuration. This
      # is +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(T::Boolean)) }
      def gpu_passthrough?; end

      sig { returns(T.nilable(String)) }
      attr_reader :configuration_template

      # _@return_ — The amount of RAM assigned for this VM, if it has been manually configured in advance of
      # deployment. This is always +nil+ if {#deployed?} is +true+.
      sig { returns(T.nilable(String)) }
      attr_reader :ram
    end

    # An account used for Kubernetes operations.
    class KubeAccount
      # _@param_ `name`
      #
      # _@param_ `email`
      #
      # _@param_ `kubeconfig`
      #
      # _@param_ `conn`
      sig do
        params(
          name: String,
          conn: Connection,
          email: T.nilable(String),
          kubeconfig: T.nilable(String)
        ).void
      end
      def initialize(name, conn:, email: nil, kubeconfig: nil); end

      # Regenerate this kube-account.
      #
      # This method requires the client to be configured with both a token and a license key.
      sig { void }
      def regenerate; end

      # Retrieve the +kubeconfig+ for this kube-account.
      #
      # This method is cached. Subsequent calls to this method will not invoke additional network requests. The
      # methods {#regenerate} and {Client#create_kube_account} also fill this cache.
      #
      # This method requires the client to be configured with both a token and a license key.
      sig { void }
      def kubeconfig; end

      # _@return_ — The name of this kube-account.
      sig { returns(String) }
      attr_reader :name
    end

    # Represents an image which exists in the Orka remote repo rather than local storage.
    class RemoteImage
      # _@param_ `name`
      #
      # _@param_ `conn`
      sig { params(name: String, conn: Connection).void }
      def initialize(name, conn:); end

      # Pull this image from the remote repo. This is a long-running operation and might take a while.
      #
      # The operation copies the image to the local storage of your Orka environment. The base image will be
      # available for use by all users of the environment.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `new_name` — The name for the local copy of this image.
      #
      # _@return_ — The lazily-loaded local image.
      sig { params(new_name: String).returns(Image) }
      def pull(new_name); end

      # _@return_ — The name of this remote image.
      sig { returns(String) }
      attr_reader :name
    end

    # A template configuration (a container template) consisting of a
    # {https://orkadocs.macstadium.com/docs/orka-glossary#base-image base image}, a
    # {https://orkadocs.macstadium.com/docs/orka-glossary#snapshot-image snapshot image}, and the number of CPU cores
    # to be used. To become a VM that you can run in the cloud, a VM configuration needs to be deployed to a {Node
    # node}.
    #
    # You can deploy multiple VMs from a single VM configuration. Once created, you can no longer modify a VM
    # configuration.
    #
    # Deleting a VM does not delete the VM configuration it was deployed from.
    class VMConfiguration < OrkaAPI::Models::LazyModel
      # _@param_ `name`
      #
      # _@param_ `conn`
      sig { params(name: String, conn: Connection).returns(VMConfiguration) }
      def self.lazy_prepare(name:, conn:); end

      # _@param_ `hash`
      #
      # _@param_ `conn`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection).returns(VMConfiguration) }
      def self.from_hash(hash, conn:); end

      # _@param_ `conn`
      #
      # _@param_ `name`
      #
      # _@param_ `hash`
      sig { params(conn: Connection, name: T.nilable(String), hash: T.nilable(T::Hash[T.untyped, T.untyped])).void }
      def initialize(conn:, name: nil, hash: nil); end

      # Deploy the VM configuration to a node. If you don't specify a node, Orka chooses a node based on the
      # available resources.
      #
      # This method requires the client to be configured with a token.
      #
      # _@param_ `node` — The node on which to deploy the VM. The node must have sufficient CPU and memory to accommodate the VM.
      #
      # _@param_ `replicas` — The scale at which to deploy the VM configuration. If not specified, defaults to +1+ (non-scaled). The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `reserved_ports` — One or more port mappings that forward traffic to the specified ports on the VM. The following ports and port ranges are reserved and cannot be used: +22+, +443+, +6443+, +5000-5014+, +5999-6013+, +8822-8836+.
      #
      # _@param_ `iso_install` — Set to +true+ if you want to use an ISO. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `iso_image` — An ISO to attach to the VM during deployment. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override any ISO specified in the VM configuration. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `attach_disk` — Set to +true+ if you want to attach additional storage during deployment. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `attached_disk` — An additional storage disk to attach to the VM during deployment. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override any storage specified in the VM configuration. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `vnc_console` — Enables or disables VNC for the VM. If not set in the VM configuration or here, defaults to +true+. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override the VNC setting specified in the VM configuration.
      #
      # _@param_ `vm_metadata` — Inject custom metadata to the VM. If not set, only the built-in metadata is injected into the VM.
      #
      # _@param_ `system_serial` — Assign an owned macOS system serial number to the VM. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. The option is supported for VMs deployed on Intel nodes only.
      #
      # _@param_ `gpu_passthrough` — Enables or disables GPU passthrough for the VM. If not set in the VM configuration or here, defaults to +false+. If already set in the respective VM configuration and not set here, Orka applies the setting from the VM configuration. You can also use this field to override the GPU passthrough setting specified in the VM configuration. When enabled, +vnc_console+ is automatically disabled. The option is supported for VMs deployed on Intel nodes only. GPU passthrough must first be enabled in your cluster.
      #
      # _@param_ `tag` — When specified, the VM is preferred to be deployed to a node marked with this tag.
      #
      # _@param_ `tag_required` — By default, +false+. When set to +true+, the VM is required to be deployed to a node marked with this tag.
      #
      # _@param_ `scheduler` — Possible values are +:default+ and +:most-allocated+. By default, +:default+. When set to +:most-allocated+ the deployed VM will be scheduled to nodes having most of their resources allocated. +:default+ keeps used vs free resources balanced between the nodes.
      #
      # _@return_ — Details of the just-deployed VM.
      sig do
        params(
          node: T.nilable(T.any(Node, String)),
          replicas: T.nilable(Integer),
          reserved_ports: T.nilable(T::Array[PortMapping]),
          iso_install: T.nilable(T::Boolean),
          iso_image: T.nilable(T.any(Models::ISO, String)),
          attach_disk: T.nilable(T::Boolean),
          attached_disk: T.nilable(T.any(Models::Image, String)),
          vnc_console: T.nilable(T::Boolean),
          vm_metadata: T.nilable(T::Hash[String, String]),
          system_serial: T.nilable(String),
          gpu_passthrough: T.nilable(T::Boolean),
          tag: T.nilable(String),
          tag_required: T.nilable(T::Boolean),
          scheduler: T.nilable(Symbol)
        ).returns(VMDeploymentResult)
      end
      def deploy(node: nil, replicas: nil, reserved_ports: nil, iso_install: nil, iso_image: nil, attach_disk: nil, attached_disk: nil, vnc_console: nil, vm_metadata: nil, system_serial: nil, gpu_passthrough: nil, tag: nil, tag_required: nil, scheduler: nil); end

      # Remove the VM configuration and all VM deployments of it.
      #
      # If the VM configuration and its deployments belong to the user associated with the client's token then the
      # client only needs to be configured with a token. Otherwise, if you are removing a VM resource associated with
      # another user, you need to configure the client with both a token and a license key.
      sig { void }
      def purge; end

      # Delete the VM configuration state. Now when you deploy the VM configuration it will use the base image to
      # boot the VM.
      #
      # To delete a VM state, it must not be used by any deployed VM.
      #
      # This method requires the client to be configured with a token.
      #
      # _@note_ — This request is supported for VMs deployed on Intel nodes only.
      sig { void }
      def delete_saved_state; end

      # _@return_ — The name of this VM configuration.
      sig { returns(String) }
      attr_reader :name

      # _@return_ — The owner of this VM configuration, i.e. the user which deployed it.
      sig { returns(User) }
      attr_reader :owner

      # _@return_ — The base image which newly deployed VMs of this configuration will boot from.
      sig { returns(Image) }
      attr_reader :base_image

      # _@return_ — The number of CPU cores to allocate to deployed VMs of this configuration.
      sig { returns(Integer) }
      attr_reader :cpu_cores

      # _@return_ — The number of VCPUs to allocate to deployed VMs of this configuration.
      sig { returns(Integer) }
      attr_reader :vcpu_count

      # _@return_ — The ISO to attach to deployed VMs of this configuration.
      sig { returns(ISO) }
      attr_reader :iso_image

      # _@return_ — The storage disk image to attach to deployed VMs of this configuration.
      sig { returns(Image) }
      attr_reader :attached_disk

      # _@return_ — True if the VNC console should be enabled for deployed VMs of this configuration.
      sig { returns(T::Boolean) }
      def vnc_console?; end

      # _@return_ — True if IO boost should be enabled for deployed VMs of this configuration.
      sig { returns(T::Boolean) }
      def io_boost?; end

      # _@return_ — True if network boost should be enabled for deployed VMs of this configuration.
      sig { returns(T::Boolean) }
      def net_boost?; end

      # _@return_ — True if deployed VMs of this configuration should use a prior saved state (created via
      # {VMInstance#save_state}) rather than a clean base image.
      sig { returns(T::Boolean) }
      def use_saved_state?; end

      # _@return_ — True if GPU passthrough should be enabled for deployed VMs of this configuration.
      sig { returns(T::Boolean) }
      def gpu_passthrough?; end

      # _@return_ — The custom system serial number, if set.
      sig { returns(T.nilable(String)) }
      attr_reader :system_serial

      # _@return_ — The tag that VMs of this configuration should be deployed to, if any.
      sig { returns(T.nilable(String)) }
      attr_reader :tag

      # _@return_ — Whether it is mandatory that VMs are deployed to the requested tag.
      sig { returns(T::Boolean) }
      def tag_required?; end

      # _@return_ — The scheduler mode chosen for VM deployment. Can be either +:default+ or +:most_allocated+.
      sig { returns(Symbol) }
      attr_reader :scheduler

      # _@return_ — The amount of RAM this VM is assigned to take, in gigabytes. If not set, Orka will
      # automatically select a value when deploying.
      sig { returns(T.nilable(Numeric)) }
      attr_reader :memory
    end

    # Provides information on the just-deployed VM.
    class VMDeploymentResult
      extend OrkaAPI::Models::AttrPredicate

      # _@param_ `hash`
      #
      # _@param_ `conn`
      #
      # _@param_ `admin`
      sig { params(hash: T::Hash[T.untyped, T.untyped], conn: Connection, admin: T::Boolean).void }
      def initialize(hash, conn:, admin: false); end

      # _@return_ — The amount of RAM allocated to the VM.
      sig { returns(String) }
      attr_reader :ram

      # _@return_ — The number of vCPUs allocated to the VM.
      sig { returns(Integer) }
      attr_reader :vcpu_count

      # _@return_ — The number of host CPU cores allocated to the VM.
      sig { returns(Integer) }
      attr_reader :cpu_cores

      # _@return_ — The IP of the VM.
      sig { returns(String) }
      attr_reader :ip

      # _@return_ — The port used to connect to the VM via SSH.
      sig { returns(Integer) }
      attr_reader :ssh_port

      # _@return_ — The port used to connect to the VM via macOS Screen Sharing.
      sig { returns(Integer) }
      attr_reader :screen_sharing_port

      # _@return_ — The VM resource object representing this VM.
      sig { returns(VMResource) }
      attr_reader :resource

      # _@return_ — True if network boost is enabled for this VM.
      sig { returns(T::Boolean) }
      def io_boost?; end

      # _@return_ — True if this VM is using a prior saved state rather than a clean base image.
      sig { returns(T::Boolean) }
      def use_saved_state?; end

      # _@return_ — True if GPU passthrough is enabled for this VM.
      sig { returns(T::Boolean) }
      def gpu_passthrough?; end

      # _@return_ — The port used to connect to the VM via VNC, if enabled.
      sig { returns(T.nilable(Integer)) }
      attr_reader :vnc_port
    end

    # The requirements enforced for passwords when creating a user account.
    class PasswordRequirements
      # _@param_ `hash`
      sig { params(hash: T::Hash[T.untyped, T.untyped]).void }
      def initialize(hash); end

      # _@return_ — The minimum length of a password.
      sig { returns(Integer) }
      attr_reader :length
    end

    # Represents a port forwarding from a host node to a guest VM, with an additional field denoting the transport
    # protocol.
    class ProtocolPortMapping < OrkaAPI::PortMapping
      # _@param_ `host_port`
      #
      # _@param_ `guest_port`
      #
      # _@param_ `protocol`
      sig { params(host_port: Integer, guest_port: Integer, protocol: String).void }
      def initialize(host_port:, guest_port:, protocol:); end

      # _@return_ — The transport protocol, typically TCP.
      sig { returns(String) }
      attr_reader :protocol
    end
  end

  # This is the entrypoint class for all interactions with the Orka API.
  class Client
    VERSION = T.let("0.2.1", T.untyped)
    API_VERSION = T.let("2.4.0", T.untyped)

    # Creates an instance of the client for a given Orka service endpoint and associated credentials.
    #
    # _@param_ `base_url` — The API URL for the Orka service endpoint.
    #
    # _@param_ `token` — The token used for authentication. This can be generated with {#create_token} from an credentialless client.
    #
    # _@param_ `license_key` — The Orka license key used for authentication in administrative operations.
    sig { params(base_url: String, token: T.nilable(String), license_key: T.nilable(String)).void }
    def initialize(base_url, token: nil, license_key: nil); end

    # Retrieve a list of the users in the Orka environment.
    #
    # This method requires the client to be configured with a license key.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@return_ — The enumerator of the user list.
    sig { returns(Models::Enumerator[Models::User]) }
    def users; end

    # Fetches information on a particular user in the Orka environment.
    #
    # This method requires the client to be configured with a license key.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any attribute is accessed or any method is called on the returned object, or otherwise forced via
    # {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    # exists.
    #
    # _@param_ `email` — The email of the user to fetch.
    #
    # _@return_ — The lazily-loaded user object.
    sig { params(email: String).returns(Models::User) }
    def user(email); end

    # Create a new user in the Orka environment. You need to specify email address and password. You cannot pass an
    # email address that's already in use.
    #
    # This method requires the client to be configured with a license key.
    #
    # _@param_ `email` — An email address for the user. This also serves as the username.
    #
    # _@param_ `password` — A password for the user. Must be at least 6 characters long.
    #
    # _@param_ `group` — A user group for the user. Once set, you can no longer change the user group.
    #
    # _@return_ — The user object.
    sig { params(email: String, password: String, group: T.nilable(String)).returns(Models::User) }
    def create_user(email:, password:, group: nil); end

    # Modify the email address or password of the current user. This operation is intended for regular Orka users.
    #
    # This method requires the client to be configured with a token.
    #
    # _@param_ `email` — The new email address for the user.
    #
    # _@param_ `password` — The new password for the user.
    sig { params(email: T.nilable(String), password: T.nilable(String)).void }
    def update_user_credentials(email: nil, password: nil); end

    # Create an authentication token using an existing user's email and password.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@param_ `user` — The user or their associated email address.
    #
    # _@param_ `password` — The user's password.
    #
    # _@return_ — The authentication token.
    sig { params(user: T.any(Models::User, String), password: String).returns(String) }
    def create_token(user:, password:); end

    # Revoke the token associated with this client instance.
    #
    # This method requires the client to be configured with a token.
    sig { void }
    def revoke_token; end

    # Retrieve a list of the VMs and VM configurations. By default this fetches resources associated with the
    # client's token, but you can optionally request a list of resources for another user (or all users).
    #
    # If you filter by a user, or request all users, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@param_ `user` — The user, or their associated email address, to use instead of the one associated with the client's token. Pass "all" if you wish to fetch for all users.
    #
    # _@return_ — The enumerator of the VM resource list.
    sig { params(user: T.nilable(T.any(Models::User, String))).returns(Models::Enumerator[Models::VMResource]) }
    def vm_resources(user: nil); end

    # Fetches information on a particular VM or VM configuration.
    #
    # If you set the admin parameter to true, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any attribute is accessed or any method is called on the returned object, or otherwise forced via
    # {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    # exists.
    #
    # _@param_ `name` — The name of the VM resource to fetch.
    #
    # _@param_ `admin` — Set to true to allow VM resources associated with other users to be queried.
    #
    # _@return_ — The lazily-loaded VM resource object.
    sig { params(name: String, admin: T::Boolean).returns(Models::VMResource) }
    def vm_resource(name, admin: false); end

    # Retrieve a list of the VM configurations associated with the client's token. Orka returns information about the
    # base image, CPU cores, owner and name of the VM configurations.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@return_ — The enumerator of the VM configuration list.
    sig { returns(Models::Enumerator[Models::VMConfiguration]) }
    def vm_configurations; end

    # Fetches information on a particular VM configuration.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any attribute is accessed or any method is called on the returned object, or otherwise forced via
    # {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    # exists.
    #
    # _@param_ `name` — The name of the VM configuration to fetch.
    #
    # _@return_ — The lazily-loaded VM configuration.
    sig { params(name: String).returns(Models::VMConfiguration) }
    def vm_configuration(name); end

    # Create a VM configuration that is ready for deployment. In Orka, VM configurations are container templates.
    # You can deploy multiple VMs from a single VM configuration. You cannot modify VM configurations.
    #
    # This method requires the client to be configured with a token.
    #
    # _@param_ `name` — The name of the VM configuration. This string must consist of lowercase Latin alphanumeric characters or the dash (+-+). This string must begin and end with an alphanumeric character. This string must not exceed 38 characters.
    #
    # _@param_ `base_image` — The name of the base image that you want to use with the configuration. If you want to attach an ISO to the VM configuration from which to install macOS, make sure that the base image is an empty disk of a sufficient size.
    #
    # _@param_ `snapshot_image` — A name for the {https://orkadocs.macstadium.com/docs/orka-glossary#section-snapshot-image snapshot image} of the VM. Typically, the same value as +name+.
    #
    # _@param_ `cpu_cores` — The number of CPU cores to dedicate for the VM. Must be 3, 4, 6, 8, 12, or 24.
    #
    # _@param_ `vcpu_count` — The number of vCPUs for the VM. Must equal the number of CPUs, when CPU is less than or equal to 3. Otherwise, must equal half of or exactly the number of CPUs specified.
    #
    # _@param_ `iso_image` — An ISO to attach to the VM on deployment. The option is supported for VMs deployed on Intel nodes only.
    #
    # _@param_ `attached_disk` — An additional storage disk to attach to the VM on deployment. The option is supported for VMs deployed on Intel nodes only.
    #
    # _@param_ `vnc_console` — By default, +true+. Enables or disables VNC for the VM configuration. You can override on deployment of specific VMs.
    #
    # _@param_ `system_serial` — Assign an owned macOS system serial number to the VM configuration. The option is supported for VMs deployed on Intel nodes only.
    #
    # _@param_ `io_boost` — By default, +false+ for VM configurations created before Orka 1.5. Default value for VM configurations created with Orka 1.5 or later depends on the cluster default. Enables or disables IO performance improvements for the VM configuration. The option is supported for VMs deployed on Intel nodes only.
    #
    # _@param_ `net_boost` — By default, +false+ for VM configurations created before Orka 2.3.0. Default value for VM configurations created with Orka 2.3.0 or later depends on the cluster default. Enables or disables network performance improvements for the VM configuration. The option is supported for VMs deployed on Intel nodes only.
    #
    # _@param_ `gpu_passthrough` — Enables or disables GPU passthrough for the VM. When enabled, +vnc_console+ is automatically disabled. The option is supported for VMs deployed on Intel nodes only. GPU passthrough must first be enabled in your cluster.
    #
    # _@param_ `tag` — When specified, the VM is preferred to be deployed to a node marked with this tag.
    #
    # _@param_ `tag_required` — By default, +false+. When set to +true+, the VM is required to be deployed to a node marked with this tag.
    #
    # _@param_ `scheduler` — Possible values are +:default+ and +:most-allocated+. By default, +:default+. When set to +:most-allocated+ VMs deployed from the VM configuration will be scheduled to nodes having most of their resources allocated. +:default+ keeps used vs free resources balanced between the nodes.
    #
    # _@param_ `memory`
    #
    # _@return_ — The lazily-loaded VM configuration.
    sig do
      params(
        name: String,
        base_image: T.any(Models::Image, String),
        snapshot_image: T.any(Models::Image, String),
        cpu_cores: Integer,
        vcpu_count: Integer,
        iso_image: T.nilable(T.any(Models::ISO, String)),
        attached_disk: T.nilable(T.any(Models::Image, String)),
        vnc_console: T.nilable(T::Boolean),
        system_serial: T.nilable(String),
        io_boost: T.nilable(T::Boolean),
        net_boost: T.nilable(T::Boolean),
        gpu_passthrough: T.nilable(T::Boolean),
        tag: T.nilable(String),
        tag_required: T.nilable(T::Boolean),
        scheduler: T.nilable(Symbol),
        memory: T.nilable(Numeric)
      ).returns(Models::VMConfiguration)
    end
    def create_vm_configuration(name, base_image:, snapshot_image:, cpu_cores:, vcpu_count:, iso_image: nil, attached_disk: nil, vnc_console: nil, system_serial: nil, io_boost: nil, net_boost: nil, gpu_passthrough: nil, tag: nil, tag_required: nil, scheduler: nil, memory: nil); end

    # Retrieve a list of the nodes in your Orka environment. Orka returns a list of nodes with IP and resource
    # information.
    #
    # If you set the admin parameter to true, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@param_ `admin` — Set to true to allow nodes dedicated to other users to be queried.
    #
    # _@return_ — The enumerator of the node list.
    sig { params(admin: T::Boolean).returns(Models::Enumerator[Models::Node]) }
    def nodes(admin: false); end

    # Fetches information on a particular node.
    #
    # If you set the admin parameter to true, this method requires the client to be configured with both a
    # token and a license key. Otherwise, it only requires a token.
    #
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any attribute is accessed or any method is called on the returned object, or otherwise forced via
    # {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    # exists.
    #
    # _@param_ `name` — The name of the node to fetch.
    #
    # _@param_ `admin` — Set to true to allow nodes dedicated with other users to be queried.
    #
    # _@return_ — The lazily-loaded node object.
    sig { params(name: String, admin: T::Boolean).returns(Models::VMResource) }
    def node(name, admin: false); end

    # Retrieve a list of the base images and empty disks in your Orka environment.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@return_ — The enumerator of the image list.
    sig { returns(Models::Enumerator[Models::Image]) }
    def images; end

    # Fetches information on a particular image.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any attribute is accessed or any method is called on the returned object, or otherwise forced via
    # {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    # exists.
    #
    # _@param_ `name` — The name of the image to fetch.
    #
    # _@return_ — The lazily-loaded image.
    sig { params(name: String).returns(Models::Image) }
    def image(name); end

    # List the base images available in the Orka remote repo.
    #
    # To use one of the images from the remote repo, you can {Models::RemoteImage#pull pull} it into the local Orka
    # storage.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@return_ — The enumerator of the remote image list.
    sig { returns(Models::Enumerator[Models::RemoteImage]) }
    def remote_images; end

    # Returns an object representing a remote image of a specified name.
    #
    # Note that this method does not perform any network requests and does not verify if the name supplied actually
    # exists in the Orka remote repo.
    #
    # _@param_ `name` — The name of the remote image.
    #
    # _@return_ — The remote image object.
    sig { params(name: String).returns(Models::RemoteImage) }
    def remote_image(name); end

    # Generate an empty base image. You can use it to create VM configurations that will use an ISO or you can attach
    # it to a deployed VM to extend its storage.
    #
    # This method requires the client to be configured with a token.
    #
    # _@param_ `name` — The name of this new image.
    #
    # _@param_ `size` — The size of this new image (in K, M, G, or T), for example +"10G"+.
    #
    # _@return_ — The new lazily-loaded image.
    #
    # _@note_ — This request is supported for Intel images only. Intel images have +.img+ extension.
    sig { params(name: String, size: String).returns(Models::Image) }
    def generate_empty_image(name, size:); end

    # Upload an image to the Orka environment.
    #
    # This method requires the client to be configured with a token.
    #
    # _@param_ `file` — The string file path or an open IO object to the image to upload.
    #
    # _@param_ `name` — The name to give to this image. Defaults to the local filename.
    #
    # _@return_ — The new lazily-loaded image.
    #
    # _@note_ — This request is supported for Intel images only. Intel images have +.img+ extension.
    sig { params(file: T.any(String, IO), name: T.nilable(String)).returns(Models::Image) }
    def upload_image(file, name: nil); end

    # Retrieve a list of the ISOs available in the local Orka storage.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@return_ — The enumerator of the ISO list.
    #
    # _@note_ — All ISO requests are supported for Intel nodes only.
    sig { returns(Models::Enumerator[Models::ISO]) }
    def isos; end

    # Fetches information on a particular ISO in local Orka storage.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any attribute is accessed or any method is called on the returned object, or otherwise forced via
    # {Models::LazyModel#eager}. Successful return from this method does not guarantee the requested resource
    # exists.
    #
    # _@param_ `name` — The name of the ISO to fetch.
    #
    # _@return_ — The lazily-loaded ISO.
    #
    # _@note_ — All ISO requests are supported for Intel nodes only.
    sig { params(name: String).returns(Models::ISO) }
    def iso(name); end

    # List the ISOs available in the Orka remote repo.
    #
    # To use one of the ISOs from the remote repo, you can {Models::RemoteISO#pull pull} it into the local Orka
    # storage.
    #
    # This method requires the client to be configured with a token.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@return_ — The enumerator of the remote ISO list.
    #
    # _@note_ — All ISO requests are supported for Intel nodes only.
    sig { returns(Models::Enumerator[Models::RemoteISO]) }
    def remote_isos; end

    # Returns an object representing a remote ISO of a specified name.
    #
    # Note that this method does not perform any network requests and does not verify if the name supplied actually
    # exists in the Orka remote repo.
    #
    # _@param_ `name` — The name of the remote ISO.
    #
    # _@return_ — The remote ISO object.
    #
    # _@note_ — All ISO requests are supported for Intel nodes only.
    sig { params(name: String).returns(Models::RemoteISO) }
    def remote_iso(name); end

    # Upload an ISO to the Orka environment.
    #
    # This method requires the client to be configured with a token.
    #
    # _@param_ `file` — The string file path or an open IO object to the ISO to upload.
    #
    # _@param_ `name` — The name to give to this ISO. Defaults to the local filename.
    #
    # _@return_ — The new lazily-loaded ISO.
    #
    # _@note_ — All ISO requests are supported for Intel nodes only.
    sig { params(file: T.any(String, IO), name: T.nilable(String)).returns(Models::ISO) }
    def upload_iso(file, name: nil); end

    # Retrieve a list of kube-accounts associated with an Orka user.
    #
    # This method requires the client to be configured with both a token and a license key.
    # The network operation is not performed immediately upon return of this method. The request is performed when
    # any action is performed on the enumerator, or otherwise forced via {Models::Enumerator#eager}.
    #
    # _@param_ `user` — The user, which can be specified by the user object or their email address, for which we are returning the associated kube-accounts of. Defaults to the user associated with the client's token.
    #
    # _@return_ — The enumerator of the kube-account list.
    sig { params(user: T.nilable(T.any(Models::User, String))).returns(Models::Enumerator[Models::KubeAccount]) }
    def kube_accounts(user: nil); end

    # Returns an object representing a kube-account of a particular user.
    #
    # Note that this method does not perform any network requests and does not verify if the name supplied actually
    # exists in the Orka environment.
    #
    # _@param_ `name` — The name of the kube-account.
    #
    # _@param_ `user` — The user, which can be specified by the user object or their email address, of which the kube-account is associated with. Defaults to the user associated with the client's token.
    #
    # _@return_ — The kube-account object.
    sig { params(name: String, user: T.nilable(T.any(Models::User, String))).returns(Models::KubeAccount) }
    def kube_account(name, user: nil); end

    # Create a kube-account.
    #
    # This method requires the client to be configured with both a token and a license key.
    #
    # _@param_ `name` — The name of the kube-account.
    #
    # _@param_ `user` — The user, which can be specified by the user object or their email address, of which the kube-account will be associated with. Defaults to the user associated with the client's token.
    #
    # _@return_ — The created kube-account.
    sig { params(name: String, user: T.nilable(T.any(Models::User, String))).returns(Models::KubeAccount) }
    def create_kube_account(name, user: nil); end

    # Delete all kube-accounts associated with a user.
    #
    # This method requires the client to be configured with both a token and a license key.
    #
    # _@param_ `user` — The user, which can be specified by the user object or their email address, which will have their associated kube-account deleted. Defaults to the user associated with the client's token.
    sig { params(user: T.nilable(T.any(Models::User, String))).void }
    def delete_all_kube_accounts(user: nil); end

    # Retrieve a log of all CLI commands and API requests executed against your Orka environment.
    #
    # This method requires the client to be configured with a license key.
    #
    # _@param_ `limit` — Limit the amount of results returned to this quantity.
    #
    # _@param_ `start` — Limit the results to be log entries after this date.
    #
    # _@param_ `query` — The LogQL query to filter by. Defaults to +{log_type="user_logs"}+.
    #
    # _@return_ — A raw Grafana Loki query result payload. Parsing this is out-of-scope for this gem.
    sig { params(limit: T.nilable(Integer), start: T.nilable(DateTime), query: T.nilable(String)).returns(T::Hash[T.untyped, T.untyped]) }
    def logs(limit: nil, start: nil, query: nil); end

    # Retrieve information about the token associated with the client. The request returns information about the
    # associated email address, the authentication status of the token, and if the token is revoked.
    #
    # This method requires the client to be configured with a token.
    #
    # _@return_ — Information about the token.
    sig { returns(Models::TokenInfo) }
    def token_info; end

    # Retrieve detailed information about the health of your Orka environment.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@return_ — The status information on different components of your environment.
    sig { returns(T::Hash[T.untyped, T.untyped]) }
    def environment_status; end

    # Retrieve the current API version of your Orka environment.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@return_ — The remote API version.
    sig { returns(String) }
    def remote_api_version; end

    # Retrieve the current version of the components in your Orka environment.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@return_ — The version of each component.
    sig { returns(T::Hash[String, String]) }
    def environment_component_versions; end

    # Retrieve the current password requirements for creating an Orka user.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@return_ — The password requirements.
    sig { returns(Models::PasswordRequirements) }
    def password_requirements; end

    # Check if a license key is authorized or not.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@param_ `license_key` — The license key to check. Defaults to the one associated with the client.
    #
    # _@return_ — True if the license key is valid.
    sig { params(license_key: String).returns(T::Boolean) }
    def license_key_valid?(license_key = @license_key); end

    # Retrieve the default base image for the Orka environment.
    #
    # This method does not require the client to be configured with any credentials.
    #
    # _@return_ — The lazily-loaded default base image object.
    sig { returns(Models::Image) }
    def default_base_image; end

    # Upload a custom TLS certificate and its private key in PEM format from your computer to your cluster. You can
    # then access Orka via {https://orkadocs.macstadium.com/docs/custom-tls-certificate external custom domain}.
    #
    # The certificate and the key must meet the following requirements:
    #
    # * Both files are in PEM format.
    # * The private key is not passphrase protected.
    # * The certificate might be any of the following:
    #   * A single domain certificate (e.g. +company.com+).
    #   * Multi-domain certificate (e.g. +app1.company.com+, +app2.company.com+, and so on).
    #   * Wildcard TLS certificate (e.g. +*.company.com+). If containing an asterisk, it must be a single asterisk
    #     and must be in the leftmost position of the domain name. For example: You cannot use a +*.*.company.com+
    #     certificate to work with Orka.
    #   * A certificate chain (bundle) that contains your server, intermediates, and root certificates concatenated
    #     (in the proper order) into one file.
    # * The certificate must be a domain certificate issued by a certificate authority for a registered domain OR a
    #   self-signed certificate for any domain
    #   ({https://orkadocs.macstadium.com/docs/custom-tls-certificate#32-create-a-local-mapping for local use only}).
    #
    # This method requires the client to be configured with both a token and a license key.
    #
    # _@param_ `cert` — The string file path or an open IO object to the certificate.
    #
    # _@param_ `key` — The string file path or an open IO object to the key.
    sig { params(cert: T.any(String, IO), key: T.any(String, IO)).void }
    def upload_tls_certificate(cert, key); end
  end

  # Base error class.
  class Error < StandardError
  end

  # This error is thrown if an endpoint requests an auth mechanism which we do not have credentials for.
  class AuthConfigurationError < OrkaAPI::Error
  end

  # This error is thrown if a specific resource is requested but it was not found in the Orka backend.
  class ResourceNotFoundError < OrkaAPI::Error
  end

  # This error is thrown if the client receives data from the server it does not recognise. This is typically
  # indicative of a bug or a feature not yet implemented.
  class UnrecognisedStateError < OrkaAPI::Error
  end

  # @api private
  class Connection < Faraday::Connection
    # _@param_ `base_url`
    #
    # _@param_ `token`
    #
    # _@param_ `license_key`
    sig { params(base_url: String, token: T.nilable(String), license_key: T.nilable(String)).void }
    def initialize(base_url, token: nil, license_key: nil); end
  end

  # Represents a port forwarding from a host node to a guest VM.
  class PortMapping
    # _@param_ `host_port` — The port on the node side.
    #
    # _@param_ `guest_port` — The port on the VM side.
    sig { params(host_port: Integer, guest_port: Integer).void }
    def initialize(host_port:, guest_port:); end

    # _@return_ — The port on the node side.
    sig { returns(Integer) }
    attr_reader :host_port

    # _@return_ — The port on the VM side.
    sig { returns(Integer) }
    attr_reader :guest_port
  end
end
