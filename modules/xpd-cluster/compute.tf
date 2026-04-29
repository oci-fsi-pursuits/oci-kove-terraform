resource "oci_core_compute_cluster" "bm_compute" {
  count = local.use_compute_cluster_mode ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        length(trimspace(var.existing_vcn_id)) > 0 &&
        length(trimspace(var.existing_public_subnet_id)) > 0 &&
        length(trimspace(var.existing_private_subnet_id)) > 0
      )
      error_message = "existing_vcn_id, existing_public_subnet_id, and existing_private_subnet_id must be set (non-empty)."
    }
    precondition {
      condition     = local.use_compute_cluster_mode || !var.cluster_placement_group_enabled
      error_message = "cluster_placement_group_enabled is supported only when rdma_deployment_mode is compute_cluster."
    }
  }

  availability_domain = local.cluster_ad
  compartment_id      = var.compartment_ocid
  display_name        = local.compute_cluster_name
  freeform_tags       = local.common_tags
}

resource "oci_core_instance" "bm_nodes" {
  count      = local.use_compute_cluster_mode ? local.bm_total_count : 0
  depends_on = [oci_core_compute_cluster.bm_compute]

  availability_domain = local.cluster_ad
  compartment_id      = var.compartment_ocid
  display_name        = count.index == 0 ? "${local.name_prefix}-${local.compute_system_name}-control" : "${local.name_prefix}-${local.xpd_name}-${count.index}"
  shape               = var.bm_node_shape
  freeform_tags = merge(local.common_tags, {
    node_role  = count.index == 0 ? local.compute_system_name : local.xpd_name
    node_index = tostring(count.index)
    node_pool  = local.xpd_name
  })

  cluster_placement_group_id = var.cluster_placement_group_enabled ? oci_cluster_placement_groups_cluster_placement_group.bm_rdma[0].id : null

  capacity_reservation_id = trimspace(var.bm_capacity_reservation_id) != "" ? var.bm_capacity_reservation_id : null

  dynamic "platform_config" {
    for_each = var.bm_generic_platform_config ? [1] : []
    content {
      type                                           = "GENERIC_BM"
      is_symmetric_multi_threading_enabled           = var.bm_smt_enabled
      is_access_control_service_enabled              = false
      is_input_output_memory_management_unit_enabled = false
      are_virtual_instructions_enabled               = false
      numa_nodes_per_socket                          = var.bm_numa_nodes_per_socket
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

  metadata = merge(
    { ssh_authorized_keys = local.cluster_ssh_authorized_keys },
    local.bm_user_data_b64 != "" ? { user_data = local.bm_user_data_b64 } : {}
  )

  source_details {
    source_type             = "image"
    source_id               = var.bm_node_image_ocid
    boot_volume_size_in_gbs = var.bm_boot_volume_size_gbs
    boot_volume_vpus_per_gb = 30
  }

  compute_cluster_id = oci_core_compute_cluster.bm_compute[0].id

  create_vnic_details {
    subnet_id        = local.private_subnet_id
    assign_public_ip = false
    hostname_label   = count.index == 0 ? local.compute_system_hostname : (local.rdma_host_label_prefix != "" ? "${local.rdma_host_label_prefix}xpd${count.index}" : "xpd${count.index}")
  }

  timeouts {
    create = local.bm_instance_create_timeout
    update = "30m"
    delete = "30m"
  }
}

resource "oci_core_instance_configuration" "rdma_cluster_network" {
  count          = local.use_cluster_network_mode ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${local.name_prefix}-rdma-cluster-network-config"

  instance_details {
    instance_type = "compute"
    launch_details {
      availability_domain = local.cluster_ad
      compartment_id      = var.compartment_ocid
      display_name        = "${local.name_prefix}-${local.xpd_name}-node"
      shape               = var.bm_node_shape
      freeform_tags = merge(local.common_tags, {
        node_pool = local.xpd_name
        node_role = local.xpd_name
      })

      metadata = merge(
        { ssh_authorized_keys = local.cluster_ssh_authorized_keys },
        local.bm_user_data_b64 != "" ? { user_data = local.bm_user_data_b64 } : {}
      )

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

      dynamic "platform_config" {
        for_each = var.bm_generic_platform_config ? [1] : []
        content {
          type                                           = "GENERIC_BM"
          is_symmetric_multi_threading_enabled           = var.bm_smt_enabled
          is_access_control_service_enabled              = false
          is_input_output_memory_management_unit_enabled = false
          are_virtual_instructions_enabled               = false
          numa_nodes_per_socket                          = var.bm_numa_nodes_per_socket
          percentage_of_cores_enabled                    = 100
        }
      }

      source_details {
        source_type             = "image"
        image_id                = var.bm_node_image_ocid
        boot_volume_size_in_gbs = var.bm_boot_volume_size_gbs
        boot_volume_vpus_per_gb = 30
      }

      create_vnic_details {
        subnet_id        = local.private_subnet_id
        assign_public_ip = false
      }
    }
  }

  source = "NONE"
}

resource "oci_core_instance" "cluster_network_control" {
  count = local.use_cluster_network_mode ? 1 : 0

  availability_domain = local.cluster_ad
  compartment_id      = var.compartment_ocid
  display_name        = "${local.name_prefix}-${local.compute_system_name}-control"
  shape               = var.bm_node_shape
  freeform_tags = merge(local.common_tags, {
    node_role  = local.compute_system_name
    node_index = "0"
    node_pool  = local.xpd_name
  })

  capacity_reservation_id = trimspace(var.bm_capacity_reservation_id) != "" ? var.bm_capacity_reservation_id : null

  dynamic "platform_config" {
    for_each = var.bm_generic_platform_config ? [1] : []
    content {
      type                                           = "GENERIC_BM"
      is_symmetric_multi_threading_enabled           = var.bm_smt_enabled
      is_access_control_service_enabled              = false
      is_input_output_memory_management_unit_enabled = false
      are_virtual_instructions_enabled               = false
      numa_nodes_per_socket                          = var.bm_numa_nodes_per_socket
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

  metadata = merge(
    { ssh_authorized_keys = local.cluster_ssh_authorized_keys },
    local.bm_user_data_b64 != "" ? { user_data = local.bm_user_data_b64 } : {}
  )

  source_details {
    source_type             = "image"
    source_id               = var.bm_node_image_ocid
    boot_volume_size_in_gbs = var.bm_boot_volume_size_gbs
    boot_volume_vpus_per_gb = 30
  }

  create_vnic_details {
    subnet_id        = local.private_subnet_id
    assign_public_ip = false
    hostname_label   = local.compute_system_hostname
  }

  timeouts {
    create = local.bm_instance_create_timeout
    update = "30m"
    delete = "30m"
  }
}

resource "oci_core_cluster_network" "rdma" {
  count = local.use_cluster_network_mode ? 1 : 0

  lifecycle {
    precondition {
      condition     = !var.cluster_placement_group_enabled
      error_message = "cluster_placement_group_enabled is not supported when rdma_deployment_mode is cluster_network."
    }
  }

  compartment_id = var.compartment_ocid
  display_name   = "${local.name_prefix}-cluster-network"
  freeform_tags = merge(local.common_tags, {
    cluster_name = "${local.name_prefix}-cluster-network"
    node_pool    = local.xpd_name
  })

  instance_pools {
    instance_configuration_id = oci_core_instance_configuration.rdma_cluster_network[0].id
    size                      = var.memory_node_count
    display_name              = "${local.name_prefix}-${local.xpd_name}-pool"
  }

  placement_configuration {
    availability_domain = local.cluster_ad
    primary_subnet_id   = local.private_subnet_id
  }

  timeouts {
    create = local.bm_instance_create_timeout
  }
}

resource "oci_autoscaling_auto_scaling_configuration" "cluster_network_pool" {
  count = local.use_cluster_network_mode && var.cluster_network_enable_autoscaling ? 1 : 0

  compartment_id       = var.compartment_ocid
  display_name         = "${local.name_prefix}-cluster-network-autoscaling"
  is_enabled           = true
  cool_down_in_seconds = var.cluster_network_autoscaling_cooldown_seconds
  freeform_tags        = local.common_tags

  auto_scaling_resources {
    id   = oci_core_cluster_network.rdma[0].instance_pools[0].id
    type = "instancePool"
  }

  policies {
    policy_type  = "threshold"
    display_name = "${local.name_prefix}-cluster-network-threshold"
    is_enabled   = true

    capacity {
      initial = var.cluster_network_autoscaling_initial_nodes
      min     = var.cluster_network_autoscaling_min_nodes
      max     = var.cluster_network_autoscaling_max_nodes
    }

    rules {
      display_name = "scale-out-memory"

      metric {
        metric_type = "MEMORY_UTILIZATION"
        threshold {
          operator = "GT"
          value    = var.cluster_network_autoscaling_scale_out_threshold_percent
        }
      }

      action {
        type  = "CHANGE_COUNT_BY"
        value = var.cluster_network_autoscaling_scale_out_by
      }
    }

    rules {
      display_name = "scale-in-memory"

      metric {
        metric_type = "MEMORY_UTILIZATION"
        threshold {
          operator = "LT"
          value    = var.cluster_network_autoscaling_scale_in_threshold_percent
        }
      }

      action {
        type  = "CHANGE_COUNT_BY"
        value = -1 * var.cluster_network_autoscaling_scale_in_by
      }
    }
  }
}

resource "oci_core_instance_console_connection" "bm_console" {
  count = var.create_bm_console_connections && local.use_compute_cluster_mode ? local.bm_total_count : 0

  instance_id = oci_core_instance.bm_nodes[count.index].id
  public_key  = trimspace(var.ssh_public_key)
}
