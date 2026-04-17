# Example: OKE deployment

Deploys an OKE cluster by composing:

- `modules/labels`
- `modules/networking`
- `modules/oke`

## Run

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Fill OCI IDs, `ssh_public_key`, and `availability_domain`.
3. Run:

```powershell
terraform init
terraform plan
terraform apply
```

This example uses one VCN from `modules/networking` and maps:

- API endpoint subnet -> `public_subnet_id`
- service LB subnet -> `management_subnet_id`
- worker subnet -> `rdma_subnet_id`
