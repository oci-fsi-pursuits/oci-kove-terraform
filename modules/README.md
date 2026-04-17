# Modules

| Module | Status | Description |
|--------|--------|-------------|
| [kove-context](./kove-context/) | **Initial** | Standard `freeform_tags` and `name_prefix` (`namespace-environment-stack_name`). |
| [kove-oci-network-rdma-vcn](./kove-oci-network-rdma-vcn/) | **Initial** | New VCN + 3 subnets (public / mgmt / RDMA) + gateways + route tables + SLs. |

Add new modules as **`kove-<area>-<thing>`** (kebab-case directories). Document required provider versions in each module’s `versions.tf`.
