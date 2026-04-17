module "rdma_platform" {
  source = "../../modules/rdma-platform"

  tenancy_ocid         = var.tenancy_ocid
  region               = var.region
  identity_home_region = var.identity_home_region
  compartment_ocid     = var.compartment_ocid
  ssh_public_key       = var.ssh_public_key

  kove_namespace      = var.kove_namespace
  kove_environment    = var.kove_environment
  kove_stack_name     = var.kove_stack_name
  host_label_prefix   = var.host_label_prefix
  availability_domain = var.availability_domain

  use_existing_vcn                  = var.use_existing_vcn
  vcn_cidr_block                    = var.vcn_cidr_block
  existing_vcn_id                   = var.existing_vcn_id
  existing_public_subnet_id         = var.existing_public_subnet_id
  existing_management_subnet_id     = var.existing_management_subnet_id
  existing_rdma_subnet_id           = var.existing_rdma_subnet_id
  private_subnet_ssh_sources_extras = var.private_subnet_ssh_sources_extras
  ssh_ingress_cidr                  = var.ssh_ingress_cidr
  public_ingress_hpc_ui_ports       = var.public_ingress_hpc_ui_ports

  enable_bastion     = var.enable_bastion
  bastion_shape      = var.bastion_shape
  bastion_ocpus      = var.bastion_ocpus
  bastion_memory_gbs = var.bastion_memory_gbs
  bastion_image_ocid = var.bastion_image_ocid

  management_shape                     = var.management_shape
  management_ocpus                     = var.management_ocpus
  management_memory_gbs                = var.management_memory_gbs
  management_image_ocid                = var.management_image_ocid
  management_secondary_vnic_enabled    = var.management_secondary_vnic_enabled
  management_secondary_vnic_subnet_id  = var.management_secondary_vnic_subnet_id
  management_secondary_vnic_private_ip = var.management_secondary_vnic_private_ip
  management_cloud_init_template_path  = var.management_cloud_init_template_path

  rhsm_org_id                    = var.rhsm_org_id
  rhsm_activation_key            = var.rhsm_activation_key
  playbooks_zip_url              = var.playbooks_zip_url
  cloud_init_template_extra_vars = var.cloud_init_template_extra_vars

  bm_node_shape                  = var.bm_node_shape
  rdma_deployment_mode           = var.rdma_deployment_mode
  bm_node_image_ocid             = var.bm_node_image_ocid
  bm_boot_volume_size_gbs        = var.bm_boot_volume_size_gbs
  bm_capacity_reservation_id     = var.bm_capacity_reservation_id
  bm_generic_platform_config     = var.bm_generic_platform_config
  bm_smt_enabled                 = var.bm_smt_enabled
  bm_numa_nodes_per_socket       = var.bm_numa_nodes_per_socket
  use_compute_agent              = var.use_compute_agent
  bm_imds_ssh_key_bootstrap      = var.bm_imds_ssh_key_bootstrap
  cluster_network_create_timeout = var.cluster_network_create_timeout
  create_bm_console_connections  = var.create_bm_console_connections

  cluster_placement_group_enabled     = var.cluster_placement_group_enabled
  cluster_placement_group_type        = var.cluster_placement_group_type
  cluster_placement_group_name        = var.cluster_placement_group_name
  cluster_placement_group_description = var.cluster_placement_group_description

  memory_node_count                       = var.memory_node_count
  enable_memory_autoscale                 = var.enable_memory_autoscale
  memory_scale_threshold_percent          = var.memory_scale_threshold_percent
  memory_scale_window_minutes             = var.memory_scale_window_minutes
  memory_scale_cooldown_minutes           = var.memory_scale_cooldown_minutes
  memory_node_max_count                   = var.memory_node_max_count
  memory_autoscale_check_interval_minutes = var.memory_autoscale_check_interval_minutes
  resource_manager_stack_id               = var.resource_manager_stack_id
  resource_manager_stack_compartment_ocid = var.resource_manager_stack_compartment_ocid
  resource_manager_region                 = var.resource_manager_region
  memory_autoscale_dry_run                = var.memory_autoscale_dry_run

  tags = var.tags
}
