# labels module

Creates a consistent naming prefix and freeform tag map for OCI resources.

This module does not create cloud resources.

## Usage

```hcl
module "labels" {
  source = "./modules/labels"

  namespace   = "kove"
  environment = "prod"
  stack_name  = "rdma"

  additional_tags = {
    project = "rdma-platform"
  }
}
```

## Outputs

| Name | Description |
|---|---|
| `name_prefix` | Combined prefix such as `kove-prod-rdma`. |
| `tags` | Map for `freeform_tags` on OCI resources. |
| `namespace` | Echo of the input namespace. |
| `environment` | Echo of the input environment. |
| `stack_name` | Echo of the input stack name. |
