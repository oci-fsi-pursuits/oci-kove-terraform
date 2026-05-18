# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID."
}

variable "region" {
  type        = string
  description = "OCI region."
}

variable "identity_home_region" {
  type        = string
  description = "Home region for IAM create/update/delete operations."
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment for RDMA memory-node infrastructure."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for BM memory-node access."
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
  description = "Compatibility stack identifier. Not included in default display names."
  default     = "rdma"
}

variable "name_prefix_override" {
  type        = string
  description = "Optional explicit prefix for xpd/rdma-platform display_name fields. Empty uses labels default composition."
  default     = ""
}

variable "host_label_prefix" {
  type        = string
  description = "Optional DNS-safe prefix for hostname labels."
  default     = ""
}

variable "availability_domain" {
  type        = string
  description = "Availability domain for RDMA memory nodes. Empty uses subnet AD or first tenancy AD."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Extra defined tag values applied to RDMA resources."
  default     = {}
}

variable "defined_tag_namespace" {
  type        = string
  description = "OCI defined tag namespace used for standard tags."
  default     = "kove"
}

variable "enable_defined_tags" {
  type        = bool
  description = "Apply OCI defined tags to RDMA resources."
  default     = true
}

# ---------------------------------------------------------------------------
# Caller-provided networking
# ---------------------------------------------------------------------------
variable "use_existing_vcn" {
  type        = bool
  description = "Whether the root module supplied existing subnet IDs."
  default     = true
}

variable "existing_vcn_id" {
  type        = string
  description = "VCN OCID supplied by the root module."
}

variable "existing_public_subnet_id" {
  type        = string
  description = "Public subnet OCID supplied by the root module."
}

variable "existing_private_subnet_id" {
  type        = string
  description = "Private subnet OCID for RDMA memory nodes."
}

variable "enable_ipv6" {
  type        = bool
  description = "Assign IPv6 address(es) on RDMA memory-node VNICs."
  default     = true
}

variable "public_route_table_id" {
  type        = string
  description = "Public route table OCID supplied by the root module."
  default     = ""
}

variable "private_route_table_id" {
  type        = string
  description = "Private route table OCID supplied by the root module."
  default     = ""
}

# ---------------------------------------------------------------------------
# RDMA memory nodes
# ---------------------------------------------------------------------------
variable "bm_node_shape" {
  type        = string
  description = "Bare metal shape for RDMA memory nodes."
  default     = "BM.Optimized3.36"
}

variable "rdma_deployment_mode" {
  type        = string
  description = "RDMA deployment mode: compute_cluster or cluster_network."
  default     = "compute_cluster"

  validation {
    condition     = contains(["compute_cluster", "cluster_network"], trimspace(var.rdma_deployment_mode))
    error_message = "rdma_deployment_mode must be either compute_cluster or cluster_network."
  }
}

variable "bm_node_image_ocid" {
  type        = string
  description = "Image OCID for RDMA memory nodes."
}

variable "bm_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB for RDMA memory nodes."
  default     = 120
}

variable "memory_node_count" {
  type        = number
  description = "Number of RDMA memory nodes."
  default     = 2

  validation {
    condition     = var.memory_node_count >= 0 && var.memory_node_count <= 32
    error_message = "memory_node_count must be between 0 and 32."
  }
}

variable "xpd_name" {
  type        = string
  description = "Role label for RDMA memory node resources."
  default     = "xpd"
}

variable "bm_capacity_reservation_id" {
  type        = string
  description = "Optional capacity reservation OCID for RDMA memory nodes."
  default     = ""
}

variable "bm_generic_platform_config" {
  type        = bool
  description = "Enable GENERIC_BM platform_config for RDMA memory nodes."
  default     = false
}

variable "bm_smt_enabled" {
  type        = bool
  description = "Enable symmetric multithreading when generic platform config is used."
  default     = true
}

variable "bm_numa_nodes_per_socket" {
  type        = string
  description = "NUMA nodes per socket when generic platform config is used."
  default     = "NPS1"
}

variable "use_compute_agent" {
  type        = bool
  description = "Enable Oracle Cloud Agent HPC RDMA plugins on memory nodes."
  default     = false
}

variable "bm_imds_ssh_key_bootstrap" {
  type        = bool
  description = "First-boot script copies SSH keys from IMDS to common users on custom RHEL images."
  default     = true
}

variable "cluster_network_create_timeout" {
  type        = string
  description = "Per-BM instance create timeout. Empty uses 2h."
  default     = ""
}

variable "create_bm_console_connections" {
  type        = bool
  description = "Create OCI instance console connections for each compute_cluster memory node."
  default     = false
}

# ---------------------------------------------------------------------------
# Cluster placement group
# ---------------------------------------------------------------------------
variable "cluster_placement_group_enabled" {
  type        = bool
  description = "Create and assign a cluster placement group for compute_cluster memory nodes."
  default     = false
}

variable "cluster_placement_group_type" {
  type        = string
  description = "OCI cluster placement group type."
  default     = "STANDARD"
}

variable "cluster_placement_group_name" {
  type        = string
  description = "Optional cluster placement group display name."
  default     = ""
}

variable "cluster_placement_group_description" {
  type        = string
  description = "Optional cluster placement group description."
  default     = ""
}

# ---------------------------------------------------------------------------
# Cluster network autoscaling
# ---------------------------------------------------------------------------
variable "cluster_network_enable_autoscaling" {
  type        = bool
  description = "Enable OCI autoscaling for the cluster-network memory pool."
  default     = false
}

variable "cluster_network_autoscaling_min_nodes" {
  type        = number
  description = "Minimum memory nodes in autoscaling configuration."
  default     = 1
}

variable "cluster_network_autoscaling_max_nodes" {
  type        = number
  description = "Maximum memory nodes in autoscaling configuration."
  default     = 8
}

variable "cluster_network_autoscaling_initial_nodes" {
  type        = number
  description = "Initial memory node count for autoscaling policy capacity."
  default     = 2
}

variable "cluster_network_autoscaling_cooldown_seconds" {
  type        = number
  description = "Autoscaling cooldown in seconds."
  default     = 300
}

variable "cluster_network_autoscaling_scale_out_threshold_percent" {
  type        = number
  description = "Scale-out memory utilization threshold percent."
  default     = 75
}

variable "cluster_network_autoscaling_scale_in_threshold_percent" {
  type        = number
  description = "Scale-in memory utilization threshold percent."
  default     = 30
}

variable "cluster_network_autoscaling_scale_out_by" {
  type        = number
  description = "Number of memory nodes to add per scale-out action."
  default     = 1
}

variable "cluster_network_autoscaling_scale_in_by" {
  type        = number
  description = "Number of memory nodes to remove per scale-in action."
  default     = 1
}

# ---------------------------------------------------------------------------
# Cloud-init and offline RPM inputs
# ---------------------------------------------------------------------------
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
  description = "Optional URL or absolute local path to a tar.gz containing a createrepo-generated RPM repository for offline cloud-init installs."
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
  description = "Space-separated base package names installed from the offline RPM repository when offline_repo_tarball_url is set."
  default     = "python3 jq unzip curl ansible-core"
}

variable "offline_rdma_rpm_packages" {
  type        = string
  description = "Space-separated RDMA package names installed from the offline RPM repository on memory nodes when offline_repo_tarball_url is set."
  default     = "rdma-core libibverbs infiniband-diags librdmacm-utils libibverbs-utils kove-oci-hpc-ansible"
}

variable "cloud_init_template_extra_vars" {
  type        = map(string)
  description = "Extra string placeholders merged into RDMA cloud-init templates."
  default     = {}
  sensitive   = true
}
