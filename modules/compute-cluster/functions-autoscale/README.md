# rdma-autoscale module

Terraform module for IAM + OCI Functions autoscaling for RDMA memory nodes.

## What this stack creates

- `oci_identity_dynamic_group` and `oci_identity_policy` for autoscaler permissions.
- Optional OCI Functions runtime:
  - `oci_functions_application`
  - `oci_functions_function`
- Optional alarm-driven trigger wiring:
  - `oci_monitoring_alarm`
  - `oci_ons_notification_topic`
  - `oci_ons_subscription` (ORACLE_FUNCTIONS endpoint)
- Optional Terraform-managed Docker build/push to OCIR during apply.

## What this stack does not create

- VCN/subnets/gateways/security lists
- Bastion or management VM
- BM control/memory nodes or compute cluster
- Any systemd timers/scripts on instances

Autoscale execution is OCI-native and function + alarm driven.

## Required variables

- `tenancy_ocid`
- `region`
- `compartment_ocid`

## Required when function autoscale is enabled

- `resource_manager_stack_id`
- `function_application_subnet_ids`
- `function_image_uri` (or enable image build and set `function_image_ocir_uri`)

## Recommended variables

- `management_instance_ocid` to scope autoscaler IAM to a single management instance where applicable.
- `resource_manager_stack_compartment_ocid` if the Resource Manager stack is in a different compartment.

## Core toggles

- `enable_memory_autoscale_iam` (default `true`)
- `enable_function_autoscale` (default `false`)
- `enable_function_alarm_trigger` (default `false`)

## Function behavior

The function evaluates memory utilization for nodes tagged:

- `node_pool = rdma-memory`
- `node_role = memory`

When the configured rule is met (`all_nodes`, `any_node`, or `average_nodes`), it submits an RM apply job to increment `memory_node_count`.

## Outputs

- `memory_autoscale_dynamic_group_ocid`
- `memory_autoscale_dynamic_group_name`
- `memory_autoscale_policy_ocid`
- `resource_manager_stack_compartment_ocid_effective`
- `function_autoscale_enabled`
- `function_autoscale_application_id`
- `function_autoscale_function_id`
- `function_autoscale_image_uri_effective`
- `function_alarm_trigger_enabled`
