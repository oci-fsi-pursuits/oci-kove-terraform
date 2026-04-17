# kove-context

No cloud resources — shared **tags** and **`name_prefix`** for consistent OCI `display_name` values.

## Usage

```hcl
module "ctx" {
  source = "./modules/kove-context"

  namespace   = "kove"
  environment = "prod"
  stack_name  = "rdma-ash"

  additional_tags = {
    cost_center = "eng"
  }
}

# Example display_name
# display_name = "${module.ctx.name_prefix}-vcn"
```

## Outputs

| Name | Description |
|------|-------------|
| `name_prefix` | e.g. `kove-prod-rdma-ash` |
| `tags` | Map for `freeform_tags` on OCI resources |
| `namespace`, `environment`, `stack_name` | Echo inputs for wiring |
