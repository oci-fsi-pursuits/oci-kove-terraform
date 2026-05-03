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

## OCI Defined Tag Prerequisite

This module emits OCI `defined_tags`, not `freeform_tags`. OCI requires the tag namespace and every tag key to exist before Terraform creates tagged resources.

Before running `terraform apply`, create or verify the tag namespace in OCI:

1. Open OCI Console.
2. Go to **Governance & Administration** -> **Tag Namespaces**.
3. Create or reuse the `kove` namespace.
4. Inside that namespace, create these tag keys:

- `project`
- `environment`
- `managed_by`
- `workload`
- `node_role`
- `node_pool`
- `node_index`
- `cluster_name`

Set the namespace in root `.tfvars`:

```hcl
enable_defined_tags   = true
defined_tag_namespace = "kove"
```

If the OCI namespace or keys are not ready yet, set `enable_defined_tags = false`. The module still produces the same display-name prefix, but emits an empty defined-tag map.

With the default namespace, the labels module emits tag keys like:

```hcl
{
  "kove.project"     = "kove"
  "kove.environment" = "prod"
  "kove.managed_by"  = "terraform"
  "kove.workload"    = "xpd"
}
```

Other modules add role-specific tags such as `kove.node_role`, `kove.node_pool`, `kove.node_index`, and `kove.cluster_name` for instance pools and cluster networks.

If the namespace or any key is missing, OCI returns an `Invalid tags` error during apply. Fix the OCI tag namespace/keys first, then re-run `terraform apply`.

## Outputs

| Name | Description |
|---|---|
| `name_prefix` | Combined prefix such as `kove-prod`. |
| `tags` | Map for `defined_tags` on OCI resources. |
| `defined_tags` | Same defined tag map as `tags`. |
| `namespace` | Echo of the input namespace. |
| `environment` | Echo of the input environment. |
| `stack_name` | Compatibility output; not included in the default display-name prefix. |
