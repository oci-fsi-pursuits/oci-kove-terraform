variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID."
}

variable "region" {
  type        = string
  description = "Primary OCI region for autoscale resources (for example eu-frankfurt-1)."
}

variable "identity_home_region" {
  type        = string
  description = "Tenancy home region for IAM create/update operations."
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment containing RDMA instances and metrics."
}

variable "name_prefix" {
  type        = string
  description = "Name prefix used to derive IAM and alarm resource names."
  default     = "kove-rdma"
}

variable "management_instance_ocid" {
  type        = string
  description = "Optional management instance OCID to scope autoscale IAM principal membership to one instance."
  default     = ""
}

variable "resource_manager_stack_compartment_ocid" {
  type        = string
  description = "Optional compartment OCID containing the Resource Manager stack. Empty defaults to compartment_ocid."
  default     = ""
}

variable "enable_memory_autoscale_iam" {
  type        = bool
  description = "When true, create autoscale IAM dynamic group and policy resources."
  default     = true
}

variable "resource_manager_stack_id" {
  type        = string
  description = "Resource Manager stack OCID targeted by autoscale apply jobs."
  default     = ""
}

variable "resource_manager_region" {
  type        = string
  description = "Region hosting the target Resource Manager stack. Empty defaults to region."
  default     = ""
}

variable "memory_scale_threshold_percent" {
  type        = number
  description = "Scale-out threshold (%) for memory utilization checks."
  default     = 80
}

variable "memory_scale_window_minutes" {
  type        = number
  description = "Metric lookback window in minutes."
  default     = 5
}

variable "memory_scale_rule" {
  type        = string
  description = "Scale decision rule: all_nodes, any_node, or average_nodes."
  default     = "all_nodes"

  validation {
    condition     = contains(["all_nodes", "any_node", "average_nodes"], var.memory_scale_rule)
    error_message = "memory_scale_rule must be one of: all_nodes, any_node, average_nodes."
  }
}

variable "memory_scale_cooldown_minutes" {
  type        = number
  description = "Minimum cooldown (minutes) between successful scale-out actions."
  default     = 20
}

variable "memory_node_max_count" {
  type        = number
  description = "Maximum allowed memory node count for autoscaling."
  default     = 8
}

variable "memory_autoscale_dry_run" {
  type        = bool
  description = "When true, evaluates conditions but does not submit Resource Manager apply jobs."
  default     = false
}

variable "enable_function_autoscale" {
  type        = bool
  description = "When true, deploy OCI Functions resources for autoscaling."
  default     = false

  validation {
    condition     = !var.enable_function_autoscale || length(var.function_application_subnet_ids) > 0
    error_message = "When enable_function_autoscale is true, set at least one function_application_subnet_ids value."
  }

  validation {
    condition = !var.enable_function_autoscale || (
      trimspace(var.function_image_uri) != "" ||
      (var.enable_function_image_build && trimspace(var.function_image_ocir_uri) != "")
    )
    error_message = "When enable_function_autoscale is true, set function_image_uri, or enable function image build with function_image_ocir_uri."
  }

  validation {
    condition     = !var.enable_function_autoscale || trimspace(var.resource_manager_stack_id) != ""
    error_message = "When enable_function_autoscale is true, set resource_manager_stack_id."
  }
}

variable "function_application_name" {
  type        = string
  description = "Display name for the OCI Functions application."
  default     = "rdma-memory-autoscale-app"
}

variable "function_name" {
  type        = string
  description = "Display name for the OCI Function."
  default     = "rdma-memory-autoscale"
}

variable "function_application_subnet_ids" {
  type        = list(string)
  description = "Private subnet OCIDs for the Functions application."
  default     = []
}

variable "function_image_uri" {
  type        = string
  description = "Pre-published function image URI (for example iad.ocir.io/namespace/repo:tag)."
  default     = ""
}

variable "function_image_ocir_uri" {
  type        = string
  description = "Target OCIR image URI used when Terraform builds and pushes the function image."
  default     = ""
}

variable "function_memory_in_mbs" {
  type        = number
  description = "OCI Function memory allocation."
  default     = 512
}

variable "function_timeout_in_seconds" {
  type        = number
  description = "OCI Function timeout."
  default     = 120
}

variable "function_application_shape" {
  type        = string
  description = "Functions application shape type (for example GENERIC_X86 or GENERIC_ARM)."
  default     = "GENERIC_X86"
}

variable "enable_function_alarm_trigger" {
  type        = bool
  description = "When true, create Monitoring Alarm + Notifications wiring to invoke the autoscale function."
  default     = false

  validation {
    condition     = !var.enable_function_alarm_trigger || var.enable_function_autoscale
    error_message = "enable_function_alarm_trigger requires enable_function_autoscale = true."
  }
}

variable "function_alarm_query_override" {
  type        = string
  description = "Optional custom MQL query for alarm trigger. Empty uses the default MemoryUtilization query."
  default     = ""
}

variable "function_alarm_pending_duration" {
  type        = string
  description = "Alarm pending duration (ISO-8601), for example PT5M."
  default     = "PT5M"
}

variable "enable_function_image_build" {
  type        = bool
  description = "When true, build the function container from source and push to OCIR during terraform apply."
  default     = false

  validation {
    condition     = !var.enable_function_image_build || (trimspace(var.function_source_dir) != "" && trimspace(var.function_image_ocir_uri) != "" && trimspace(var.ocir_registry) != "" && trimspace(var.ocir_username) != "" && trimspace(var.ocir_auth_token) != "")
    error_message = "When enable_function_image_build is true, set function_source_dir, function_image_ocir_uri, ocir_registry, ocir_username, and ocir_auth_token."
  }
}

variable "function_source_dir" {
  type        = string
  description = "Path to local function source directory containing Dockerfile and handler code."
  default     = "function"
}

variable "ocir_registry" {
  type        = string
  description = "OCIR registry host (for example iad.ocir.io)."
  default     = ""
}

variable "ocir_username" {
  type        = string
  description = "OCIR username (for example <namespace>/<user> or <namespace>/oracleidentitycloudservice/<email>)."
  default     = ""
}

variable "ocir_auth_token" {
  type        = string
  description = "OCIR auth token for docker login."
  default     = ""
  sensitive   = true
}
