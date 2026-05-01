module "labels" {
  source = "../labels"

  namespace   = var.kove_namespace
  environment = var.kove_environment
  stack_name  = var.kove_stack_name
  name_prefix_override = var.name_prefix_override

  additional_tags = merge(var.tags, {
    workload = "compute-system"
  })
}

locals {
  use_compute_cluster_mode = trimspace(var.rdma_deployment_mode) == "compute_cluster"
  host_label_prefix        = length(trimspace(var.host_label_prefix)) > 0 ? substr(replace(replace(lower(trimspace(var.host_label_prefix)), "-", ""), "_", ""), 0, 12) : ""
  rdma_host_label_prefix   = local.host_label_prefix != "" ? substr(local.host_label_prefix, 0, 8) : ""
  hostname_label           = local.rdma_host_label_prefix != "" ? "${local.rdma_host_label_prefix}csys" : "compsys"
  instance_create_timeout  = trimspace(var.instance_create_timeout) != "" ? var.instance_create_timeout : "2h"
  compute_system_name      = trimspace(var.compute_system_name)
  cloud_init_src_path      = trimspace(var.cloud_init_template_path) != "" ? trimspace(var.cloud_init_template_path) : "${path.module}/../xpd-cluster/cloud_init/kove-xpd-cloud-init-standalone-runtime.txt"

  cloud_init_vars = merge(
    {
      rhsm_org_id                 = var.rhsm_org_id
      rhsm_activation_key         = var.rhsm_activation_key
      playbooks_zip_url           = var.playbooks_zip_url
      offline_repo_tarball_url    = var.offline_repo_tarball_url
      offline_repo_tarball_sha256 = var.offline_repo_tarball_sha256
      offline_base_rpm_packages   = var.offline_base_rpm_packages
      offline_rdma_rpm_packages   = var.offline_rdma_rpm_packages
      authorized_keys_b64         = base64encode(var.ssh_public_keys)
      imds_key_bootstrap          = tostring(var.bm_imds_ssh_key_bootstrap)
      rdma_use_oca_plugin         = tostring(var.use_compute_agent)
      primary_login_user          = "cloud-user"
      compartment_ocid            = var.compartment_ocid
      rdma_interface              = "eth2"
      node_role                   = "bm"
    },
    var.cloud_init_template_extra_vars,
  )

  user_data_rendered = replace(replace(
    templatefile(local.cloud_init_src_path, local.cloud_init_vars),
    "\r\n", "\n"),
  "\r", "\n")

  user_data_b64 = base64encode(local.user_data_rendered)
}

resource "oci_core_instance" "compute_system" {
  lifecycle {
    precondition {
      condition     = trimspace(var.image_ocid) != ""
      error_message = "image_ocid must be set for the compute-system BM."
    }

    precondition {
      condition     = !local.use_compute_cluster_mode || try(trimspace(var.compute_cluster_id), "") != ""
      error_message = "compute_cluster_id must be set when rdma_deployment_mode = compute_cluster."
    }

    precondition {
      condition     = trimspace(var.cloud_init_template_path) == "" || fileexists(var.cloud_init_template_path)
      error_message = "cloud_init_template_path must be empty or point to an existing file."
    }
  }

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${module.labels.name_prefix}-${local.compute_system_name}"
  shape               = var.shape
  freeform_tags = merge(module.labels.tags, {
    node_role  = local.compute_system_name
    node_index = "0"
    node_pool  = var.xpd_name
  })

  capacity_reservation_id = trimspace(var.capacity_reservation_id) != "" ? var.capacity_reservation_id : null
  compute_cluster_id      = local.use_compute_cluster_mode ? var.compute_cluster_id : null

  dynamic "platform_config" {
    for_each = var.generic_platform_config ? [1] : []
    content {
      type                                           = "GENERIC_BM"
      is_symmetric_multi_threading_enabled           = var.smt_enabled
      is_access_control_service_enabled              = false
      is_input_output_memory_management_unit_enabled = false
      are_virtual_instructions_enabled               = false
      numa_nodes_per_socket                          = var.numa_nodes_per_socket
      percentage_of_cores_enabled                    = 100
    }
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = !var.use_compute_agent
    is_monitoring_disabled   = false
    plugins_config {
      name          = "OS Management Service Agent"
      desired_state = "DISABLED"
    }
    dynamic "plugins_config" {
      for_each = var.use_compute_agent ? ["ENABLED"] : ["DISABLED"]
      content {
        name          = "Compute HPC RDMA Authentication"
        desired_state = plugins_config.value
      }
    }
    dynamic "plugins_config" {
      for_each = var.use_compute_agent ? ["ENABLED"] : ["DISABLED"]
      content {
        name          = "Compute HPC RDMA Auto-Configuration"
        desired_state = plugins_config.value
      }
    }
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_keys
    user_data           = local.user_data_b64
  }

  source_details {
    source_type             = "image"
    source_id               = trimspace(var.image_ocid)
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
    boot_volume_vpus_per_gb = 30
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = false
    hostname_label   = local.hostname_label
  }

  timeouts {
    create = local.instance_create_timeout
    update = "30m"
    delete = "30m"
  }
}
