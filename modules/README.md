# Modules

| Module | Status | Description |
|--------|--------|-------------|
| [labels](./labels/) | **Initial** | Standard `freeform_tags` and `name_prefix` (`namespace-environment-stack_name`). |
| [networking](./networking/) | **Initial** | New VCN + 3 subnets (public / mgmt / RDMA) + gateways + route tables + SLs. |
| [oke](./oke/) | **Initial** | OKE cluster + worker node pool using supplied VCN/subnets. |
| [rdma-platform](./rdma-platform/) | **Initial** | Full RDMA deployment module (networking, controller, BM plane, autoscale hooks). |

**Planned (not yet extracted as modules):** **compute** (instances, instance pools), **placement** (cluster placement groups — rack-aware placement for compute, not VCN networking), **autoscaling** (instance pool / cluster autoscaler patterns).

Module directories use short **kebab-case** names (`labels`, `networking`, `oke`, `rdma-platform`). Document required provider versions in each module’s `versions.tf`.
