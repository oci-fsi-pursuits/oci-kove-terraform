locals {
  autoscale_rm_compartment_ocid = trimspace(var.resource_manager_stack_compartment_ocid) != "" ? trimspace(var.resource_manager_stack_compartment_ocid) : var.compartment_ocid
  autoscale_dynamic_group_name  = "${replace(var.name_prefix, "_", "-")}-mem-autoscale-dg"
  autoscale_policy_name         = "${replace(var.name_prefix, "_", "-")}-mem-autoscale-policy"
  function_dynamic_group_name   = "${replace(var.name_prefix, "_", "-")}-mem-autoscale-fn-dg"
  function_policy_name          = "${replace(var.name_prefix, "_", "-")}-mem-autoscale-fn-policy"
  function_alarm_topic_name     = "${replace(var.name_prefix, "_", "-")}-mem-autoscale-topic"
  function_alarm_name           = "${replace(var.name_prefix, "_", "-")}-mem-autoscale-alarm"
  autoscale_matching_rule       = trimspace(var.management_instance_ocid) != "" ? "instance.id = '${trimspace(var.management_instance_ocid)}'" : "instance.compartment.id = '${var.compartment_ocid}'"
  function_matching_rule        = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_ocid}'}"

  function_image_effective = trimspace(var.function_image_uri) != "" ? trimspace(var.function_image_uri) : trimspace(var.function_image_ocir_uri)
  function_alarm_query     = trimspace(var.function_alarm_query_override) != "" ? trimspace(var.function_alarm_query_override) : "MemoryUtilization[${var.memory_scale_window_minutes}m]{node_pool = \"rdma-memory\", node_role = \"memory\"}.mean() > ${var.memory_scale_threshold_percent}"
}

resource "oci_identity_dynamic_group" "memory_autoscale" {
  provider       = oci.home
  count          = var.enable_memory_autoscale_iam ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = local.autoscale_dynamic_group_name
  description    = "Resource principal group for RDMA management-node autoscale timer."
  matching_rule  = local.autoscale_matching_rule
}

resource "oci_identity_policy" "memory_autoscale" {
  provider       = oci.home
  count          = var.enable_memory_autoscale_iam ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = local.autoscale_policy_name
  description    = "Permissions for RDMA management-node autoscale timer."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale[0].name} to read instances in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale[0].name} to read metrics in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale[0].name} to inspect orm-stacks in compartment id ${local.autoscale_rm_compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale[0].name} to manage orm-jobs in compartment id ${local.autoscale_rm_compartment_ocid}",
  ]
}

resource "oci_identity_dynamic_group" "memory_autoscale_function" {
  provider       = oci.home
  count          = var.enable_function_autoscale ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = local.function_dynamic_group_name
  description    = "Resource principal group for OCI Function autoscaler."
  matching_rule  = local.function_matching_rule
}

resource "oci_identity_policy" "memory_autoscale_function" {
  provider       = oci.home
  count          = var.enable_function_autoscale ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = local.function_policy_name
  description    = "Permissions for OCI Function autoscaler."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale_function[0].name} to read instances in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale_function[0].name} to read metrics in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale_function[0].name} to inspect orm-stacks in compartment id ${local.autoscale_rm_compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.memory_autoscale_function[0].name} to manage orm-jobs in compartment id ${local.autoscale_rm_compartment_ocid}",
  ]
}

resource "null_resource" "function_image_build" {
  count = var.enable_function_image_build ? 1 : 0

  triggers = {
    source_dir     = var.function_source_dir
    target_image   = var.function_image_ocir_uri
    ocir_registry  = var.ocir_registry
    ocir_username  = var.ocir_username
    auth_token_set = tostring(trimspace(var.ocir_auth_token) != "")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    environment = {
      SOURCE_DIR      = var.function_source_dir
      TARGET_IMAGE    = var.function_image_ocir_uri
      OCIR_REGISTRY   = var.ocir_registry
      OCIR_USERNAME   = var.ocir_username
      OCIR_AUTH_TOKEN = var.ocir_auth_token
    }
    command = <<-EOT
      $ErrorActionPreference = 'Stop'
      if (-not (Test-Path "$env:SOURCE_DIR")) { throw "Function source directory not found: $env:SOURCE_DIR" }
      $env:OCIR_AUTH_TOKEN | docker login "$env:OCIR_REGISTRY" --username "$env:OCIR_USERNAME" --password-stdin
      docker build -t "$env:TARGET_IMAGE" "$env:SOURCE_DIR"
      docker push "$env:TARGET_IMAGE"
    EOT
  }
}

resource "oci_functions_application" "memory_autoscale" {
  count          = var.enable_function_autoscale ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = var.function_application_name
  subnet_ids     = var.function_application_subnet_ids
  shape          = var.function_application_shape
}

resource "oci_functions_function" "memory_autoscale" {
  count              = var.enable_function_autoscale ? 1 : 0
  application_id     = oci_functions_application.memory_autoscale[0].id
  display_name       = var.function_name
  image              = local.function_image_effective
  memory_in_mbs      = var.function_memory_in_mbs
  timeout_in_seconds = var.function_timeout_in_seconds
  config = {
    COMPARTMENT_OCID                   = var.compartment_ocid
    RESOURCE_MANAGER_STACK_ID          = var.resource_manager_stack_id
    RESOURCE_MANAGER_STACK_COMPARTMENT = local.autoscale_rm_compartment_ocid
    RESOURCE_MANAGER_REGION            = trimspace(var.resource_manager_region) != "" ? trimspace(var.resource_manager_region) : var.region
    MEMORY_SCALE_THRESHOLD_PERCENT     = tostring(var.memory_scale_threshold_percent)
    MEMORY_SCALE_WINDOW_MINUTES        = tostring(var.memory_scale_window_minutes)
    MEMORY_SCALE_RULE                  = var.memory_scale_rule
    MEMORY_SCALE_COOLDOWN_MINUTES      = tostring(var.memory_scale_cooldown_minutes)
    MEMORY_NODE_MAX_COUNT              = tostring(var.memory_node_max_count)
    MEMORY_AUTOSCALE_DRY_RUN           = tostring(var.memory_autoscale_dry_run)
  }
  depends_on = [
    null_resource.function_image_build
  ]
}

resource "oci_ons_notification_topic" "function_autoscale" {
  count          = var.enable_function_autoscale && var.enable_function_alarm_trigger ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = local.function_alarm_topic_name
  description    = "Alarm topic that invokes RDMA autoscale function."
}

resource "oci_ons_subscription" "function_autoscale" {
  count          = var.enable_function_autoscale && var.enable_function_alarm_trigger ? 1 : 0
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.function_autoscale[0].id
  protocol       = "ORACLE_FUNCTIONS"
  endpoint       = oci_functions_function.memory_autoscale[0].id
}

resource "oci_monitoring_alarm" "function_autoscale" {
  count                 = var.enable_function_autoscale && var.enable_function_alarm_trigger ? 1 : 0
  compartment_id        = var.compartment_ocid
  display_name          = local.function_alarm_name
  metric_compartment_id = var.compartment_ocid
  namespace             = "oci_computeagent"
  query                 = local.function_alarm_query
  severity              = "CRITICAL"
  is_enabled            = true
  pending_duration      = var.function_alarm_pending_duration
  destinations          = [oci_ons_notification_topic.function_autoscale[0].id]
  message_format        = "PRETTY_JSON"
  body                  = "RDMA autoscale alarm fired."
}

