output "instance_id" {
  description = "Compute-system BM instance OCID."
  value       = oci_core_instance.compute_system.id
}

output "private_ip" {
  description = "Compute-system BM private IP."
  value       = oci_core_instance.compute_system.private_ip
}
