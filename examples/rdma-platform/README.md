# Example: RDMA platform deployment

This example wraps `stacks/kove-rdma-platform` so deployments can run from `examples/`.

## Run

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Fill OCI IDs, SSH key, and `bm_node_image_ocid`.
3. Run:

```powershell
terraform init
terraform plan
terraform apply
```

For advanced controls (autoscaling, placement group, existing VCN wiring), pass additional variables supported by `stacks/kove-rdma-platform`.

Notable options:

- `rdma_deployment_mode = "compute_cluster"` (default) or `"cluster_network"`
- `management_shape`, `management_ocpus`, `management_memory_gbs`, `management_image_ocid`
- `management_secondary_vnic_enabled` with optional subnet/IP overrides
