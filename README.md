# oci-kove-terraform

Terraform configuration for deploying a Kove RDMA shared-memory platform on Oracle Cloud Infrastructure (OCI).

## What This Deploys

The root module can deploy:

- OCI networking, or use existing subnets
- XPD bare metal nodes with RDMA
- Management Console (MC) KVM host VM
- an optional bastion VM

The XPD/MC nodes use a required custom image:

```hcl
bm_node_image_ocid = "ocid1.image.oc1..REPLACE_ME"
```

## Deployment Modes

RDMA deployment modes:

| Mode | Description |
|---|---|
| `compute_cluster` | Creates a compute cluster plus individual bare metal instances. |
| `cluster_network` | Creates an OCI cluster network for the memory-node pool. |

MC host deployment modes:

| Mode | Description |
|---|---|
| `custom_image` | Uses a prebuilt MC host image. |
| `cloud_init_setup` | Uses a base image and lets cloud-init install/configure KVM and libvirt. |

## Start Here

1. Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` for your tenancy, compartment, subnets, images, and deployment mode.

3. Initialize and deploy:

```bash
terraform init
terraform plan
terraform apply
```

## Documentation

| Document | Use When |
|---|---|
| [Complete MC setup](docs/complete-mc-setup.md) | You need to finish MC guest import and validate MC access. |
| [Complete MC setup with offline RPMs](docs/complete-mc-setup-offline.md) | The MC host installs packages from the offline RPM tarball. |
| [Offline RPM install guide](docs/offline-rpm-install-guide.md) | You need the Object Storage links and `.tfvars` values for the RHEL 8.10 RPM tarball. |

## Common Inputs

Existing VCN deployment:

```hcl
use_existing_vcn           = true
existing_vcn_id            = "ocid1.vcn.oc1..REPLACE_ME"
existing_public_subnet_id  = "ocid1.subnet.oc1..REPLACE_ME"
existing_private_subnet_id = "ocid1.subnet.oc1..REPLACE_ME"
```

RDMA cluster network deployment:

```hcl
rdma_deployment_mode = "cluster_network"
memory_node_count    = 2
```

Dedicated MC host:

```hcl
enable_mc_instance = true
mc_deployment_mode = "custom_image"
mc_custom_image_ocid = "ocid1.image.oc1..REPLACE_ME"
```

Offline RPM tarball:

```hcl
offline_repo_tarball_url    = "https://object-storage-url/kove-rhel8.10-offline-rpms.tar.gz"
offline_repo_tarball_sha256 = "REPLACE_WITH_SHA256"

mc_offline_repo_tarball_url    = "https://object-storage-url/kove-rhel8.10-offline-rpms.tar.gz"
mc_offline_repo_tarball_sha256 = "REPLACE_WITH_SHA256"
```

## Requirements

- Terraform `>= 1.3`
- OCI Terraform provider `>= 5.0`
- OCI credentials with permission to create the selected resources

## Repository Layout

| Path | Purpose |
|---|---|
| `main.tf` | Root deployment wrapper. |
| `variables.tf` | Root input variables. |
| `terraform.tfvars.example` | Example production-style variable file. |
| `modules/xpd-cluster` | RDMA platform module. |
| `modules/mc-instance` | Dedicated MC KVM host module. |
| `modules/networking` | VCN, subnet, route, and security-list module. |
| `docs` | End-user setup and offline RPM guides. |

## Notes

Do not commit `.tfvars`, Terraform state, generated plans, private keys, RPMs, or offline tarballs.
