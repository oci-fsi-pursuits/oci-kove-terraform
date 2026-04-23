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

  memory_node_count   = var.memory_node_count
  compute_system_name = var.compute_system_name
  xpd_name            = var.xpd_name

  tags = var.tags
}

module "mc_instance" {
  count  = var.enable_mc_instance ? 1 : 0
  source = "../../modules/mc-instance"

  tenancy_ocid        = var.tenancy_ocid
  compartment_ocid    = var.compartment_ocid
  subnet_id           = trimspace(var.mc_subnet_id) != "" ? trimspace(var.mc_subnet_id) : module.rdma_platform.management_subnet_ocid
  availability_domain = trimspace(var.mc_availability_domain) != "" ? trimspace(var.mc_availability_domain) : module.rdma_platform.availability_domain_used
  ssh_public_key      = var.ssh_public_key

  kove_namespace   = var.kove_namespace
  kove_environment = var.kove_environment
  kove_stack_name  = var.kove_stack_name
  tags             = var.tags

  instance_name_suffix = var.mc_instance_name_suffix
  hostname_label       = var.mc_hostname_label
  assign_public_ip     = var.mc_assign_public_ip

  shape                = var.mc_shape
  ocpus                = var.mc_ocpus
  memory_gbs           = var.mc_memory_gbs
  boot_volume_size_gbs = var.mc_boot_volume_size_gbs

  deployment_mode          = var.mc_deployment_mode
  custom_image_ocid        = var.mc_custom_image_ocid
  base_image_ocid          = var.mc_base_image_ocid
  cloud_init_template_path = var.mc_cloud_init_template_path

  setup_script_path = var.mc_setup_script_path
  guest_vm_name     = var.mc_guest_vm_name
  guest_disk_path   = var.mc_guest_disk_path
  guest_memory_mb   = var.mc_guest_memory_mb
  guest_vcpus       = var.mc_guest_vcpus
}
