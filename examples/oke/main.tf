provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}

module "labels" {
  source = "../../modules/labels"

  namespace   = var.namespace
  environment = var.environment
  stack_name  = var.stack_name
  additional_tags = merge(
    {
      example = "oke"
    },
    var.tags
  )
}

module "networking" {
  source = "../../modules/networking"

  compartment_id                    = var.compartment_ocid
  vcn_cidr_block                    = var.vcn_cidr_block
  name_prefix                       = module.labels.name_prefix
  freeform_tags                     = module.labels.tags
  ssh_ingress_cidr                  = "0.0.0.0/0"
  public_ingress_hpc_ui_ports       = false
  private_subnet_ssh_sources_extras = ""
}

module "oke" {
  source = "../../modules/oke"

  compartment_id       = var.compartment_ocid
  region               = var.region
  name_prefix          = module.labels.name_prefix
  vcn_id               = module.networking.vcn_id
  endpoint_subnet_id   = module.networking.public_subnet_id
  service_lb_subnet_id = module.networking.management_subnet_id
  worker_subnet_id     = module.networking.rdma_subnet_id
  ssh_public_key       = var.ssh_public_key
  availability_domain  = var.availability_domain
  tags                 = module.labels.tags
}

output "cluster_id" {
  value = module.oke.cluster_id
}

output "node_pool_id" {
  value = module.oke.node_pool_id
}

output "kubeconfig_hint" {
  value = module.oke.kubeconfig_hint
}
