output "namespace" {
  description = "Normalized namespace input."
  value       = var.namespace
}

output "environment" {
  description = "Environment label."
  value       = var.environment
}

output "stack_name" {
  description = "Stack identifier."
  value       = var.stack_name
}

output "name_prefix" {
  description = "Hyphenated prefix for OCI display_name fields."
  value       = local.name_prefix
}

output "tags" {
  description = "Merged freeform tags for oci_* resources."
  value       = local.base_tags
}
