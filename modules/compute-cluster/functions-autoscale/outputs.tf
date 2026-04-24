output "memory_autoscale_dynamic_group_ocid" {
  description = "Dynamic group OCID for the autoscale principal."
  value       = var.enable_memory_autoscale_iam ? oci_identity_dynamic_group.memory_autoscale[0].id : null
}

output "memory_autoscale_dynamic_group_name" {
  description = "Dynamic group name for the autoscaler principal."
  value       = var.enable_memory_autoscale_iam ? oci_identity_dynamic_group.memory_autoscale[0].name : null
}

output "memory_autoscale_policy_ocid" {
  description = "IAM policy OCID granting autoscale permissions."
  value       = var.enable_memory_autoscale_iam ? oci_identity_policy.memory_autoscale[0].id : null
}

output "resource_manager_stack_compartment_ocid_effective" {
  description = "Effective compartment OCID used for Resource Manager stack/job IAM statements."
  value       = local.autoscale_rm_compartment_ocid
}

output "function_autoscale_enabled" {
  description = "Whether OCI Functions autoscale resources are enabled."
  value       = var.enable_function_autoscale
}

output "function_autoscale_application_id" {
  description = "OCI Functions application OCID for autoscaling."
  value       = var.enable_function_autoscale ? oci_functions_application.memory_autoscale[0].id : null
}

output "function_autoscale_function_id" {
  description = "OCI Function OCID for autoscaling."
  value       = var.enable_function_autoscale ? oci_functions_function.memory_autoscale[0].id : null
}

output "function_autoscale_image_uri_effective" {
  description = "Function container image URI used for deployment."
  value       = var.enable_function_autoscale ? local.function_image_effective : null
}

output "function_alarm_trigger_enabled" {
  description = "Whether alarm-driven function invocation is enabled."
  value       = var.enable_function_autoscale && var.enable_function_alarm_trigger
}
