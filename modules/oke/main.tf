resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  kubernetes_version = local.k8s_version
  name               = "${var.name_prefix}-cluster"
  vcn_id             = var.vcn_id
  freeform_tags      = var.tags

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = var.public_control_plane_endpoint
    subnet_id            = var.endpoint_subnet_id
    nsg_ids              = []
  }

  options {
    service_lb_subnet_ids = [var.service_lb_subnet_id]

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }
}

resource "oci_containerengine_node_pool" "workers" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_id
  kubernetes_version = local.k8s_version
  name               = "${var.name_prefix}-workers"
  node_shape         = var.node_pool_shape
  freeform_tags      = var.tags

  dynamic "node_shape_config" {
    for_each = can(regex("Flex$", var.node_pool_shape)) ? [1] : []
    content {
      ocpus         = var.node_pool_ocpus
      memory_in_gbs = var.node_pool_memory_gbs
    }
  }

  node_source_details {
    image_id    = local.worker_image_id_effective
    source_type = "IMAGE"
  }

  node_config_details {
    placement_configs {
      availability_domain = var.availability_domain
      subnet_id           = var.worker_subnet_id
    }
    size = var.node_pool_size
  }

  ssh_public_key = trimspace(replace(var.ssh_public_key, "\r", ""))

  lifecycle {
    precondition {
      condition     = local.worker_image_id_effective != ""
      error_message = "No worker image was resolved. Set worker_image_id explicitly for your region/shape."
    }
  }
}
