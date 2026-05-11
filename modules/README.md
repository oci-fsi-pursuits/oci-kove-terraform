# Modules

Reusable Terraform modules used by the root deployment.

| Module | Purpose |
|---|---|
| [xpd-cluster](./xpd-cluster/) | XPD RDMA memory-node infrastructure. |
| [mc-instance](./mc-instance/) | Management Console (MC) instance. |
| [compute-system](./compute-system/) | Optional single BM node labeled `compute-system`. |
| [bastion](./bastion/) | Optional public jump host. |
| [networking](./networking/) | VCN, public/private subnets, gateways, route tables, and security lists. |
| [labels](./labels/) | Shared naming prefix and defined tags. |

Most users should deploy from the repo root instead of calling modules directly. Use direct module calls only for custom compositions.
