# rdma-platform

Reusable RDMA platform module for:

- optional VCN creation (or existing VCN attachment)
- bastion and management controller VM
- BM RDMA nodes in either:
  - `compute_cluster` mode, or
  - `cluster_network` mode
- optional management secondary VNIC
- optional memory autoscale wiring

For turnkey deployment wrappers (OCI Resource Manager schema, stack defaults), use `stacks/kove-rdma-platform`.
