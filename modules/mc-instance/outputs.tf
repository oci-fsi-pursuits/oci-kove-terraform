output "instance_id" {
  description = "MC host instance OCID."
  value       = oci_core_instance.mc_host.id
}

output "display_name" {
  description = "MC host display name."
  value       = oci_core_instance.mc_host.display_name
}

output "private_ip" {
  description = "MC host private IP."
  value       = oci_core_instance.mc_host.private_ip
}

output "public_ip" {
  description = "MC host public IP when assign_public_ip is true."
  value       = oci_core_instance.mc_host.public_ip
}

output "availability_domain_used" {
  description = "AD used by MC host."
  value       = local.ad_used
}

output "deployment_mode" {
  description = "Selected deployment mode."
  value       = local.deployment_mode
}

output "setup_script_path" {
  description = "Helper script path on MC host for manual KVM guest setup (cloud_init_setup mode)."
  value       = local.deployment_mode == "cloud_init_setup" ? var.setup_script_path : null
}

output "setup_script_run_command" {
  description = "Command to run on MC host after you manually copy/convert the OVA into qcow2."
  value       = local.deployment_mode == "cloud_init_setup" ? format("sudo %s %s %s %d %d", var.setup_script_path, var.guest_vm_name, var.guest_disk_path, var.guest_vcpus, var.guest_memory_mb) : null
}
