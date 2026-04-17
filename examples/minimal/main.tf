# Minimal example: wire `kove-context` only (no OCI credentials required).
module "kove_context" {
  source = "../../modules/kove-context"

  namespace   = var.namespace
  environment = var.environment
  stack_name  = var.stack_name

  additional_tags        = var.additional_tags
  include_managed_by_tag = var.include_managed_by_tag
}

output "name_prefix" {
  value = module.kove_context.name_prefix
}

output "tags" {
  value = module.kove_context.tags
}
