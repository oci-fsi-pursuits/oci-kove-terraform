# Naming + tags (`modules/labels`).
module "labels" {
  source = "../labels"

  namespace             = var.kove_namespace
  environment           = var.kove_environment
  name_prefix_override  = var.name_prefix_override
  defined_tag_namespace = var.defined_tag_namespace

  additional_tags        = var.tags
  include_managed_by_tag = true
}
