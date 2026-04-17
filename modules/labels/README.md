# labels

No cloud resources — shared **tags** and **`name_prefix`** for consistent OCI `display_name` values.

## Usage

```hcl
module "labels" {
  source = "./modules/labels"

  namespace   = "kove"
  environment = "prod"
  stack_name  = "rdma-ash"

  additional_tags = {
    cost_center = "eng"
  }
}

# Example display_name
# display_name = "${module.labels.name_prefix}-vcn"
```

## Outputs

| Name | Description |
|------|-------------|
| `name_prefix` | e.g. `kove-prod-rdma-ash` |
| `tags` | Map for `freeform_tags` on OCI resources |
| `namespace`, `environment`, `stack_name` | Echo inputs for wiring |
