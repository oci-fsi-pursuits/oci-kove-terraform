# Modules

Reusable Terraform modules used by the root deployment.

| Module | Purpose |
|---|---|
| [xpd-cluster](./xpd-cluster/) | RDMA platform deployment, including bastion, management VM, and bare metal RDMA nodes. |
| [mc-instance](./mc-instance/) | Dedicated MC KVM host VM. |
| [networking](./networking/) | VCN, public/private subnets, gateways, route tables, and security lists. |
| [labels](./labels/) | Shared naming prefix and freeform tags. |

Most users should deploy from the repo root instead of calling modules directly. Use direct module calls only for custom compositions.
