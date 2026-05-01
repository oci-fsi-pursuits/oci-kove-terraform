# networking

Creates a dedicated VCN with:

- Internet gateway, NAT gateway, service gateway (for object storage patterns)
- Public + private route tables
- DHCP options (VCN-local + Internet DNS)
- Security lists (public: SSH + HTTPS 443 + HTTPS-alt 8443 + optional HPC UI ports; private: VCN + optional extra SSH CIDRs)
- Two subnets: **public** (index 1) and **private** (index 2) under `cidrsubnet(vcn_cidr, 8, n)`

Use `private_subnet_name_prefix` to prepend a custom prefix to the private subnet display name.

Cluster placement groups are **not** configured in this module. They are part of RDMA compute placement and are configured via `modules/xpd-cluster` inputs (`cluster_placement_group_*`) at root.

> ⚠️ Capacity warning
> Cluster placement groups can reduce placement flexibility. In constrained AD/FD capacity conditions, enabling them may increase launch delays or capacity-related provisioning failures.

Does **not** handle attaching to an existing VCN; the stack passes through existing subnet OCIDs when `use_existing_vcn = true`.
