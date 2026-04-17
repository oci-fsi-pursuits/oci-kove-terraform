# oci-kove-terraform

Reusable **Terraform modules** and **examples** for Oracle Cloud Infrastructure (Kove). This tree is intended to live in its **own Git root**; it is nested here only for convenience until you move it.

## Layout

| Path | Purpose |
|------|---------|
| `modules/` | Versioned, composable building blocks (`kove-*`). |
| `examples/` | Runnable roots that **call** modules for integration testing and copy-paste starts. |

Each **example** is its own Terraform **root** (`terraform init` inside that folder).

## Naming convention

- **Repository:** `oci-kove-terraform` (this repo).
- **Module folders:** `kove-<domain>-<artifact>` in kebab-case, e.g. `kove-context`, `kove-oci-vcn`.
- **Terraform module names** (in `module "..."` blocks): `snake_case`, e.g. `module "kove_context" { ... }`.
- **Resource `display_name`s / OCI names:** `{namespace}-{environment}-{role}-{suffix}` with lowercase hyphenation, e.g. `kove-prod-vcn-rdma`.
- **Freeform tags:** at minimum `project`, `environment`, `managed_by = "terraform"`, plus module-specific tags.

Namespaces default to **`kove`** but stay overridable per deployment.

## Requirements

- Terraform `>= 1.3`
- OCI provider `>= 5.0` (examples pin a recent `~> 5` or `~> 6`; align with your org)

## Using modules from this repo

**Local path (while nested in a monorepo):**

```hcl
module "kove_context" {
  source = "../../../oci-kove-terraform/modules/kove-context"
  # ...
}
```

**After moving to its own repo / version tags:**

```hcl
module "kove_context" {
  source = "git::https://github.com/<org>/oci-kove-terraform.git//modules/kove-context?ref=v0.1.0"
}
```

## Roadmap (incremental)

1. **`kove-context`** — tags and naming (done).
2. **`kove-oci-network-rdma-vcn`** — new VCN + three subnets (done).
3. **`stacks/kove-rdma-platform`** — migrated RDMA stack using the modules above (in progress; legacy copy remains under `stig-hardened-builds/rdma-platform`).
4. **`kove-oci-oke`** — OKE cluster module (future).

## License

Use the same license as the parent project unless you specify otherwise.
