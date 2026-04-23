# rdma-platform module

Reusable module to deploy the RDMA platform infrastructure components on OCI.

## Components

- Optional VCN creation (or use existing VCN/subnets)
- Optional bastion VM in public subnet
- Management controller VM in private subnet
- RDMA node plane with:
  - 1 control node
  - N memory nodes (`memory_node_count`)
  - role naming:
    - `compute_system_name` (default `compute-system`) for control/orchestrator
    - `xpd_name` (default `xpd`) for memory nodes

## Deployment modes

- `compute_cluster` (default)
  - Creates `oci_core_compute_cluster`
  - Creates BM instances directly: 1 control + N memory nodes
- `cluster_network`
  - Creates a dedicated control BM instance
  - Creates a cluster network memory pool sized by `memory_node_count`

## Autoscaling status

Legacy management-node timer autoscaling in this module is deprecated and disabled.

Use `modules/rdma-autoscale` for OCI-native autoscaling:

- OCI Function runtime
- OCI Monitoring Alarm trigger
- OCI Notifications wiring
- IAM for function/resource principals

## Key input categories

- Core OCI identity and compartment settings
- Networking mode (`use_existing_vcn` and subnet IDs)
- Bastion and management VM shape/image options
- RDMA BM shape and image options
- RDMA deployment mode (`compute_cluster` or `cluster_network`)

## Outputs

Outputs include:

- network OCIDs
- bastion and management addresses
- control and memory node IDs/IPs
- compute cluster or cluster network identifiers
