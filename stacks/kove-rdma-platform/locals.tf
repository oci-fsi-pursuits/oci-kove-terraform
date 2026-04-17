locals {
  # From module.kove_context: {namespace}-{environment}-{stack_name}
  name_prefix = module.kove_context.name_prefix

  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name

  host_label_prefix = length(trimspace(var.host_label_prefix)) > 0 ? substr(replace(replace(lower(trimspace(var.host_label_prefix)), "-", ""), "_", ""), 0, 12) : ""

  bastion_name         = "${local.name_prefix}-bastion"
  management_name      = "${local.name_prefix}-management"
  compute_cluster_name = "${local.name_prefix}-compute-cluster"
  bm_name_prefix       = "${local.name_prefix}-bm"
  bastion_hostname     = local.host_label_prefix != "" ? "${local.host_label_prefix}bastion" : "bastion"
  management_hostname  = local.host_label_prefix != "" ? "${local.host_label_prefix}mgmt" : "mgmt"

  vcn_id = var.use_existing_vcn ? var.existing_vcn_id : module.network_rdma_vcn[0].vcn_id

  public_subnet_id     = var.use_existing_vcn ? var.existing_public_subnet_id : module.network_rdma_vcn[0].public_subnet_id
  management_subnet_id = var.use_existing_vcn ? var.existing_management_subnet_id : module.network_rdma_vcn[0].management_subnet_id
  rdma_subnet_id       = var.use_existing_vcn ? var.existing_rdma_subnet_id : module.network_rdma_vcn[0].rdma_subnet_id

  rdma_subnet_ad   = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_rdma[0].availability_domain), "") : try(trimspace(module.network_rdma_vcn[0].rdma_subnet_availability_domain), "")
  mgmt_subnet_ad   = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_management[0].availability_domain), "") : try(trimspace(module.network_rdma_vcn[0].management_subnet_availability_domain), "")
  public_subnet_ad = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_public[0].availability_domain), "") : try(trimspace(module.network_rdma_vcn[0].public_subnet_availability_domain), "")

  stack_ad = trimspace(var.availability_domain)

  cluster_ad = length(local.stack_ad) > 0 ? local.stack_ad : (
    length(local.rdma_subnet_ad) > 0 ? local.rdma_subnet_ad : (
      length(local.mgmt_subnet_ad) > 0 ? local.mgmt_subnet_ad : (
        length(local.public_subnet_ad) > 0 ? local.public_subnet_ad : local.ad_name
      )
    )
  )

  bm_instance_create_timeout    = trimspace(var.cluster_network_create_timeout) != "" ? var.cluster_network_create_timeout : "2h"
  autoscale_rm_compartment_ocid = trimspace(var.resource_manager_stack_compartment_ocid) != "" ? trimspace(var.resource_manager_stack_compartment_ocid) : var.compartment_ocid

  cluster_ssh_authorized_keys = join("\n", compact([
    trimspace(replace(var.ssh_public_key, "\r", "")),
    chomp(trimspace(replace(tls_private_key.cluster_ssh.public_key_openssh, "\r", ""))),
  ]))

  bm_total_count = 1 + var.memory_node_count

  ol8_image_id = length(data.oci_core_images.ol8_flex.images) > 0 ? data.oci_core_images.ol8_flex.images[0].id : ""

  bastion_image_id    = trimspace(var.bastion_image_ocid) != "" ? var.bastion_image_ocid : local.ol8_image_id
  management_image_id = trimspace(var.management_image_ocid) != "" ? var.management_image_ocid : local.ol8_image_id

  common_tags = module.kove_context.tags

  # Management cloud-init: default stub in-repo, or your file (e.g. under Downloads) via management_cloud_init_template_path.
  management_cloud_init_src_path = trimspace(var.management_cloud_init_template_path) != "" ? var.management_cloud_init_template_path : "${path.module}/cloud_init/kove-rdma-cloud-init-standalone-runtime.txt"

  cloud_init_common_vars = merge(
    {
      rhsm_org_id                             = var.rhsm_org_id
      rhsm_activation_key                     = var.rhsm_activation_key
      playbooks_zip_url                       = var.playbooks_zip_url
      authorized_keys_b64                     = base64encode(local.cluster_ssh_authorized_keys)
      imds_key_bootstrap                      = tostring(var.bm_imds_ssh_key_bootstrap)
      rdma_use_oca_plugin                     = tostring(var.use_compute_agent)
      primary_login_user                      = "cloud-user"
      compartment_ocid                        = var.compartment_ocid
      rdma_interface                          = "eth2"
      enable_memory_autoscale                 = "false"
      memory_scale_threshold_percent          = "80"
      memory_scale_window_minutes             = "5"
      memory_scale_cooldown_minutes           = "20"
      memory_node_max_count                   = tostring(var.memory_node_max_count)
      memory_autoscale_check_interval_minutes = "5"
      resource_manager_stack_id               = ""
      resource_manager_stack_compartment      = local.autoscale_rm_compartment_ocid
      resource_manager_region                 = var.identity_home_region
      memory_autoscale_dry_run                = "false"
    },
    var.cloud_init_template_extra_vars,
  )

  bastion_cloud_init_vars = merge(local.cloud_init_common_vars, { node_role = "bastion" })
  management_cloud_init_vars = merge(local.cloud_init_common_vars, {
    node_role                               = "management"
    enable_memory_autoscale                 = tostring(var.enable_memory_autoscale)
    memory_scale_threshold_percent          = tostring(var.memory_scale_threshold_percent)
    memory_scale_window_minutes             = tostring(var.memory_scale_window_minutes)
    memory_scale_cooldown_minutes           = tostring(var.memory_scale_cooldown_minutes)
    memory_node_max_count                   = tostring(var.memory_node_max_count)
    memory_autoscale_check_interval_minutes = tostring(var.memory_autoscale_check_interval_minutes)
    resource_manager_stack_id               = var.resource_manager_stack_id
    resource_manager_stack_compartment      = local.autoscale_rm_compartment_ocid
    resource_manager_region                 = trimspace(var.resource_manager_region) != "" ? trimspace(var.resource_manager_region) : var.identity_home_region
    memory_autoscale_dry_run                = tostring(var.memory_autoscale_dry_run)
  })
  bm_cloud_init_vars = merge(local.cloud_init_common_vars, { node_role = "bm" })

  bastion_user_data_rendered = replace(replace(
    templatefile(local.management_cloud_init_src_path, local.bastion_cloud_init_vars),
    "\r\n", "\n"),
  "\r", "\n")

  management_user_data_rendered = replace(replace(
    templatefile(local.management_cloud_init_src_path, local.management_cloud_init_vars),
    "\r\n", "\n"),
  "\r", "\n")

  bm_user_data_rendered = replace(replace(
    templatefile(local.management_cloud_init_src_path, local.bm_cloud_init_vars),
    "\r\n", "\n"),
  "\r", "\n")

  bastion_user_data_b64    = base64encode(local.bastion_user_data_rendered)
  management_user_data_b64 = base64encode(local.management_user_data_rendered)
  bm_user_data_b64         = base64encode(local.bm_user_data_rendered)
}
