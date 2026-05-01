# xpd-cluster module

Deploys the RDMA platform on OCI.

## Components

- Optional VCN creation, or use of existing subnets
- Optional bastion VM
- Optional management VM
- RDMA bare metal nodes
- Optional cluster network memory-node pool

## RDMA deployment modes

| Mode | Description |
|---|---|
| `compute_cluster` | Creates a compute cluster and individual bare metal instances. |
| `cluster_network` | Creates a dedicated control bare metal instance and a cluster network for memory nodes. |

## Required inputs

At minimum, provide:

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..REPLACE_ME"
compartment_ocid = "ocid1.compartment.oc1..REPLACE_ME"
region           = "REPLACE_ME"
ssh_public_key   = "ssh-rsa REPLACE_ME"
bm_node_image_ocid = "ocid1.image.oc1..REPLACE_ME"
```

For existing networking:

```hcl
use_existing_vcn           = true
existing_vcn_id            = "ocid1.vcn.oc1..REPLACE_ME"
existing_public_subnet_id  = "ocid1.subnet.oc1..REPLACE_ME"
existing_private_subnet_id = "ocid1.subnet.oc1..REPLACE_ME"
```

## Cloud-init

The module renders cloud-init for bastion, management, and RDMA nodes. Cloud-init can:

- bootstrap SSH access
- install required packages from configured package sources
- install from an offline RPM repository tarball when provided
- enable OCI RDMA agent plugins when requested

For the offline RPM tarball workflow, see [../../docs/offline-rpm-install-guide.md](../../docs/offline-rpm-install-guide.md).

## Outputs

Common outputs include:

- subnet OCIDs
- bastion public IP
- management private IP
- RDMA instance IDs and private IPs
- cluster network ID when using `cluster_network`
