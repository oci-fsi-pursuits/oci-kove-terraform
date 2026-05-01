locals {
  resolved_bm_node_image_ocid = trimspace(var.bm_node_custom_image_ocid) != "" ? trimspace(var.bm_node_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  resolved_mc_image_ocid      = trimspace(var.mc_custom_image_ocid) != "" ? trimspace(var.mc_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  resolved_bastion_image_ocid = trimspace(var.bastion_custom_image_ocid) != "" ? trimspace(var.bastion_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
}
