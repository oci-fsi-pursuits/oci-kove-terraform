output "instance_id" {
  description = "Bastion instance OCID."
  value       = oci_core_instance.bastion.id
}

output "private_ip" {
  description = "Bastion private IP."
  value       = oci_core_instance.bastion.private_ip
}

output "public_ip" {
  description = "Bastion public IP."
  value       = oci_core_instance.bastion.public_ip
}
