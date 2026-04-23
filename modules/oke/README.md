# oke

Creates an OKE cluster and one worker node pool.

This module expects networking inputs (VCN and subnets) to already exist. A common pattern is:

1. `modules/labels` for names and tags
2. `modules/networking` for VCN/subnets
3. `modules/oke` for cluster + workers

## Required inputs

- `compartment_id`
- `region`
- `name_prefix`
- `compute_system_name` (default `compute-system`)
- `xpd_name` (default `xpd`)
- `vcn_id`
- `endpoint_subnet_id`
- `service_lb_subnet_id`
- `worker_subnet_id`
- `ssh_public_key`
- `availability_domain`

## Outputs

- `cluster_id`
- `node_pool_id`
- `cluster_kubernetes_version`
- `worker_image_id`
- `kubeconfig_hint`
