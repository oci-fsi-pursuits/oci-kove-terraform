module "labels" {
  source = "../labels"

  namespace             = var.kove_namespace
  environment           = var.kove_environment
  name_prefix_override  = var.name_prefix_override
  defined_tag_namespace = var.defined_tag_namespace
  enable_defined_tags   = var.enable_defined_tags

  additional_tags = merge(var.tags, {
    workload = "mc-host"
  })
}

resource "oci_core_instance" "mc_host" {
  lifecycle {
    precondition {
      condition     = local.deployment_mode == "custom_image" ? local.resolved_custom_image_id != "" : true
      error_message = "custom_image_ocid must be set when deployment_mode = custom_image."
    }

    precondition {
      condition     = local.deployment_mode == "cloud_init_setup" ? local.resolved_base_image_id != "" : true
      error_message = "Could not resolve base image for cloud_init_setup mode. Set base_image_ocid or ensure Oracle Linux 8 image exists for selected shape."
    }

    precondition {
      condition     = trimspace(var.cloud_init_template_path) == "" || fileexists(var.cloud_init_template_path)
      error_message = "cloud_init_template_path must be empty or point to an existing file."
    }

    precondition {
      condition     = !var.secondary_vnic_enabled || trimspace(var.secondary_vnic_subnet_id) != ""
      error_message = "secondary_vnic_subnet_id must be set when secondary_vnic_enabled = true."
    }
  }

  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_used
  display_name        = local.instance_display_name
  shape               = var.shape
  defined_tags        = module.labels.defined_tags

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = local.source_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
    boot_volume_vpus_per_gb = 30
  }

  metadata = merge(
    {
      ssh_authorized_keys = trimspace(replace(var.ssh_public_key, "\r", ""))
    },
    var.enable_kvm_automation ? { user_data = local.user_data_b64 } : {}
  )

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = local.hostname_label
  }
}

resource "oci_core_vnic_attachment" "mc_secondary" {
  count = var.secondary_vnic_enabled ? 1 : 0

  instance_id = oci_core_instance.mc_host.id

  create_vnic_details {
    subnet_id        = var.secondary_vnic_subnet_id
    assign_public_ip = false
    private_ip       = trimspace(var.secondary_vnic_private_ip) != "" ? trimspace(var.secondary_vnic_private_ip) : null
  }
}
