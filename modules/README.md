# Modules

| Module | Purpose |
|---|---|
| [labels](./labels/) | Standard naming prefix and freeform tags. |
| [mc-instance](./mc-instance/) | Dedicated MC KVM host VM with custom-image or cloud-init setup modes. |
| [networking](./networking/) | VCN, public/private subnets, gateways, route tables, and security lists. |
| [oke](./oke/) | OKE cluster and worker node pool on supplied networking. |
| [rdma-platform](./rdma-platform/) | Full RDMA platform infrastructure deployment module. |
| [rdma-autoscale](./rdma-autoscale/) | OCI Function + Monitoring alarm autoscaling overlay module. |

Use modules directly for custom compositions, or use stack wrappers in `stacks/` for opinionated deployments.
