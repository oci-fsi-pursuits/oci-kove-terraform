locals {
  resolved_bm_node_image_ocid = trimspace(var.bm_node_custom_image_ocid) != "" ? trimspace(var.bm_node_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  resolved_mc_image_ocid      = trimspace(var.mc_custom_image_ocid) != "" ? trimspace(var.mc_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  resolved_bastion_image_ocid = trimspace(var.bastion_custom_image_ocid) != "" ? trimspace(var.bastion_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  name_prefix                 = join("-", distinct(compact([var.kove_namespace, var.kove_environment])))
  defined_tags = var.enable_defined_tags ? {
    for key, value in merge(
      {
        project     = var.kove_namespace
        environment = var.kove_environment
        managed_by  = "terraform"
      },
      var.tags,
    ) :
    "${var.defined_tag_namespace}.${key}" => value
  } : {}
}
