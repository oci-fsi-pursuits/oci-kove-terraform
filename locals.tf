locals {
  resolved_bm_node_image_ocid = trimspace(var.bm_node_custom_image_ocid) != "" ? trimspace(var.bm_node_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  resolved_mc_image_ocid      = trimspace(var.mc_custom_image_ocid) != "" ? trimspace(var.mc_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  resolved_bastion_image_ocid = trimspace(var.bastion_custom_image_ocid) != "" ? trimspace(var.bastion_custom_image_ocid) : trimspace(var.rhel8_10_image_ocid)
  defined_tag_namespace       = trimspace(var.defined_tag_namespace)
  kove_namespace              = trimspace(var.kove_namespace) != "" ? trimspace(var.kove_namespace) : local.defined_tag_namespace
  name_prefix                 = join("-", distinct(compact([local.kove_namespace, var.kove_environment])))
  defined_tags = var.enable_defined_tags ? {
    for key, value in merge(
      {
        project     = local.kove_namespace
        environment = var.kove_environment
        managed_by  = "terraform"
      },
      var.tags,
    ) :
    "${local.defined_tag_namespace}.${key}" => value
  } : {}
}
