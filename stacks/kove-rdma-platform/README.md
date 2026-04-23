# kove-rdma-platform stack

Stack wrapper for deploying `modules/rdma-platform` through OCI Resource Manager or Terraform CLI.
Optionally deploys a separate MC host VM via `modules/mc-instance`.

## What it wires

- passes stack variables into `modules/rdma-platform`
- optionally creates a dedicated MC host (`VM.Standard3.Flex`, 3 OCPU, 32 GB default)
- exposes outputs for networking, management access, and RDMA node addresses
- includes Resource Manager schema for guided variable entry

## Primary use cases

- deploy the full RDMA platform in one stack
- deploy RDMA + optional MC host in one stack while keeping MC lifecycle separate
- use existing VCN/subnets or create networking during deployment
- choose RDMA mode:
  - `compute_cluster` for direct BM instances in a compute cluster
  - `cluster_network` for dedicated control plus cluster network memory pool
- role naming:
  - `compute_system_name` labels the RDMA control/orchestrator node display names
  - `xpd_name` labels RDMA memory-node display names
- choose MC mode (when `enable_mc_instance = true`):
  - `custom_image`: launch MC host from your custom image (cloud-init still applied)
  - `cloud_init_setup`: install KVM/libvirt and drop `/opt/kove/setup-kove-mc.sh` for manual post-copy OVA setup

## Autoscaling notes

This stack no longer enables management-node/systemd autoscaling.
Use `modules/rdma-autoscale` for function + alarm autoscaling.

## Typical flow

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Set required OCIDs, SSH key, and `bm_node_image_ocid`.
3. Run Terraform:

```powershell
terraform init
terraform plan
terraform apply
```
