# Modules

| Module | Purpose |
|---|---|
| [xpd-cluster](./xpd-cluster/) | Primary module for RDMA platform deployments (compute-cluster and cluster-network modes). |
| [labels](./labels/) | Standard naming prefix and freeform tags. |
| [mc-instance](./mc-instance/) | Dedicated MC KVM host VM with custom-image or cloud-init setup modes. |
| [networking](./networking/) | VCN, public/private subnets, gateways, route tables, and security lists. |
| [oke](./oke/) | OKE cluster and worker node pool on supplied networking. |

Use modules directly for custom compositions, or use stack wrappers in `stacks/` for opinionated deployments.
