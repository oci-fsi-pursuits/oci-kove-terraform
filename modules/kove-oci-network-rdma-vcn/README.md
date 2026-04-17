# kove-oci-network-rdma-vcn

Creates a dedicated VCN with:

- Internet gateway, NAT gateway, service gateway (for object storage patterns)
- Public + private route tables
- DHCP options (VCN-local + Internet DNS)
- Security lists (public: SSH + optional HPC UI ports; private: VCN + optional extra SSH CIDRs)
- Three subnets: **public** (index 1), **management** (2), **RDMA** (3) under `cidrsubnet(vcn_cidr, 8, n)`

Does **not** handle attaching to an existing VCN; the stack passes through existing subnet OCIDs when `use_existing_vcn = true`.
