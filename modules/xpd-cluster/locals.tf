locals {
  # From module.labels: {namespace}-{environment}
  name_prefix = module.labels.name_prefix

  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name

  host_label_prefix = length(trimspace(var.host_label_prefix)) > 0 ? substr(replace(replace(lower(trimspace(var.host_label_prefix)), "-", ""), "_", ""), 0, 12) : ""

  compute_cluster_name   = "${local.name_prefix}-compute-cluster"
  xpd_name               = trimspace(var.xpd_name)
  rdma_host_label_prefix = local.host_label_prefix != "" ? substr(local.host_label_prefix, 0, 8) : ""

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

  use_compute_cluster_mode = trimspace(var.rdma_deployment_mode) == "compute_cluster"
  use_cluster_network_mode = trimspace(var.rdma_deployment_mode) == "cluster_network"
  cluster_network_memory_instance_ids = local.use_cluster_network_mode ? [
    for instance in data.oci_core_cluster_network_instances.rdma[0].instances : instance["id"]
  ] : []
  cluster_network_memory_private_ips = local.use_cluster_network_mode ? data.oci_core_instance.cluster_network_instances[*].private_ip : []

  common_tags = module.labels.defined_tags

  cloud_init_src_path = "${path.module}/cloud_init/kove-xpd-cloud-init-standalone-runtime.txt"

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

  bm_cloud_init_vars = merge(local.cloud_init_common_vars, { node_role = "memory" })

  bm_user_data_rendered = replace(replace(
    templatefile(local.cloud_init_src_path, local.bm_cloud_init_vars),
    "\r\n", "\n"),
  "\r", "\n")

  bm_user_data_b64 = base64encode(local.bm_user_data_rendered)
}
