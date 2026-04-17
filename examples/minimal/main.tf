# Minimal example: wire `labels` only (no OCI credentials required).
module "labels" {
  source = "../../modules/labels"

  namespace   = "kove"
  environment = "dev"
  stack_name  = "example"

  additional_tags = {
    example = "minimal"
  }
}

output "name_prefix" {
  value = module.labels.name_prefix
}

output "tags" {
  value = module.labels.tags
}
