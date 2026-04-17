output "vcn_id" {
  value = module.rdma_platform.vcn_id
}

output "public_subnet_ocid" {
  value = module.rdma_platform.public_subnet_ocid
}

output "management_subnet_ocid" {
  value = module.rdma_platform.management_subnet_ocid
}

output "rdma_subnet_ocid" {
  value = module.rdma_platform.rdma_subnet_ocid
}

output "public_route_table_ocid" {
  value = module.rdma_platform.public_route_table_ocid
}

output "private_route_table_ocid" {
  value = module.rdma_platform.private_route_table_ocid
}

output "bastion_public_ip" {
  value = module.rdma_platform.bastion_public_ip
}

output "management_private_ip" {
  value = module.rdma_platform.management_private_ip
}

output "management_secondary_vnic_id" {
  value = module.rdma_platform.management_secondary_vnic_id
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

output "bm_control_private_ip" {
  value = module.rdma_platform.bm_control_private_ip
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

output "memory_autoscale_function_ocid" {
  value = module.rdma_platform.memory_autoscale_function_ocid
}

output "memory_autoscale_schedule_ocid" {
  value = module.rdma_platform.memory_autoscale_schedule_ocid
}

output "memory_autoscale_dynamic_group_ocid" {
  value = module.rdma_platform.memory_autoscale_dynamic_group_ocid
}
