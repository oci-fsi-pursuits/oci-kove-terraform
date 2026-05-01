output "vcn_id" {
  description = "VCN OCID (created or existing)."
  value       = local.vcn_id
}

output "public_subnet_ocid" {
  description = "Public subnet OCID provided by caller."
  value       = local.public_subnet_id
}

output "private_subnet_ocid" {
  description = "Private subnet for MC, compute-system, and RDMA memory resources."
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

output "compute_cluster_id" {
  description = "BM compute cluster OCID when rdma_deployment_mode is compute_cluster; used by the compute-system module."
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
  description = "RDMA memory-node BM OCIDs."
  value       = local.use_compute_cluster_mode ? oci_core_instance.bm_nodes[*].id : local.cluster_network_memory_instance_ids
}

output "bm_private_ips" {
  description = "RDMA memory-node private IPs aligned with bm_instance_ids."
  value       = local.use_compute_cluster_mode ? oci_core_instance.bm_nodes[*].private_ip : local.cluster_network_memory_private_ips
}

output "bm_memory_private_ips" {
  description = "RDMA memory-node private IPs."
  value       = local.use_compute_cluster_mode ? oci_core_instance.bm_nodes[*].private_ip : local.cluster_network_memory_private_ips
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
  description = "AD used for RDMA memory infrastructure."
  value       = local.cluster_ad
}

output "cluster_ssh_authorized_keys" {
  description = "Newline-separated SSH public keys injected into RDMA and compute-system BM metadata."
  value       = local.cluster_ssh_authorized_keys
}
