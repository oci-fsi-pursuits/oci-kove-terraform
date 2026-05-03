variable "namespace" {
  type        = string
  description = "Short project or product prefix for names and tags (e.g. kove)."
  default     = "kove"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.namespace))
    error_message = "namespace must be lowercase alphanumeric with hyphens, 1-31 chars."
  }
}

variable "environment" {
  type        = string
  description = "Deployment slice: dev, staging, prod, or a region/workload label."
  default     = "dev"

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must be non-empty."
  }
}

variable "stack_name" {
  type        = string
  description = "Logical stack identifier retained for compatibility. It is not included in default display name prefixes."
  default     = ""

  validation {
    condition     = trimspace(var.stack_name) == "" || can(regex("^[a-z][a-z0-9-]{0,40}$", var.stack_name))
    error_message = "stack_name must be empty or lowercase alphanumeric with hyphens, 1-41 chars."
  }
}

variable "name_prefix_override" {
  type        = string
  description = "Optional explicit name prefix override for display_name fields. Empty uses namespace/environment composition."
  default     = ""
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra defined tag keys merged after standard tags."
  default     = {}
}

variable "include_managed_by_tag" {
  type        = bool
  description = "Add managed_by = terraform to defined tags."
  default     = true
}

variable "defined_tag_namespace" {
  type        = string
  description = "OCI defined tag namespace used for standard tags. The namespace and tag keys must already exist in OCI."
  default     = "kove"
}

variable "enable_defined_tags" {
  type        = bool
  description = "Emit defined tags. Set false when the OCI tag namespace or keys have not been created yet."
  default     = true
}
