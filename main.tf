module "networking" {
  count  = var.use_existing_vcn ? 0 : 1
  source = "./modules/networking"

  compartment_id                    = var.compartment_ocid
  vcn_cidr_block                    = var.vcn_cidr_block
  private_subnet_name_prefix        = var.private_subnet_name_prefix
  name_prefix                       = local.name_prefix
  defined_tags                      = local.defined_tags
  ssh_ingress_cidr                  = var.ssh_ingress_cidr
  public_ingress_hpc_ui_ports       = var.public_ingress_hpc_ui_ports
  private_subnet_ssh_sources_extras = var.private_subnet_ssh_sources_extras
}

module "rdma_platform" {
  source = "./modules/xpd-cluster"

  tenancy_ocid         = var.tenancy_ocid
  region               = var.region
  identity_home_region = var.identity_home_region
  compartment_ocid     = var.compartment_ocid
  ssh_public_key       = var.ssh_public_key

  kove_namespace        = local.kove_namespace
  kove_environment      = var.kove_environment
  name_prefix_override  = var.xpd_name_prefix
  defined_tag_namespace = local.defined_tag_namespace
  enable_defined_tags   = var.enable_defined_tags
  host_label_prefix     = var.host_label_prefix
  availability_domain   = var.availability_domain

  use_existing_vcn = var.use_existing_vcn

  existing_vcn_id            = var.use_existing_vcn ? var.existing_vcn_id : module.networking[0].vcn_id
  existing_public_subnet_id  = var.use_existing_vcn ? var.existing_public_subnet_id : module.networking[0].public_subnet_id
  existing_private_subnet_id = var.use_existing_vcn ? var.existing_private_subnet_id : module.networking[0].private_subnet_id
  public_route_table_id      = var.use_existing_vcn ? "" : module.networking[0].public_route_table_id
  private_route_table_id     = var.use_existing_vcn ? "" : module.networking[0].private_route_table_id

  rhsm_org_id                    = var.rhsm_org_id
  rhsm_activation_key            = var.rhsm_activation_key
  playbooks_zip_url              = var.playbooks_zip_url
  offline_repo_tarball_url       = var.offline_repo_tarball_url
  offline_repo_tarball_sha256    = var.offline_repo_tarball_sha256
  offline_base_rpm_packages      = var.offline_base_rpm_packages
  offline_rdma_rpm_packages      = var.offline_rdma_rpm_packages
  cloud_init_template_extra_vars = var.cloud_init_template_extra_vars

  bm_node_shape                                           = var.bm_node_shape
  rdma_deployment_mode                                    = var.rdma_deployment_mode
  bm_node_image_ocid                                      = local.resolved_bm_node_image_ocid
  bm_boot_volume_size_gbs                                 = var.bm_boot_volume_size_gbs
  bm_capacity_reservation_id                              = var.bm_capacity_reservation_id
  bm_generic_platform_config                              = var.bm_generic_platform_config
  bm_smt_enabled                                          = var.bm_smt_enabled
  bm_numa_nodes_per_socket                                = var.bm_numa_nodes_per_socket
  use_compute_agent                                       = var.use_compute_agent
  bm_imds_ssh_key_bootstrap                               = var.bm_imds_ssh_key_bootstrap
  cluster_network_create_timeout                          = var.cluster_network_create_timeout
  cluster_network_enable_autoscaling                      = var.cluster_network_enable_autoscaling
  cluster_network_autoscaling_min_nodes                   = var.cluster_network_autoscaling_min_nodes
  cluster_network_autoscaling_max_nodes                   = var.cluster_network_autoscaling_max_nodes
  cluster_network_autoscaling_initial_nodes               = var.cluster_network_autoscaling_initial_nodes
  cluster_network_autoscaling_cooldown_seconds            = var.cluster_network_autoscaling_cooldown_seconds
  cluster_network_autoscaling_scale_out_threshold_percent = var.cluster_network_autoscaling_scale_out_threshold_percent
  cluster_network_autoscaling_scale_in_threshold_percent  = var.cluster_network_autoscaling_scale_in_threshold_percent
  cluster_network_autoscaling_scale_out_by                = var.cluster_network_autoscaling_scale_out_by
  cluster_network_autoscaling_scale_in_by                 = var.cluster_network_autoscaling_scale_in_by
  create_bm_console_connections                           = var.create_bm_console_connections

  cluster_placement_group_enabled     = var.cluster_placement_group_enabled
  cluster_placement_group_type        = var.cluster_placement_group_type
  cluster_placement_group_name        = var.cluster_placement_group_name
  cluster_placement_group_description = var.cluster_placement_group_description

  memory_node_count = var.memory_node_count
  xpd_name          = var.xpd_name

  tags = var.tags
}

module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./modules/bastion"

  tenancy_ocid        = var.tenancy_ocid
  compartment_ocid    = var.compartment_ocid
  subnet_id           = module.rdma_platform.public_subnet_ocid
  availability_domain = module.rdma_platform.availability_domain_used
  ssh_public_key      = var.ssh_public_key

  kove_namespace        = local.kove_namespace
  kove_environment      = var.kove_environment
  name_prefix_override  = var.bastion_name_prefix
  defined_tag_namespace = local.defined_tag_namespace
  enable_defined_tags   = var.enable_defined_tags
  host_label_prefix     = var.host_label_prefix
  tags                  = var.tags

  shape            = var.bastion_shape
  ocpus            = var.bastion_ocpus
  memory_gbs       = var.bastion_memory_gbs
  image_ocid       = local.resolved_bastion_image_ocid
  assign_public_ip = true
}

module "compute_system" {
  count  = var.enable_compute_system ? 1 : 0
  source = "./modules/compute-system"

  compartment_ocid    = var.compartment_ocid
  subnet_id           = module.rdma_platform.private_subnet_ocid
  availability_domain = module.rdma_platform.availability_domain_used
  ssh_public_keys     = module.rdma_platform.cluster_ssh_authorized_keys

  kove_namespace        = local.kove_namespace
  kove_environment      = var.kove_environment
  name_prefix_override  = var.compute_system_name_prefix
  defined_tag_namespace = local.defined_tag_namespace
  enable_defined_tags   = var.enable_defined_tags
  host_label_prefix     = var.host_label_prefix
  tags                  = var.tags

  rdma_deployment_mode                                    = var.rdma_deployment_mode
  enable_cluster_network_autoscaling_mode                 = var.compute_system_use_cluster_network || var.compute_system_use_cluster_network_autoscaling
  cluster_network_node_count                              = var.compute_system_cluster_network_node_count
  cluster_network_enable_autoscaling                      = var.compute_system_cluster_network_enable_autoscaling
  cluster_network_autoscaling_min_nodes                   = var.compute_system_cluster_network_autoscaling_min_nodes
  cluster_network_autoscaling_max_nodes                   = var.compute_system_cluster_network_autoscaling_max_nodes
  cluster_network_autoscaling_initial_nodes               = var.compute_system_cluster_network_autoscaling_initial_nodes
  cluster_network_autoscaling_cooldown_seconds            = var.compute_system_cluster_network_autoscaling_cooldown_seconds
  cluster_network_autoscaling_scale_out_threshold_percent = var.compute_system_cluster_network_autoscaling_scale_out_threshold_percent
  cluster_network_autoscaling_scale_in_threshold_percent  = var.compute_system_cluster_network_autoscaling_scale_in_threshold_percent
  cluster_network_autoscaling_scale_out_by                = var.compute_system_cluster_network_autoscaling_scale_out_by
  cluster_network_autoscaling_scale_in_by                 = var.compute_system_cluster_network_autoscaling_scale_in_by
  compute_cluster_id                                      = module.rdma_platform.compute_cluster_id
  compute_system_name                                     = var.compute_system_name
  xpd_name                                                = var.xpd_name
  image_ocid                                              = local.resolved_bm_node_image_ocid
  shape                                                   = var.bm_node_shape
  boot_volume_size_gbs                                    = var.bm_boot_volume_size_gbs
  capacity_reservation_id                                 = var.bm_capacity_reservation_id
  generic_platform_config                                 = var.bm_generic_platform_config
  smt_enabled                                             = var.bm_smt_enabled
  numa_nodes_per_socket                                   = var.bm_numa_nodes_per_socket
  use_compute_agent                                       = var.use_compute_agent
  instance_create_timeout                                 = var.cluster_network_create_timeout
  bm_imds_ssh_key_bootstrap                               = var.bm_imds_ssh_key_bootstrap
  rhsm_org_id                                             = var.rhsm_org_id
  rhsm_activation_key                                     = var.rhsm_activation_key
  playbooks_zip_url                                       = var.playbooks_zip_url
  offline_repo_tarball_url                                = var.offline_repo_tarball_url
  offline_repo_tarball_sha256                             = var.offline_repo_tarball_sha256
  offline_base_rpm_packages                               = var.offline_base_rpm_packages
  offline_rdma_rpm_packages                               = var.offline_rdma_rpm_packages
  cloud_init_template_extra_vars                          = var.cloud_init_template_extra_vars
}

module "mc_instance" {
  count  = var.enable_mc_instance ? 1 : 0
  source = "./modules/mc-instance"

  tenancy_ocid        = var.tenancy_ocid
  compartment_ocid    = var.compartment_ocid
  subnet_id           = trimspace(var.mc_subnet_id) != "" ? trimspace(var.mc_subnet_id) : module.rdma_platform.private_subnet_ocid
  availability_domain = trimspace(var.mc_availability_domain) != "" ? trimspace(var.mc_availability_domain) : module.rdma_platform.availability_domain_used
  ssh_public_key      = var.ssh_public_key

  kove_namespace        = local.kove_namespace
  kove_environment      = var.kove_environment
  name_prefix_override  = var.mc_name_prefix
  defined_tag_namespace = local.defined_tag_namespace
  enable_defined_tags   = var.enable_defined_tags
  tags                  = var.tags

  instance_name_suffix      = var.mc_instance_name_suffix
  hostname_label            = var.mc_hostname_label
  assign_public_ip          = var.mc_assign_public_ip
  secondary_vnic_enabled    = true
  secondary_vnic_subnet_id  = module.rdma_platform.private_subnet_ocid
  secondary_vnic_private_ip = ""
  secondary_vnic_interface  = "eth1"
  secondary_vnic_prefix     = "24"
  enable_kvm_automation     = var.mc_enable_kvm_automation

  shape                = var.mc_shape
  ocpus                = var.mc_ocpus
  memory_gbs           = var.mc_memory_gbs
  boot_volume_size_gbs = var.mc_boot_volume_size_gbs

  deployment_mode             = var.mc_deployment_mode
  custom_image_ocid           = local.resolved_mc_image_ocid
  base_image_ocid             = local.resolved_mc_image_ocid
  cloud_init_template_path    = var.mc_cloud_init_template_path
  offline_repo_tarball_url    = var.mc_offline_repo_tarball_url
  offline_repo_tarball_sha256 = var.mc_offline_repo_tarball_sha256
  offline_rpm_packages        = var.mc_offline_rpm_packages

  setup_script_path = var.mc_setup_script_path
  guest_vm_name     = var.mc_guest_vm_name
  guest_disk_path   = var.mc_guest_disk_path
  guest_memory_mb   = var.mc_guest_memory_mb
  guest_vcpus       = var.mc_guest_vcpus
}
