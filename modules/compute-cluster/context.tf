# Naming + tags (`modules/labels`) and new VCN (`modules/networking`).
module "labels" {
  source = "../labels"

  namespace   = var.kove_namespace
  environment = var.kove_environment
  stack_name  = var.kove_stack_name

  additional_tags        = var.tags
  include_managed_by_tag = true
}

module "networking" {
  count  = var.use_existing_vcn ? 0 : 1
  source = "../networking"

  compartment_id                    = var.compartment_ocid
  vcn_cidr_block                    = var.vcn_cidr_block
  name_prefix                       = module.labels.name_prefix
  freeform_tags                     = module.labels.tags
  ssh_ingress_cidr                  = var.ssh_ingress_cidr
  public_ingress_hpc_ui_ports       = var.public_ingress_hpc_ui_ports
  private_subnet_ssh_sources_extras = var.private_subnet_ssh_sources_extras
}
