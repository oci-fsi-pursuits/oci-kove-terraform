# Example: minimal (`kove-context` only)

Validates the **`kove-context`** module without creating OCI resources.

```bash
cd oci-kove-terraform/examples/minimal
terraform init
terraform apply
```

Expected outputs: `name_prefix` like `kove-dev-demo` and a `tags` map.
