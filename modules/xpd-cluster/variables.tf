# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "region" {
  type        = string
  description = "OCI region (e.g. us-phoenix-1)"
}

variable "identity_home_region" {
  type        = string
  description = "Home region for IAM create/update/delete operations (tenancy home region)."
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment for all resources"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for opc on VMs and combined with generated key on BMs"
}

variable "kove_namespace" {
  type        = string
  description = "Short project prefix for names and tags (see modules/labels)."
  default     = "kove"
}

variable "kove_environment" {
  type        = string
  description = "Environment label (dev, staging, prod, …)."
  default     = "dev"
}

variable "kove_stack_name" {
  type        = string
  description = "Stack identifier (e.g. rdma-ash). Display names use module.labels.name_prefix = namespace-environment-stack_name."
  default     = "rdma"
}

variable "host_label_prefix" {
  type        = string
  description = "Optional DNS-safe prefix for instance hostname labels."
  default     = ""
}

variable "availability_domain" {
  type        = string
  description = "Single AD for bastion, management VM, compute cluster, and BMs (e.g. pILZ:PHX-AD-2). Empty = derive from rdma subnet (existing VCN) or first tenancy AD."
  default     = ""
}

# ---------------------------------------------------------------------------
# Networking: create VCN vs existing
# ---------------------------------------------------------------------------
variable "use_existing_vcn" {
  type        = bool
  description = "false = create VCN with public + private subnets; true = supply subnet OCIDs"
  default     = false
}

variable "vcn_cidr_block" {
  type        = string
  description = "VCN CIDR when creating a new VCN. Subnets: /24 at indices 1 (public), 2 (private)."
  default     = "10.0.0.0/16"
}

variable "private_subnet_name_prefix" {
  type        = string
  description = "Optional prefix added to private subnet display name when creating networking."
  default     = ""
}

variable "existing_vcn_id" {
  type        = string
  description = "Existing VCN OCID (informational output when using existing subnets)"
  default     = ""
}

variable "existing_public_subnet_id" {
  type        = string
  description = "Public subnet for optional bastion (must allow SSH from Internet if bastion enabled)"
  default     = ""
}

variable "existing_private_subnet_id" {
  type        = string
  description = "Private subnet for management VM and BM compute cluster (primary VNIC placement)."
  default     = ""
}

variable "private_subnet_ssh_sources_extras" {
  type        = string
  description = "Comma-separated CIDRs allowed SSH to private subnets in addition to VCN CIDR (when Terraform creates security lists)"
  default     = ""
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR for TCP 22 (and optional 3000/5000) on the **public** subnet when Terraform creates the VCN — same role as oci-hpc `ssh_cidr`."
  default     = "0.0.0.0/0"
}

variable "public_ingress_hpc_ui_ports" {
  type        = bool
  description = "When creating the VCN: allow TCP 3000 and 5000 from ssh_ingress_cidr on the public subnet (oci-hpc public security list)."
  default     = true
}

# ---------------------------------------------------------------------------
# Optional bastion (public subnet)
# ---------------------------------------------------------------------------
variable "enable_bastion" {
  type        = bool
  description = "Create a small Oracle Linux VM in the public subnet for jump access"
  default     = true
}

variable "bastion_shape" {
  type        = string
  description = "Bastion compute shape (same VM family as stig-hardened-builds/oke-cluster worker node_pool_shape)."
  default     = "VM.Standard.E6.Flex"
}

variable "bastion_ocpus" {
  type        = number
  description = "Bastion OCPUs (E6.Flex); matches oke-cluster node_pool_ocpus default."
  default     = 2
}

variable "bastion_memory_gbs" {
  type        = number
  description = "Bastion memory in GB (E6.Flex); matches oke-cluster node_pool_memory_gbs default."
  default     = 16
}

variable "bastion_image_ocid" {
  type        = string
  description = "Optional custom image OCID for bastion; empty = latest Oracle Linux 8 for this shape"
  default     = ""
}

# ---------------------------------------------------------------------------
# Management VM (private subnet 1)
# ---------------------------------------------------------------------------
variable "management_shape" {
  type        = string
  description = "Same VM shape as oke-cluster workers by default (VM.Standard.E6.Flex)."
  default     = "VM.Standard.E6.Flex"
}

variable "management_ocpus" {
  type        = number
  description = "Matches oke-cluster node_pool_ocpus default (2)."
  default     = 2
}

variable "management_memory_gbs" {
  type        = number
  description = "Matches oke-cluster node_pool_memory_gbs default (16)."
  default     = 16
}

variable "management_image_ocid" {
  type        = string
  description = "Optional custom image; empty = latest Oracle Linux 8"
  default     = ""
}

variable "management_secondary_vnic_enabled" {
  type        = bool
  description = "Attach a secondary VNIC to the management controller."
  default     = false
}

variable "management_secondary_vnic_subnet_id" {
  type        = string
  description = "Optional subnet OCID for the management secondary VNIC. Empty defaults to the private subnet."
  default     = ""
}

variable "management_secondary_vnic_private_ip" {
  type        = string
  description = "Optional fixed private IP for the management secondary VNIC."
  default     = ""
}

# ---------------------------------------------------------------------------
# Management VM cloud-init (secrets stay out of Git — see README)
# ---------------------------------------------------------------------------
variable "management_cloud_init_template_path" {
  type        = string
  description = "Optional path to a cloud-init template. Empty = cloud_init/kove-rdma-cloud-init-standalone-runtime.txt. Secrets via rhsm_* and secrets.auto.tfvars. On Windows prefer forward slashes."
  default     = ""
}

variable "enable_management_instance" {
  type        = bool
  description = "Create the built-in management VM (kove-*-management). Set false when using a separate MC host as the single management node."
  default     = true
}

variable "rhsm_org_id" {
  type        = string
  description = "RHSM organization ID; injected into cloud-init template as rhsm_org_id. Leave empty if unused."
  default     = ""
  sensitive   = true
}

variable "rhsm_activation_key" {
  type        = string
  description = "RHSM activation key; injected as rhsm_activation_key. Leave empty if unused."
  default     = ""
  sensitive   = true
}

variable "playbooks_zip_url" {
  type        = string
  description = "Optional HTTPS URL for playbooks.zip (injected into kove-rdma cloud-init). Empty skips download."
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
  description = "Space-separated RDMA package names installed from the offline RPM repository on BM/memory nodes when offline_repo_tarball_url is set."
  default     = "rdma-core libibverbs infiniband-diags librdmacm-utils libibverbs-utils kove-oci-hpc-ansible"
}

variable "cloud_init_template_extra_vars" {
  type        = map(string)
  description = "Extra string placeholders for your management cloud-init template (e.g. other_api_token). Merged with rhsm_*; all values are treated as sensitive for plan output."
  default     = {}
  sensitive   = true
}

# ---------------------------------------------------------------------------
# BM plane (RDMA subnet) — control + scalable memory nodes
# ---------------------------------------------------------------------------
variable "bm_node_shape" {
  type        = string
  description = "Bare metal shape for control and memory nodes (oke-cluster uses VM.Standard.E6.Flex workers only; no BM in OKE node pool)."
  default     = "BM.Optimized3.36"
}

variable "rdma_deployment_mode" {
  type        = string
  description = "RDMA deployment mode: compute_cluster (individual BM instances in a compute cluster) or cluster_network (OCI cluster network instance pool)."
  default     = "compute_cluster"

  validation {
    condition     = contains(["compute_cluster", "cluster_network"], trimspace(var.rdma_deployment_mode))
    error_message = "rdma_deployment_mode must be either compute_cluster or cluster_network."
  }
}

variable "bm_node_image_ocid" {
  type        = string
  description = "Custom image OCID for all BM nodes (control + memory)"
}

variable "bm_boot_volume_size_gbs" {
  type    = number
  default = 120
}

# ---------------------------------------------------------------------------
# Cluster placement group (BM rack-aware placement; optional)
# ---------------------------------------------------------------------------
variable "cluster_placement_group_enabled" {
  type        = bool
  description = "Create oci_cluster_placement_groups_cluster_placement_group and assign each BM to it. Applies before instance create (explicit depends_on). Set false to skip or avoid replacing existing BMs that were created without a CPG."
  default     = false
}

variable "cluster_placement_group_type" {
  type        = string
  description = "OCI cluster placement group type (e.g. STANDARD). Must match your tenancy / workload; see Oracle Cluster Placement Groups docs."
  default     = "STANDARD"
}

variable "cluster_placement_group_name" {
  type        = string
  description = "CPG display name. Empty = \"{name_prefix}-rdma-cpg\"."
  default     = ""
}

variable "cluster_placement_group_description" {
  type        = string
  description = "CPG description. Empty = generated sentence from name_prefix."
  default     = ""
}

variable "memory_node_count" {
  type        = number
  description = "Number of BM.Optimized3 memory nodes (default 2 → 3 BM instances total with 1 control). Control node is always 1."
  default     = 2

  validation {
    condition     = var.memory_node_count >= 0 && var.memory_node_count <= 32
    error_message = "memory_node_count must be between 0 and 32."
  }
}

variable "compute_system_name" {
  type        = string
  description = "Display-name role label for the RDMA control/orchestrator node."
  default     = "compute-system"
}

variable "xpd_name" {
  type        = string
  description = "Display-name role label for RDMA memory nodes."
  default     = "xpd"
}

variable "bm_capacity_reservation_id" {
  type    = string
  default = ""
}

variable "bm_generic_platform_config" {
  type        = bool
  description = "GENERIC_BM platform_config (often must stay false for BM.Optimized3 on compute cluster)"
  default     = false
}

variable "bm_smt_enabled" {
  type    = bool
  default = true
}

variable "bm_numa_nodes_per_socket" {
  type    = string
  default = "NPS1"
}

variable "use_compute_agent" {
  type        = bool
  description = "Oracle Cloud Agent HPC RDMA plugins on BMs"
  default     = false
}

variable "bm_imds_ssh_key_bootstrap" {
  type        = bool
  description = "First-boot script to copy SSH keys from IMDS to opc/cloud-user/ec2-user (custom RHEL images)"
  default     = true
}

variable "cluster_network_create_timeout" {
  type        = string
  description = "Per-BM instance create timeout"
  default     = ""
}

variable "cluster_network_enable_autoscaling" {
  type        = bool
  description = "Enable OCI autoscaling configuration for the cluster-network memory instance pool."
  default     = false
}

variable "cluster_network_autoscaling_min_nodes" {
  type        = number
  description = "Minimum memory nodes for cluster-network autoscaling."
  default     = 1
}

variable "cluster_network_autoscaling_max_nodes" {
  type        = number
  description = "Maximum memory nodes for cluster-network autoscaling."
  default     = 8
}

variable "cluster_network_autoscaling_initial_nodes" {
  type        = number
  description = "Initial memory node count used by autoscaling policy capacity block."
  default     = 2
}

variable "cluster_network_autoscaling_cooldown_seconds" {
  type        = number
  description = "Cooldown period in seconds between autoscaling actions."
  default     = 300
}

variable "cluster_network_autoscaling_scale_out_threshold_percent" {
  type        = number
  description = "Scale-out threshold (%) for memory-pool CPU utilization."
  default     = 75
}

variable "cluster_network_autoscaling_scale_in_threshold_percent" {
  type        = number
  description = "Scale-in threshold (%) for memory-pool CPU utilization."
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

variable "create_bm_console_connections" {
  type        = bool
  description = "Create OCI instance console connections for each BM (serial/VNC over SSH tunnel)"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Freeform tags applied to major resources"
  default     = {}
}
