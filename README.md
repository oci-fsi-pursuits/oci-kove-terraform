# oci-kove-terraform

Terraform modules and stack wrappers for deploying a Kove RDMA shared-memory platform on Oracle Cloud Infrastructure (OCI).

## What this repo deploys

The RDMA platform deployment targets this topology:

- 1 RDMA controller node
- 2 memory nodes by default (`memory_node_count = 2`), with scale-out to `n+1`
- Optional bastion VM in a public subnet
- 1 management controller VM in a private subnet
- Dedicated RDMA private subnet for bare metal nodes

Management and bastion shapes can be configured as flex VMs, and custom image OCIDs are supported for both. Bare metal nodes use a required custom image (`bm_node_image_ocid`).

## Deployment options

| Option | Path | Notes |
|---|---|---|
| Networking only | `modules/networking` or `examples/minimal` + `modules/networking` | Creates VCN, subnets, routes, gateways, and security lists only. |
| Full RDMA platform on compute | `stacks/kove-rdma-platform` or `examples/rdma-platform` | Deploys bastion (optional), management VM, and RDMA nodes. |
| OKE deployment | `examples/oke` using `modules/oke` | Cloud-native OKE cluster path, separate from bare-metal RDMA node deployment. |
| Autoscale overlay (OCI Function + alarm) | `modules/compute-cluster/functions-autoscale` | Deploys IAM + function + alarm wiring for memory-node scale-out. |

## RDMA deployment modes

In `modules/compute-cluster` / `modules/cluster-network` and `stacks/kove-rdma-platform`:

- `rdma_deployment_mode = "compute_cluster"` (default)
  - Creates a compute cluster.
  - Creates 1 control BM plus `memory_node_count` memory BMs.
- `rdma_deployment_mode = "cluster_network"`
  - Creates 1 dedicated control BM.
  - Creates a cluster network memory pool sized by `memory_node_count`.

## Autoscaling behavior

Autoscaling is OCI-native and function-driven via `modules/compute-cluster/functions-autoscale`:

- Monitoring alarm evaluates memory metrics for tagged memory nodes.
- Notifications invoke OCI Function.
- Function submits RM apply job with `memory_node_count = current + 1` when thresholds are met.

Important:

- Legacy management-node/systemd autoscaling in the RDMA platform module is deprecated and disabled.
- Use `modules/compute-cluster/functions-autoscale` for active autoscaling runtime.

## Cloud-init behavior

Cloud-init templates in `modules/compute-cluster/cloud_init` and `modules/cluster-network/cloud_init` are used to:

- bootstrap SSH access on RHEL images
- optionally register RHSM credentials
- install RDMA packages and configure OCI RDMA plugins

## Repository layout

| Path | Purpose |
|---|---|
| `modules/` | Reusable Terraform modules (`labels`, `networking`, `oke`, `compute-cluster`, `cluster-network`). |
| `stacks/` | Opinionated deployment wrappers for OCI Resource Manager. |
| `examples/` | Runnable roots that demonstrate module usage. |
| `docs/` | Internal project documents such as QA tracking logs. |

## Quick start

### Full RDMA stack

1. Open `stacks/kove-rdma-platform/terraform.tfvars.example`.
2. Copy to `terraform.tfvars` and set required values.
3. Deploy:

```powershell
terraform init
terraform plan
terraform apply
```

### Autoscale overlay

Deploy `modules/compute-cluster/functions-autoscale` as a separate root to manage function + alarm autoscaling lifecycle.

## Requirements

- Terraform >= 1.3
- OCI provider >= 5.0

## License

Use the license policy defined by your organization or parent project.