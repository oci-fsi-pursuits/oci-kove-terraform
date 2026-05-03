module "labels" {
  source = "../labels"

  namespace             = var.kove_namespace
  environment           = var.kove_environment
  name_prefix_override  = var.name_prefix_override
  defined_tag_namespace = var.defined_tag_namespace
  enable_defined_tags   = var.enable_defined_tags

  additional_tags = merge(var.tags, {
    workload = "bastion"
  })
}

locals {
  host_label_prefix = length(trimspace(var.host_label_prefix)) > 0 ? substr(replace(replace(lower(trimspace(var.host_label_prefix)), "-", ""), "_", ""), 0, 12) : ""
  hostname_label    = local.host_label_prefix != "" ? "${local.host_label_prefix}bastion" : "bastion"
}

resource "oci_core_instance" "bastion" {
  lifecycle {
    precondition {
      condition     = trimspace(var.image_ocid) != ""
      error_message = "image_ocid must be set for the bastion."
    }
  }

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "${module.labels.name_prefix}-bastion"
  shape               = var.shape
  defined_tags        = module.labels.defined_tags

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  agent_config {
    is_management_disabled = true
  }

  source_details {
    source_type = "image"
    source_id   = trimspace(var.image_ocid)
  }

  metadata = {
    ssh_authorized_keys = trimspace(replace(var.ssh_public_key, "\r", ""))
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = local.hostname_label
  }
}
