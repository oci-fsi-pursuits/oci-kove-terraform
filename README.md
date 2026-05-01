# oci-kove-terraform

Terraform configuration for deploying a Kove RDMA shared-memory platform on Oracle Cloud Infrastructure (OCI).

## What This Deploys

The root module can deploy:

- OCI networking, or use existing public/private subnets
- one MC instance, which is the management VM
- RDMA memory-node bare metal infrastructure
- one optional `compute-system` bare metal node, enabled by default
- one optional bastion jump host, enabled by default

The MC instance is the management VM. There is no second management VM in `xpd-cluster`.

## Image Inputs

Use one shared RHEL 8.10 base image by default, then override only where needed:

```hcl
rhel8_10_image_ocid        = "ocid1.image.oc1..REPLACE_ME"
bm_node_custom_image_ocid  = ""
mc_custom_image_ocid       = ""
bastion_custom_image_ocid  = ""
```

Image precedence:

- RDMA memory nodes and `compute-system` use `bm_node_custom_image_ocid` when set; otherwise `rhel8_10_image_ocid`.
- MC/management uses `mc_custom_image_ocid` when set; otherwise `rhel8_10_image_ocid`.
- Bastion uses `bastion_custom_image_ocid` when set; otherwise `rhel8_10_image_ocid`.

## Main Components

| Component | Module | Default | Purpose |
|---|---|---:|---|
| MC/management | `modules/mc-instance` | enabled | Runs the MC host and management workflow. |
| RDMA memory nodes | `modules/xpd-cluster` | enabled | Creates the RDMA memory-node OCI cluster network. |
| Compute-system BM | `modules/compute-system` | enabled | Optional single BM node labeled `compute-system`. |
| Bastion | `modules/bastion` | enabled | Optional public jump host. |

To skip the optional compute-system node while keeping memory nodes:

```hcl
enable_compute_system = false
```

To skip the bastion:

```hcl
enable_bastion = false
```

## RDMA Deployment Mode

This repository is documented for the production `cluster_network` flow.

- `cluster_network`: creates an OCI cluster network for the RDMA memory-node pool.
- The optional `compute-system` node is a standalone BM in the private subnet.

## Cluster Placement Group (xpd-cluster)

Placement group controls are part of the RDMA/xpd path (`modules/xpd-cluster`) and are configured from root tfvars.

```hcl
cluster_placement_group_enabled     = true
cluster_placement_group_type        = "STANDARD"
cluster_placement_group_name        = "kove-rdma-cpg"
cluster_placement_group_description = "RDMA bare metal placement group"
```

If omitted, defaults apply and placement groups are not created.

> ⚠️ Capacity warning
> Cluster placement groups can reduce placement flexibility. In constrained AD/FD capacity conditions, enabling them may increase launch delays or capacity-related provisioning failures.

## Start Here

1. Download the required Kove documentation and software files from [download.kove.com/login](https://download.kove.com/login). Treat these as prerequisites for the deployment and MC completion workflow:

- `Kove_Direct_System_Architecture-C_API-2503`
- `Kove_SDM-Getting_Started-2503`
- `Kove_SDM-Interoperability_Matrix-2503`
- `Kove-Compute_System_Software-User_Guide-2503`
- `Kove-Management_Console-User_Guide-2503`
- `Kove-XPD_Memory_Target_Software-User_Guide-2503`
- `kove-xpd-software-2503-rhel8.10`
- `kove-mc-2503-mcvirt`
- `kove-compute-software-2503-rhel8.10`

2. Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` for your tenancy, compartment, subnets, RHEL 8.10 image, and deployment mode.

4. Initialize and deploy:

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

Cluster network deployment:

```hcl
rdma_deployment_mode = "cluster_network"
memory_node_count    = 2
```

MC/management instance:

```hcl
enable_mc_instance = true
mc_deployment_mode = "custom_image"
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
| `modules/mc-instance` | MC/management instance module. |
| `modules/xpd-cluster` | RDMA memory-node infrastructure module. |
| `modules/compute-system` | Optional single BM compute-system module. |
| `modules/bastion` | Optional public jump host module. |
| `modules/networking` | VCN, subnet, route, and security-list module. |
| `docs` | End-user setup and offline RPM guides. |

## Notes

- In the current MC workflow, FIPS mode must be disabled before creating the XPD connection. The MC requires a key type that is not supported while FIPS is enabled. On the MC instance, disable FIPS and reboot before completing the XPD connection:

```bash
sudo fips-mode-setup --disable
sudo reboot
```

- With the current architecture, MC web UI access is reached through SSH tunneling: workstation to bastion, then into the private KVM host and MC guest. Example config to tunnel to guest MC on KVM host.

```sshconfig
Host oci-kvm
    ProxyJump oci-bastion
    HostName 10.0.2.XX
    User cloud-user
    IdentityFile <path to private key>
    LocalForward 5900 127.0.0.1:5900
```

After connecting to `oci-bastion`, open the MC web UI from the workstation at `https://localhost:1443`.



