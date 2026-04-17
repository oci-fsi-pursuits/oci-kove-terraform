# oci-kove-terraform

Reusable **Terraform modules** and **examples** for Oracle Cloud Infrastructure (Kove). This tree is intended to live in its **own Git root**; it is nested here only for convenience until you move it.

## Layout

| Path | Purpose |
|------|---------|
| `modules/` | Versioned, composable building blocks (see table below). |
| `examples/` | Runnable roots that **call** modules for integration testing and copy-paste starts. |
| `stacks/` | Opinionated full deployments that compose multiple modules and extra resources. |

Each **example** is its own Terraform **root** (`terraform init` inside that folder).

## Module map

| Area | Folder | Role |
|------|--------|------|
| **Labels** | `modules/labels` | Tags and `name_prefix` — no OCI resources. |
| **Networking** | `modules/networking` | New VCN + public / management / RDMA subnets, gateways, routes, security lists. |
| **OKE** | `modules/oke` | OKE cluster + worker node pool (expects VCN/subnets as inputs). |
| **RDMA Platform** | `modules/rdma-platform` | Full RDMA deployment module (management controller, BM plane, optional autoscale). |
| **Compute** | *(future)* | Bare metal / VM instances, pools, images. |
| **Placement** | *(future)* | Cluster placement groups (rack-aware **compute** placement — not the same as VCN design). |
| **Autoscaling** | *(future)* | Instance pool or cluster autoscaler wiring. |

- **Terraform module names** in `module "..."` blocks: short **snake_case** matching the folder when practical, e.g. `module "labels"`, `module "networking"`.
- **Resource `display_name`s / OCI names:** `{namespace}-{environment}-{role}-{suffix}` with lowercase hyphenation, e.g. `kove-prod-vcn-rdma`.
- **Freeform tags:** at minimum `project`, `environment`, `managed_by = "terraform"`, plus module-specific tags.

Namespaces default to **`kove`** but stay overridable per deployment.

## Requirements

- Terraform `>= 1.3`
- OCI provider `>= 5.0` (examples pin a recent `~> 5` or `~> 6`; align with your org)

## Using modules from this repo

**Local path (while nested in a monorepo):**

```hcl
module "labels" {
  source = "../../../oci-kove-terraform/modules/labels"
  # ...
}
```

**After moving to its own repo / version tags:**

```hcl
module "labels" {
  source = "git::https://github.com/<org>/oci-kove-terraform.git//modules/labels?ref=v0.1.0"
}
```

## Roadmap (incremental)

1. **`labels`** — tags and naming (done).
2. **`networking`** — new VCN + three subnets (done).
3. **`oke`** — OKE cluster + worker node pool (initial module added).
4. **`modules/rdma-platform`** — reusable RDMA platform module (management, BM plane, autoscale hooks, cluster-network discovery).
5. **`stacks/kove-rdma-platform`** — thin deployment wrapper around `modules/rdma-platform` for Resource Manager / stack UX.
6. **`compute`**, **`placement`**, **`autoscaling`** — split into standalone modules as needed.

## License

Use the same license as the parent project unless you specify otherwise.
