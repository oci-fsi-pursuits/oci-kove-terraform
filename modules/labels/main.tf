locals {
  base_tags = merge(
    {
      project     = var.namespace
      environment = var.environment
    },
    var.include_managed_by_tag ? { managed_by = "terraform" } : {},
    var.additional_tags,
  )

  # Single prefix for display_name fields: kove-prod-rdma-ash
  name_prefix = join("-", compact([var.namespace, var.environment, var.stack_name]))
}
