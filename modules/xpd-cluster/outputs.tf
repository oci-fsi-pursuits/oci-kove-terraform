output "vcn_id" {
  description = "VCN OCID (created or existing)."
  value       = local.vcn_id
}

output "public_subnet_ocid" {
  description = "Public subnet (bastion)."
  value       = local.public_subnet_id
}

output "private_subnet_ocid" {
  description = "Private subnet for management and BM resources."
  value       = local.private_subnet_id
}

output "public_route_table_ocid" {
  description = "Public route table OCID provided by caller."
  value       = var.public_route_table_id
}

output "private_route_table_ocid" {
  description = "Private (NAT) route table OCID provided by caller."
  value       = var.private_route_table_id
}

output "bastion_public_ip" {
  description = "Public IP when enable_bastion is true; null otherwise."
  value       = var.enable_bastion ? oci_core_instance.bastion[0].public_ip : null
}

output "management_private_ip" {
  description = "Private IP of the management VM."
  value       = var.enable_management_instance ? oci_core_instance.management[0].private_ip : null
}

output "management_secondary_vnic_id" {
  description = "Secondary VNIC attachment OCID for management node when enabled; null otherwise."
  value       = var.enable_management_instance && var.management_secondary_vnic_enabled ? oci_core_vnic_attachment.management_secondary[0].id : null
}

output "compute_cluster_id" {
  description = "BM compute cluster OCID when rdma_deployment_mode is compute_cluster; null otherwise."
  value       = local.use_compute_cluster_mode ? oci_core_compute_cluster.bm_compute[0].id : null
}

output "cluster_network_id" {
  description = "RDMA cluster network OCID when rdma_deployment_mode is cluster_network; null otherwise."
  value       = local.use_cluster_network_mode ? oci_core_cluster_network.rdma[0].id : null
}

output "cluster_placement_group_id" {
  description = "Cluster Placement Group OCID when cluster_placement_group_enabled is true; null otherwise."
  value       = length(oci_cluster_placement_groups_cluster_placement_group.bm_rdma) > 0 ? oci_cluster_placement_groups_cluster_placement_group.bm_rdma[0].id : null
}

output "bm_instance_ids" {
  description = "BM OCIDs in order: index 0 = control, remaining = memory nodes."
  value       = local.use_compute_cluster_mode ? oci_core_instance.bm_nodes[*].id : local.cluster_network_instance_ids
}

output "bm_private_ips" {
  description = "Private IPs aligned with bm_instance_ids."
  value       = local.use_compute_cluster_mode ? oci_core_instance.bm_nodes[*].private_ip : local.cluster_network_instance_private_ips
}

output "bm_control_private_ip" {
  description = "Private IP of the single BM control node (index 0)."
  value       = local.use_compute_cluster_mode && length(oci_core_instance.bm_nodes) > 0 ? oci_core_instance.bm_nodes[0].private_ip : (length(local.cluster_network_instance_private_ips) > 0 ? local.cluster_network_instance_private_ips[0] : null)
}

output "bm_memory_private_ips" {
  description = "Private IPs of memory nodes only (excludes control)."
  value       = local.use_compute_cluster_mode ? slice(oci_core_instance.bm_nodes[*].private_ip, 1, length(oci_core_instance.bm_nodes)) : (length(local.cluster_network_instance_private_ips) > 1 ? slice(local.cluster_network_instance_private_ips, 1, length(local.cluster_network_instance_private_ips)) : [])
}

output "cluster_network_instance_ids" {
  description = "Cluster-network mode memory-pool instance IDs discovered from oci_core_cluster_network_instances."
  value       = local.cluster_network_memory_instance_ids
}

output "cluster_network_instance_private_ips" {
  description = "Cluster-network mode memory-pool private IPs discovered from oci_core_instance lookups."
  value       = local.cluster_network_memory_private_ips
}

output "cluster_ssh_private_key_openssh" {
  description = "Terraform-generated ED25519 private key (paired with metadata on instances). Use if your primary key is rejected by sshd."
  value       = tls_private_key.cluster_ssh.private_key_openssh
  sensitive   = true
}

output "cluster_ssh_public_key_openssh" {
  description = "Terraform-generated ED25519 public key."
  value       = tls_private_key.cluster_ssh.public_key_openssh
}

output "bm_console_vnc_connection_strings" {
  description = "Console VNC connection strings when create_bm_console_connections is true; same order as bm_instance_ids."
  value       = var.create_bm_console_connections && local.use_compute_cluster_mode ? oci_core_instance_console_connection.bm_console[*].vnc_connection_string : []
  sensitive   = true
}

output "oke_prerequisites" {
  description = "Subnet, route tables, and compartment references for consumers such as OKE modules."
  value = {
    compartment_ocid         = var.compartment_ocid
    tenancy_ocid             = var.tenancy_ocid
    region                   = var.region
    vcn_id                   = local.vcn_id
    public_subnet_ocid       = local.public_subnet_id
    private_subnet_ocid      = local.private_subnet_id
    public_route_table_ocid  = var.public_route_table_id
    private_route_table_ocid = var.private_route_table_id
    nsg_ocids                = []
  }
}

output "existing_vcns_in_compartment" {
  description = "Existing VCNs in the compartment grouped by display_name (display_name -> list of OCIDs)."
  value = {
    for vcn in data.oci_core_vcns.existing_vcns.virtual_networks :
    vcn.display_name => vcn.id...
  }
}

output "availability_domain_used" {
  description = "AD used for bastion, management VM, compute cluster, and BMs."
  value       = local.cluster_ad
}
