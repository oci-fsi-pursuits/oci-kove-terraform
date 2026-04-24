# Modules

| Module | Purpose |
|---|---|
| [compute-cluster](./compute-cluster/) | Primary module for compute-cluster based RDMA platform deployments. |
| [cluster-network](./cluster-network/) | Primary module for cluster-network based RDMA platform deployments. |
| [compute-cluster/functions-autoscale](./compute-cluster/functions-autoscale/) | OCI Function + Monitoring alarm autoscaling overlay module. |
| [labels](./labels/) | Standard naming prefix and freeform tags. |
| [mc-instance](./mc-instance/) | Dedicated MC KVM host VM with custom-image or cloud-init setup modes. |
| [networking](./networking/) | VCN, public/private subnets, gateways, route tables, and security lists. |
| [oke](./oke/) | OKE cluster and worker node pool on supplied networking. |

Use modules directly for custom compositions, or use stack wrappers in `stacks/` for opinionated deployments.
