# Naming + tags (modules/kove-context) and new VCN (modules/kove-oci-network-rdma-vcn).
module "kove_context" {
  source = "../../modules/kove-context"

  namespace   = var.kove_namespace
  environment = var.kove_environment
  stack_name  = var.kove_stack_name

  additional_tags        = var.tags
  include_managed_by_tag = true
}

module "network_rdma_vcn" {
  count  = var.use_existing_vcn ? 0 : 1
  source = "../../modules/kove-oci-network-rdma-vcn"

  compartment_id                    = var.compartment_ocid
  vcn_cidr_block                    = var.vcn_cidr_block
  name_prefix                       = module.kove_context.name_prefix
  freeform_tags                     = module.kove_context.tags
  ssh_ingress_cidr                  = var.ssh_ingress_cidr
  public_ingress_hpc_ui_ports       = var.public_ingress_hpc_ui_ports
  private_subnet_ssh_sources_extras = var.private_subnet_ssh_sources_extras
}
