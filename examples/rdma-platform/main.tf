module "rdma_platform" {
  source = "../../modules/compute-cluster"

  tenancy_ocid         = var.tenancy_ocid
  region               = var.region
  compartment_ocid     = var.compartment_ocid
  ssh_public_key       = var.ssh_public_key
  bm_node_image_ocid   = var.bm_node_image_ocid
  rdma_deployment_mode = var.rdma_deployment_mode

  management_shape                     = var.management_shape
  management_ocpus                     = var.management_ocpus
  management_memory_gbs                = var.management_memory_gbs
  management_image_ocid                = var.management_image_ocid
  management_secondary_vnic_enabled    = var.management_secondary_vnic_enabled
  management_secondary_vnic_subnet_id  = var.management_secondary_vnic_subnet_id
  management_secondary_vnic_private_ip = var.management_secondary_vnic_private_ip

  kove_namespace   = var.kove_namespace
  kove_environment = var.kove_environment
  kove_stack_name  = var.kove_stack_name
}

output "vcn_id" {
  value = module.rdma_platform.vcn_id
}

output "rdma_subnet_ocid" {
  value = module.rdma_platform.rdma_subnet_ocid
}

output "compute_cluster_id" {
  value = module.rdma_platform.compute_cluster_id
}

output "cluster_network_id" {
  value = module.rdma_platform.cluster_network_id
}
