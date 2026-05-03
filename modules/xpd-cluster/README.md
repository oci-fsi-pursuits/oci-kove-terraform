# xpd-cluster Module

Creates the RDMA memory-node infrastructure only.

Default memory-node display names use the role and index, for example `kove-prod-xpd-1`, `kove-prod-xpd-2`, and so on.
Resources use OCI defined tags from `modules/labels`.

This module no longer creates a bastion, a management VM, or the single `compute-system` BM. Those are owned by sibling modules at the root:

- `modules/mc-instance` for the MC/management instance
- `modules/bastion` for the optional jump host
- `modules/compute-system` for the optional single BM node

## RDMA Deployment Mode

This module is documented for production `cluster_network` use.

- `cluster_network`: creates an OCI cluster network with a memory pool sized by `memory_node_count`.

## Cluster Placement Group

Placement group controls are configured on this module interface (typically passed through from root):

```hcl
cluster_placement_group_enabled     = true
cluster_placement_group_type        = "STANDARD"
cluster_placement_group_name        = "kove-rdma-cpg"
cluster_placement_group_description = "RDMA bare metal placement group"
```

If omitted, defaults apply and placement groups are not created.

> ⚠️ Capacity warning
> Cluster placement groups can reduce placement flexibility. In constrained AD/FD capacity conditions, enabling them may increase launch delays or capacity-related provisioning failures.

## Required Inputs

At minimum, provide:

```hcl
tenancy_ocid          = "ocid1.tenancy.oc1..REPLACE_ME"
compartment_ocid      = "ocid1.compartment.oc1..REPLACE_ME"
region                = "REPLACE_ME"
ssh_public_key        = "ssh-rsa REPLACE_ME"
bm_node_image_ocid    = "ocid1.image.oc1..REPLACE_ME"
existing_vcn_id       = "ocid1.vcn.oc1..REPLACE_ME"
existing_public_subnet_id  = "ocid1.subnet.oc1..REPLACE_ME"
existing_private_subnet_id = "ocid1.subnet.oc1..REPLACE_ME"
```

The root module resolves `bm_node_image_ocid` from:

- `bm_node_custom_image_ocid` when set
- otherwise `rhel8_10_image_ocid`

## Cloud-Init

The module renders cloud-init for RDMA memory nodes. Cloud-init can:

- bootstrap SSH access
- install required packages from configured package sources
- install from an offline RPM repository tarball when provided
- enable OCI RDMA agent plugins when requested

For the offline RPM tarball workflow, see [../../docs/offline-rpm-install-guide.md](../../docs/offline-rpm-install-guide.md).

## Outputs

Common outputs include:

- subnet OCIDs
- RDMA memory-node instance IDs and private IPs
- cluster network ID when using `cluster_network`
