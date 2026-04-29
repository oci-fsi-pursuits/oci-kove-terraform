locals {
  # From module.labels: {namespace}-{environment}-{stack_name}
  name_prefix = module.labels.name_prefix

  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name

  host_label_prefix = length(trimspace(var.host_label_prefix)) > 0 ? substr(replace(replace(lower(trimspace(var.host_label_prefix)), "-", ""), "_", ""), 0, 12) : ""

  bastion_name            = "${local.name_prefix}-bastion"
  management_name         = "${local.name_prefix}-management"
  compute_cluster_name    = "${local.name_prefix}-compute-cluster"
  bm_name_prefix          = "${local.name_prefix}-bm"
  compute_system_name     = trimspace(var.compute_system_name)
  xpd_name                = trimspace(var.xpd_name)
  bastion_hostname        = local.host_label_prefix != "" ? "${local.host_label_prefix}bastion" : "bastion"
  management_hostname     = local.host_label_prefix != "" ? "${local.host_label_prefix}mgmt" : "mgmt"
  rdma_host_label_prefix  = local.host_label_prefix != "" ? substr(local.host_label_prefix, 0, 8) : ""
  compute_system_hostname = local.rdma_host_label_prefix != "" ? "${local.rdma_host_label_prefix}csys" : "compsys"

  vcn_id            = var.existing_vcn_id
  public_subnet_id  = var.existing_public_subnet_id
  private_subnet_id = var.existing_private_subnet_id

  private_subnet_ad = try(trimspace(data.oci_core_subnet.existing_private[0].availability_domain), "")
  public_subnet_ad  = try(trimspace(data.oci_core_subnet.existing_public[0].availability_domain), "")

  stack_ad = trimspace(var.availability_domain)

  cluster_ad = length(local.stack_ad) > 0 ? local.stack_ad : (
    length(local.private_subnet_ad) > 0 ? local.private_subnet_ad : (
      length(local.public_subnet_ad) > 0 ? local.public_subnet_ad : local.ad_name
    )
  )

  bm_instance_create_timeout = trimspace(var.cluster_network_create_timeout) != "" ? var.cluster_network_create_timeout : "2h"

  cluster_ssh_authorized_keys = join("\n", compact([
    trimspace(replace(var.ssh_public_key, "\r", "")),
    chomp(trimspace(replace(tls_private_key.cluster_ssh.public_key_openssh, "\r", ""))),
  ]))

  bm_total_count           = 1 + var.memory_node_count
  use_compute_cluster_mode = trimspace(var.rdma_deployment_mode) == "compute_cluster"
  use_cluster_network_mode = trimspace(var.rdma_deployment_mode) == "cluster_network"
  cluster_network_memory_instance_ids = local.use_cluster_network_mode ? [
    for instance in data.oci_core_cluster_network_instances.rdma[0].instances : instance["id"]
  ] : []
  cluster_network_memory_private_ips  = local.use_cluster_network_mode ? data.oci_core_instance.cluster_network_instances[*].private_ip : []
  cluster_network_control_instance_id = local.use_cluster_network_mode ? oci_core_instance.cluster_network_control[0].id : null
  cluster_network_control_private_ip  = local.use_cluster_network_mode ? oci_core_instance.cluster_network_control[0].private_ip : null
  cluster_network_instance_ids = local.use_cluster_network_mode ? concat(
    compact([local.cluster_network_control_instance_id]),
    local.cluster_network_memory_instance_ids,
  ) : []
  cluster_network_instance_private_ips = local.use_cluster_network_mode ? concat(
    compact([local.cluster_network_control_private_ip]),
    local.cluster_network_memory_private_ips,
  ) : []

  management_secondary_vnic_subnet_id_effective = trimspace(var.management_secondary_vnic_subnet_id) != "" ? trimspace(var.management_secondary_vnic_subnet_id) : local.private_subnet_id

  ol8_image_id = length(data.oci_core_images.ol8_flex.images) > 0 ? data.oci_core_images.ol8_flex.images[0].id : ""

  bastion_image_id    = trimspace(var.bastion_image_ocid) != "" ? var.bastion_image_ocid : local.ol8_image_id
  management_image_id = trimspace(var.management_image_ocid) != "" ? var.management_image_ocid : local.ol8_image_id

  common_tags = module.labels.tags

  # Management cloud-init: default stub in-repo, or your file (e.g. under Downloads) via management_cloud_init_template_path.
  management_cloud_init_src_path = trimspace(var.management_cloud_init_template_path) != "" ? var.management_cloud_init_template_path : "${path.module}/cloud_init/kove-xpd-cloud-init-standalone-runtime.txt"

  cloud_init_common_vars = merge(
    {
      rhsm_org_id                 = var.rhsm_org_id
      rhsm_activation_key         = var.rhsm_activation_key
      playbooks_zip_url           = var.playbooks_zip_url
      offline_repo_tarball_url    = var.offline_repo_tarball_url
      offline_repo_tarball_sha256 = var.offline_repo_tarball_sha256
      offline_base_rpm_packages   = var.offline_base_rpm_packages
      offline_rdma_rpm_packages   = var.offline_rdma_rpm_packages
      authorized_keys_b64         = base64encode(local.cluster_ssh_authorized_keys)
      imds_key_bootstrap          = tostring(var.bm_imds_ssh_key_bootstrap)
      rdma_use_oca_plugin         = tostring(var.use_compute_agent)
      primary_login_user          = "cloud-user"
      compartment_ocid            = var.compartment_ocid
      rdma_interface              = "eth2"
    },
    var.cloud_init_template_extra_vars,
  )

  bastion_cloud_init_vars = merge(local.cloud_init_common_vars, { node_role = "bastion" })
  management_cloud_init_vars = merge(local.cloud_init_common_vars, {
    node_role = "management"
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
