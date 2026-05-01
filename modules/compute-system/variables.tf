variable "compartment_ocid" {
  type        = string
  description = "Compartment where the compute-system BM is created."
}

variable "subnet_id" {
  type        = string
  description = "Private subnet OCID for the compute-system primary VNIC."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain for the compute-system BM."
}

variable "ssh_public_keys" {
  type        = string
  description = "Newline-separated SSH authorized keys for the compute-system BM."
}

variable "kove_namespace" {
  type        = string
  description = "Short project prefix for names and tags."
  default     = "kove"
}

variable "kove_environment" {
  type        = string
  description = "Environment label."
  default     = "dev"
}

variable "kove_stack_name" {
  type        = string
  description = "Stack identifier used in naming."
  default     = "rdma"
}

variable "name_prefix_override" {
  type        = string
  description = "Optional explicit prefix for compute-system display_name fields. Empty uses labels default composition."
  default     = ""
}

variable "host_label_prefix" {
  type        = string
  description = "Optional DNS-safe prefix for hostname labels."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Extra freeform tags."
  default     = {}
}

variable "rdma_deployment_mode" {
  type        = string
  description = "RDMA deployment mode: compute_cluster or cluster_network."

  validation {
    condition     = contains(["compute_cluster", "cluster_network"], trimspace(var.rdma_deployment_mode))
    error_message = "rdma_deployment_mode must be either compute_cluster or cluster_network."
  }
}

variable "compute_cluster_id" {
  type        = string
  description = "Compute cluster OCID used when rdma_deployment_mode is compute_cluster."
  default     = null
}

variable "compute_system_name" {
  type        = string
  description = "Role label for the compute-system BM."
  default     = "compute-system"
}

variable "xpd_name" {
  type        = string
  description = "Role label for the RDMA memory node pool."
  default     = "xpd"
}

variable "image_ocid" {
  type        = string
  description = "Image OCID for the compute-system BM."
}

variable "shape" {
  type        = string
  description = "Bare metal shape for the compute-system BM."
  default     = "BM.Optimized3.36"
}

variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB."
  default     = 120
}

variable "capacity_reservation_id" {
  type        = string
  description = "Optional capacity reservation OCID."
  default     = ""
}

variable "generic_platform_config" {
  type        = bool
  description = "Enable GENERIC_BM platform_config."
  default     = false
}

variable "smt_enabled" {
  type        = bool
  description = "Enable symmetric multithreading when generic platform config is used."
  default     = true
}

variable "numa_nodes_per_socket" {
  type        = string
  description = "NUMA nodes per socket when generic platform config is used."
  default     = "NPS1"
}

variable "use_compute_agent" {
  type        = bool
  description = "Enable Oracle Cloud Agent HPC RDMA plugins."
  default     = false
}

variable "instance_create_timeout" {
  type        = string
  description = "BM create timeout. Empty uses 2h."
  default     = ""
}

variable "cloud_init_template_path" {
  type        = string
  description = "Optional RDMA cloud-init template path. Empty uses the xpd-cluster module template."
  default     = ""
}

variable "rhsm_org_id" {
  type        = string
  description = "RHSM organization ID injected into cloud-init."
  default     = ""
  sensitive   = true
}

variable "rhsm_activation_key" {
  type        = string
  description = "RHSM activation key injected into cloud-init."
  default     = ""
  sensitive   = true
}

variable "playbooks_zip_url" {
  type        = string
  description = "Optional HTTPS URL for playbooks.zip. Empty skips download."
  default     = ""
}

variable "offline_repo_tarball_url" {
  type        = string
  description = "Optional URL or absolute local path to an offline RPM repo tarball."
  default     = ""
  sensitive   = true
}

variable "offline_repo_tarball_sha256" {
  type        = string
  description = "Optional SHA256 checksum for offline_repo_tarball_url."
  default     = ""
}

variable "offline_base_rpm_packages" {
  type        = string
  description = "Base package names installed from the offline RPM repository when configured."
  default     = "python3 jq unzip curl ansible-core"
}

variable "offline_rdma_rpm_packages" {
  type        = string
  description = "RDMA package names installed from the offline RPM repository when configured."
  default     = "rdma-core libibverbs infiniband-diags librdmacm-utils libibverbs-utils kove-oci-hpc-ansible"
}

variable "cloud_init_template_extra_vars" {
  type        = map(string)
  description = "Extra string placeholders merged into the cloud-init template."
  default     = {}
  sensitive   = true
}

variable "bm_imds_ssh_key_bootstrap" {
  type        = bool
  description = "First-boot script copies SSH keys from IMDS to common users on custom RHEL images."
  default     = true
}
