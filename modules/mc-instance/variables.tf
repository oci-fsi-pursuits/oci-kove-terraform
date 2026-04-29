variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID (used for AD lookup)."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment where the MC host instance is created."
}

variable "subnet_id" {
  type        = string
  description = "Target subnet OCID for the MC host VNIC."
}

variable "availability_domain" {
  type        = string
  description = "Optional AD override. Empty = first AD in tenancy."
  default     = ""
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected for opc/cloud-user access."
}

variable "kove_namespace" {
  type        = string
  description = "Short project prefix for names and tags."
  default     = "kove"
}

variable "kove_environment" {
  type        = string
  description = "Environment label (dev, staging, prod)."
  default     = "dev"
}

variable "kove_stack_name" {
  type        = string
  description = "Stack identifier used in naming."
  default     = "rdma"
}

variable "tags" {
  type        = map(string)
  description = "Extra freeform tags."
  default     = {}
}

variable "instance_name_suffix" {
  type        = string
  description = "Suffix used for display_name."
  default     = "mc-host"
}

variable "hostname_label" {
  type        = string
  description = "Optional DNS-safe hostname label for the primary VNIC."
  default     = ""
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign public IP to the MC host."
  default     = false
}

variable "secondary_vnic_enabled" {
  type        = bool
  description = "Attach a secondary VNIC to the MC host."
  default     = false
}

variable "secondary_vnic_subnet_id" {
  type        = string
  description = "Subnet OCID for MC host secondary VNIC when secondary_vnic_enabled is true."
  default     = ""
}

variable "secondary_vnic_private_ip" {
  type        = string
  description = "Optional fixed private IP for MC host secondary VNIC. Empty = auto-assign."
  default     = ""
}

variable "secondary_vnic_interface" {
  type        = string
  description = "Expected Linux interface name for the secondary VNIC used in cloud-init policy routing."
  default     = "eth1"
}

variable "shape" {
  type        = string
  description = "MC host shape."
  default     = "VM.Standard3.Flex"
}

variable "ocpus" {
  type        = number
  description = "MC host OCPUs."
  default     = 3
}

variable "memory_gbs" {
  type        = number
  description = "MC host memory in GB."
  default     = 32
}

variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB for the MC host."
  default     = 200
}

variable "deployment_mode" {
  type        = string
  description = "custom_image or cloud_init_setup."
  default     = "custom_image"

  validation {
    condition     = contains(["custom_image", "cloud_init_setup"], trimspace(var.deployment_mode))
    error_message = "deployment_mode must be one of: custom_image, cloud_init_setup."
  }
}

variable "custom_image_ocid" {
  type        = string
  description = "Custom image OCID when deployment_mode = custom_image."
  default     = ""
}

variable "base_image_ocid" {
  type        = string
  description = "Optional base image OCID when deployment_mode = cloud_init_setup. Empty = latest Oracle Linux 8 for selected shape."
  default     = ""
}

variable "cloud_init_template_path" {
  type        = string
  description = "Optional path to cloud-init template. Empty = module default."
  default     = ""
}

variable "offline_repo_tarball_url" {
  type        = string
  description = "Optional URL or absolute local path to a tar.gz containing a createrepo-generated RPM repository for offline cloud-init installs."
  default     = ""
  sensitive   = true
}

variable "offline_repo_tarball_sha256" {
  type        = string
  description = "Optional SHA256 checksum for offline_repo_tarball_url."
  default     = ""
}

variable "offline_rpm_packages" {
  type        = string
  description = "Space-separated package names installed from the offline RPM repository when offline_repo_tarball_url is set."
  default     = "qemu-kvm libvirt virt-install qemu-img libguestfs-tools-c python3"
}

variable "setup_script_path" {
  type        = string
  description = "Path where the MC helper script is created on host for cloud_init_setup mode."
  default     = "/opt/kove/setup-kove-mc.sh"
}

variable "guest_vm_name" {
  type        = string
  description = "Default KVM guest VM name used by setup helper script."
  default     = "kove-mc"
}

variable "guest_disk_path" {
  type        = string
  description = "Default KVM guest qcow2 path used by setup helper script."
  default     = "/var/lib/libvirt/images/kove-mc.qcow2"
}

variable "guest_memory_mb" {
  type        = number
  description = "Default guest memory in MB used by setup helper script."
  default     = 8192
}

variable "guest_vcpus" {
  type        = number
  description = "Default guest vCPU count used by setup helper script."
  default     = 2
}
