# Naming + tags (`modules/labels`).
module "labels" {
  source = "../labels"

  namespace   = var.kove_namespace
  environment = var.kove_environment
  stack_name  = var.kove_stack_name
  name_prefix_override = var.name_prefix_override

  additional_tags        = var.tags
  include_managed_by_tag = true
}
