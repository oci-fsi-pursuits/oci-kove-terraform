locals {
  base_tags = merge(
    {
      project     = var.namespace
      environment = var.environment
    },
    var.include_managed_by_tag ? { managed_by = "terraform" } : {},
    var.additional_tags,
  )

  # Single prefix for display_name fields.
  # If name_prefix_override is set, use it as-is.
  # Otherwise compose from namespace/environment and remove duplicates.
  name_prefix = trimspace(var.name_prefix_override) != "" ? trimspace(var.name_prefix_override) : join("-", distinct(compact([var.namespace, var.environment])))

  defined_tags = {
    for key, value in local.base_tags :
    "${var.defined_tag_namespace}.${key}" => value
  }
}
