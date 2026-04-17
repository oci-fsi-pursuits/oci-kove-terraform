output "cluster_id" {
  description = "OKE cluster OCID."
  value       = oci_containerengine_cluster.this.id
}

output "cluster_kubernetes_version" {
  description = "Kubernetes version used by the cluster."
  value       = oci_containerengine_cluster.this.kubernetes_version
}

output "node_pool_id" {
  description = "Worker node pool OCID."
  value       = oci_containerengine_node_pool.workers.id
}

output "worker_image_id" {
  description = "Worker image OCID used by the node pool."
  value       = local.worker_image_id_effective
}

output "kubeconfig_hint" {
  description = "OCI CLI command to merge kubeconfig."
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.this.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint ${var.public_control_plane_endpoint ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"}"
}
