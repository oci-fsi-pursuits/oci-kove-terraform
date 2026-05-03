# labels module

Creates a consistent naming prefix and defined tag map for OCI resources.

This module does not create cloud resources.

## Usage

```hcl
module "labels" {
  source = "./modules/labels"

  namespace   = "kove"
  environment = "prod"

  additional_tags = {
    workload = "xpd"
  }
}
```

The default display-name prefix uses only `namespace` and `environment`. For example, `namespace = "kove"` and `environment = "prod"` produce `kove-prod`.

Defined tags are emitted under `defined_tag_namespace` (default: `kove`). The OCI tag namespace and tag keys must already exist.

## Outputs

| Name | Description |
|---|---|
| `name_prefix` | Combined prefix such as `kove-prod`. |
| `tags` | Map for `defined_tags` on OCI resources. |
| `defined_tags` | Same defined tag map as `tags`. |
| `namespace` | Echo of the input namespace. |
| `environment` | Echo of the input environment. |
| `stack_name` | Compatibility output; not included in the default display-name prefix. |
