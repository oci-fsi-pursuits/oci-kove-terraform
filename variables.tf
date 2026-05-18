# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID."
}

variable "region" {
  type        = string
  description = "OCI region, for example us-phoenix-1."
}

variable "identity_home_region" {
  type        = string
  description = "Home region for IAM create/update/delete operations."
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment for all resources."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for instance access."
}

variable "kove_namespace" {
  type        = string
  description = "Optional project prefix override for names and tags. Empty uses defined_tag_namespace."
  default     = ""
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

variable "bastion_name_prefix" {
  type        = string
  description = "Optional explicit display-name prefix for bastion resources. Empty uses composed labels prefix."
  default     = ""
}

variable "mc_name_prefix" {
  type        = string
  description = "Optional explicit display-name prefix for MC resources. Empty uses composed labels prefix."
  default     = ""
}

variable "compute_system_name_prefix" {
  type        = string
  description = "Optional explicit display-name prefix for compute-system resources. Empty uses composed labels prefix."
  default     = ""
}

variable "xpd_name_prefix" {
  type        = string
  description = "Optional explicit display-name prefix for xpd/RDMA platform resources. Empty uses composed labels prefix."
  default     = ""
}

variable "host_label_prefix" {
  type        = string
  description = "Optional DNS-safe prefix for instance hostname labels."
  default     = ""
}

variable "availability_domain" {
  type        = string
  description = "Single AD for MC, bastion, compute-system, and RDMA memory nodes. Empty uses subnet AD or first tenancy AD."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Extra defined tag values applied to major resources. Keys are created under defined_tag_namespace."
  default     = {}
}

variable "defined_tag_namespace" {
  type        = string
  description = "OCI defined tag namespace used for standard tags and, by default, the display-name prefix namespace."
  default     = "kove"

  validation {
    condition     = length(trimspace(var.defined_tag_namespace)) > 0
    error_message = "defined_tag_namespace must be non-empty."
  }
}

variable "enable_defined_tags" {
  type        = bool
  description = "Apply OCI defined tags to resources. Set false when the OCI tag namespace or keys have not been created yet."
  default     = true
}

# ---------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------
variable "rhel8_10_image_ocid" {
  type        = string
  description = "Shared base RHEL 8.10 image OCID used by MC, bastion, compute-system, and RDMA memory nodes unless an override is set."
}

variable "bm_node_custom_image_ocid" {
  type        = string
  description = "Optional image override for RDMA memory nodes and the compute-system BM. Empty uses rhel8_10_image_ocid."
  default     = ""
}

variable "mc_custom_image_ocid" {
  type        = string
  description = "Optional image override for the MC/management instance. Empty uses rhel8_10_image_ocid."
  default     = ""
}

variable "bastion_custom_image_ocid" {
  type        = string
  description = "Optional image override for the bastion. Empty uses rhel8_10_image_ocid."
  default     = ""
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "use_existing_vcn" {
  type        = bool
  description = "false creates a VCN with public and private subnets; true uses supplied subnet OCIDs."
  default     = false
}

variable "vcn_cidr_block" {
  type        = string
  description = "VCN CIDR when creating a new VCN."
  default     = "10.0.0.0/16"
}

variable "private_subnet_name_prefix" {
  type        = string
  description = "Optional prefix added to the private subnet display name when creating networking."
  default     = ""
}

variable "existing_vcn_id" {
  type        = string
  description = "Existing VCN OCID when use_existing_vcn is true."
  default     = ""
}

variable "existing_public_subnet_id" {
  type        = string
  description = "Public subnet OCID for the optional bastion when use_existing_vcn is true."
  default     = ""
}

variable "existing_private_subnet_id" {
  type        = string
  description = "Private subnet OCID for MC, compute-system, and RDMA memory nodes when use_existing_vcn is true."
  default     = ""
}

variable "private_subnet_ssh_sources_extras" {
  type        = string
  description = "Comma-separated CIDRs allowed SSH to private subnets in addition to the VCN CIDR when Terraform creates networking."
  default     = ""
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR allowed to SSH to the public subnet when Terraform creates networking."
  default     = "0.0.0.0/0"
}

variable "public_ingress_hpc_ui_ports" {
  type        = bool
  description = "When creating networking, allow TCP 3000 and 5000 from ssh_ingress_cidr on the public subnet."
  default     = true
}

variable "enable_ipv6" {
  type        = bool
  description = "Enable IPv6 assignment on compute-system and xpd VNICs."
  default     = true
}

# ---------------------------------------------------------------------------
# Bastion
# ---------------------------------------------------------------------------
variable "enable_bastion" {
  type        = bool
  description = "Create an optional jump host in the public subnet."
  default     = true
}

variable "bastion_shape" {
  type        = string
  description = "Bastion VM shape."
  default     = "VM.Standard.E6.Flex"
}

variable "bastion_ocpus" {
  type        = number
  description = "Bastion OCPUs."
  default     = 2
}

variable "bastion_memory_gbs" {
  type        = number
  description = "Bastion memory in GB."
  default     = 16
}

# ---------------------------------------------------------------------------
# MC / management instance
# ---------------------------------------------------------------------------
variable "enable_mc_instance" {
  type        = bool
  description = "Create the MC instance. This is the management VM for the deployment."
  default     = true
}

variable "mc_subnet_id" {
  type        = string
  description = "Optional subnet OCID for the MC instance. Empty uses the private subnet."
  default     = ""
}

variable "mc_availability_domain" {
  type        = string
  description = "Optional AD override for the MC instance."
  default     = ""
}

variable "mc_assign_public_ip" {
  type        = bool
  description = "Assign a public IP to the MC primary VNIC."
  default     = false
}

variable "mc_enable_kvm_automation" {
  type        = bool
  description = "Enable automated KVM/libvirt setup on the MC host via cloud-init. When false, use docs/mc-setup-manual-end-to-end.md."
  default     = false
}

variable "mc_shape" {
  type        = string
  description = "MC instance VM shape."
  default     = "VM.Standard3.Flex"
}

variable "mc_ocpus" {
  type        = number
  description = "MC instance OCPUs."
  default     = 3
}

variable "mc_memory_gbs" {
  type        = number
  description = "MC instance memory in GB."
  default     = 32
}

variable "mc_boot_volume_size_gbs" {
  type        = number
  description = "MC boot volume size in GB."
  default     = 200
}

variable "mc_deployment_mode" {
  type        = string
  description = "MC deployment mode: custom_image or cloud_init_setup."
  default     = "custom_image"

  validation {
    condition     = contains(["custom_image", "cloud_init_setup"], trimspace(var.mc_deployment_mode))
    error_message = "mc_deployment_mode must be custom_image or cloud_init_setup."
  }
}

variable "mc_cloud_init_template_path" {
  type        = string
  description = "Optional custom cloud-init template path for MC cloud_init_setup mode."
  default     = ""
}

variable "mc_offline_repo_tarball_url" {
  type        = string
  description = "Optional URL or absolute local path to a tar.gz containing a createrepo-generated RPM repository for MC offline cloud-init installs."
  default     = ""
  sensitive   = true
}

variable "mc_offline_repo_tarball_sha256" {
  type        = string
  description = "Optional SHA256 checksum for mc_offline_repo_tarball_url."
  default     = ""
}

variable "mc_offline_rpm_packages" {
  type        = string
  description = "Space-separated package names installed from the MC offline RPM repository when mc_offline_repo_tarball_url is set."
  default     = "python3 qemu-kvm libvirt-daemon-kvm libvirt libvirt-client virt-install qemu-img nftables tar"
}

variable "mc_instance_name_suffix" {
  type        = string
  description = "Display name suffix for the MC instance."
  default     = "mc-host"
}

variable "mc_hostname_label" {
  type        = string
  description = "Optional hostname label for the MC primary VNIC."
  default     = ""
}

variable "mc_setup_script_path" {
  type        = string
  description = "Path created on the MC instance for the post-cloud-init KVM setup helper script."
  default     = "/opt/kove/setup-kove-mc.sh"
}

variable "mc_guest_vm_name" {
  type        = string
  description = "Default KVM guest domain name used by the MC setup helper script."
  default     = "kove-mc"
}

variable "mc_guest_disk_path" {
  type        = string
  description = "Internal converted guest disk path used by the MC setup helper script."
  default     = "/var/lib/libvirt/images/kove-mc.img"
}

variable "mc_guest_memory_mb" {
  type        = number
  description = "Default guest memory in MB used by the MC setup helper script."
  default     = 8192
}

variable "mc_guest_vcpus" {
  type        = number
  description = "Default guest vCPU count used by the MC setup helper script."
  default     = 2
}

# ---------------------------------------------------------------------------
# RDMA memory nodes and optional compute-system BM
# ---------------------------------------------------------------------------
variable "enable_compute_system" {
  type        = bool
  description = "Create the optional single BM node labeled compute-system."
  default     = true
}

variable "compute_system_use_cluster_network_autoscaling" {
  type        = bool
  description = "Compatibility alias for compute_system_use_cluster_network. Prefer compute_system_use_cluster_network."
  default     = false
}

variable "compute_system_use_cluster_network" {
  type        = bool
  description = "When true, deploy compute-system as a dedicated cluster network (instance-pool based) instead of a single BM instance."
  default     = false
}

variable "compute_system_cluster_network_node_count" {
  type        = number
  description = "Desired node count for compute-system cluster-network mode."
  default     = 1
}

variable "compute_system_cluster_network_enable_autoscaling" {
  type        = bool
  description = "Enable autoscaling for compute-system cluster-network mode."
  default     = false
}

variable "compute_system_cluster_network_autoscaling_min_nodes" {
  type        = number
  description = "Minimum nodes for compute-system cluster-network autoscaling."
  default     = 1
}

variable "compute_system_cluster_network_autoscaling_max_nodes" {
  type        = number
  description = "Maximum nodes for compute-system cluster-network autoscaling."
  default     = 4
}

variable "compute_system_cluster_network_autoscaling_initial_nodes" {
  type        = number
  description = "Initial nodes for compute-system cluster-network autoscaling."
  default     = 1
}

variable "compute_system_cluster_network_autoscaling_cooldown_seconds" {
  type        = number
  description = "Cooldown seconds for compute-system cluster-network autoscaling."
  default     = 300
}

variable "compute_system_cluster_network_autoscaling_scale_out_threshold_percent" {
  type        = number
  description = "CPU utilization percent threshold for compute-system cluster-network scale-out."
  default     = 75
}

variable "compute_system_cluster_network_autoscaling_scale_in_threshold_percent" {
  type        = number
  description = "CPU utilization percent threshold for compute-system cluster-network scale-in."
  default     = 30
}

variable "compute_system_cluster_network_autoscaling_scale_out_by" {
  type        = number
  description = "Node increment for compute-system cluster-network scale-out action."
  default     = 1
}

variable "compute_system_cluster_network_autoscaling_scale_in_by" {
  type        = number
  description = "Node decrement for compute-system cluster-network scale-in action."
  default     = 1
}

variable "bm_node_shape" {
  type        = string
  description = "Bare metal shape for RDMA memory nodes and compute-system."
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

variable "bm_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB for BM nodes."
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

variable "compute_system_name" {
  type        = string
  description = "Role label for the optional compute-system BM."
  default     = "compute-system"
}

variable "xpd_name" {
  type        = string
  description = "Role label for RDMA memory node resources."
  default     = "xpd"
}

variable "bm_capacity_reservation_id" {
  type        = string
  description = "Optional capacity reservation OCID for BM nodes."
  default     = ""
}

variable "bm_generic_platform_config" {
  type        = bool
  description = "Enable GENERIC_BM platform_config for BM nodes."
  default     = false
}

variable "bm_smt_enabled" {
  type        = bool
  description = "Enable symmetric multithreading when generic BM platform config is used."
  default     = true
}

variable "bm_numa_nodes_per_socket" {
  type        = string
  description = "NUMA nodes per socket when generic BM platform config is used."
  default     = "NPS1"
}

variable "use_compute_agent" {
  type        = bool
  description = "Enable Oracle Cloud Agent HPC RDMA plugins on BM nodes."
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
  description = "Create OCI instance console connections for RDMA memory nodes."
  default     = false
}

variable "cluster_placement_group_enabled" {
  type        = bool
  description = "Create and assign a cluster placement group for compute_cluster BM nodes."
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

variable "cluster_network_enable_autoscaling" {
  type        = bool
  description = "Enable OCI autoscaling for cluster-network memory pool."
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
  description = "Number of nodes to add per scale-out action."
  default     = 1
}

variable "cluster_network_autoscaling_scale_in_by" {
  type        = number
  description = "Number of nodes to remove per scale-in action."
  default     = 1
}

# ---------------------------------------------------------------------------
# RDMA cloud-init and offline RPM inputs
# ---------------------------------------------------------------------------
variable "rhsm_org_id" {
  type        = string
  description = "RHSM organization ID injected into RDMA cloud-init. Leave empty if unused."
  default     = ""
  sensitive   = true
}

variable "rhsm_activation_key" {
  type        = string
  description = "RHSM activation key injected into RDMA cloud-init. Leave empty if unused."
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
  description = "Optional URL or absolute local path to a tar.gz containing a createrepo-generated RPM repository for RDMA/offline installs."
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
  description = "Space-separated base package names installed from the RDMA offline RPM repository when offline_repo_tarball_url is set."
  default     = "python3 jq unzip curl ansible-core"
}

variable "offline_rdma_rpm_packages" {
  type        = string
  description = "Space-separated RDMA package names installed from the RDMA offline RPM repository on BM nodes when offline_repo_tarball_url is set."
  default     = "rdma-core libibverbs infiniband-diags librdmacm-utils libibverbs-utils kove-oci-hpc-ansible"
}

variable "cloud_init_template_extra_vars" {
  type        = map(string)
  description = "Extra string placeholders merged into RDMA cloud-init templates."
  default     = {}
  sensitive   = true
}
