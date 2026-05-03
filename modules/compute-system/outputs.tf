output "instance_id" {
  description = "Compute-system instance ID in single-BM mode, or first cluster-network instance ID when cluster mode is enabled."
  value = local.use_cluster_network_mode ? (
    length(data.oci_core_cluster_network_instances.compute_system[0].instances) > 0 ? data.oci_core_cluster_network_instances.compute_system[0].instances[0]["id"] : null
  ) : try(oci_core_instance.compute_system[0].id, null)
}

output "private_ip" {
  description = "Compute-system private IP in single-BM mode, or first cluster-network instance private IP when cluster mode is enabled."
  value = local.use_cluster_network_mode ? (
    length(values(data.oci_core_instance.cluster_network_instances)) > 0 ? values(data.oci_core_instance.cluster_network_instances)[0].private_ip : null
  ) : try(oci_core_instance.compute_system[0].private_ip, null)
}

output "cluster_network_id" {
  description = "Compute-system cluster network OCID when cluster-network mode is enabled; null otherwise."
  value       = local.use_cluster_network_mode ? oci_core_cluster_network.compute_system[0].id : null
}
