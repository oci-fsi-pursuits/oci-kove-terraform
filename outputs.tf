output "vcn_id" {
  value = module.rdma_platform.vcn_id
}

output "public_subnet_ocid" {
  value = module.rdma_platform.public_subnet_ocid
}

output "private_subnet_ocid" {
  value = module.rdma_platform.private_subnet_ocid
}

output "public_route_table_ocid" {
  value = module.rdma_platform.public_route_table_ocid
}

output "private_route_table_ocid" {
  value = module.rdma_platform.private_route_table_ocid
}

output "bastion_public_ip" {
  value = var.enable_bastion ? module.bastion[0].public_ip : null
}

output "compute_cluster_id" {
  value = module.rdma_platform.compute_cluster_id
}

output "cluster_network_id" {
  value = module.rdma_platform.cluster_network_id
}

output "cluster_placement_group_id" {
  value = module.rdma_platform.cluster_placement_group_id
}

output "bm_instance_ids" {
  value = module.rdma_platform.bm_instance_ids
}

output "bm_private_ips" {
  value = module.rdma_platform.bm_private_ips
}

output "bm_memory_private_ips" {
  value = module.rdma_platform.bm_memory_private_ips
}

output "cluster_network_instance_ids" {
  value = module.rdma_platform.cluster_network_instance_ids
}

output "cluster_network_instance_private_ips" {
  value = module.rdma_platform.cluster_network_instance_private_ips
}

output "cluster_ssh_private_key_openssh" {
  value     = module.rdma_platform.cluster_ssh_private_key_openssh
  sensitive = true
}

output "cluster_ssh_public_key_openssh" {
  value = module.rdma_platform.cluster_ssh_public_key_openssh
}

output "bm_console_vnc_connection_strings" {
  value     = module.rdma_platform.bm_console_vnc_connection_strings
  sensitive = true
}

output "oke_prerequisites" {
  value = module.rdma_platform.oke_prerequisites
}

output "existing_vcns_in_compartment" {
  value = module.rdma_platform.existing_vcns_in_compartment
}

output "availability_domain_used" {
  value = module.rdma_platform.availability_domain_used
}

output "mc_instance_id" {
  value = var.enable_mc_instance ? module.mc_instance[0].instance_id : null
}

output "mc_private_ip" {
  value = var.enable_mc_instance ? module.mc_instance[0].private_ip : null
}

output "mc_public_ip" {
  value = var.enable_mc_instance ? module.mc_instance[0].public_ip : null
}

output "compute_system_instance_id" {
  value = var.enable_compute_system ? module.compute_system[0].instance_id : null
}

output "compute_system_private_ip" {
  value = var.enable_compute_system ? module.compute_system[0].private_ip : null
}

output "mc_deployment_mode" {
  value = var.enable_mc_instance ? module.mc_instance[0].deployment_mode : null
}

output "mc_setup_script_path" {
  value = var.enable_mc_instance ? module.mc_instance[0].setup_script_path : null
}

output "mc_setup_script_run_command" {
  value = var.enable_mc_instance ? module.mc_instance[0].setup_script_run_command : null
}
