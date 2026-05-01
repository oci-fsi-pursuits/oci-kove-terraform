# Complete MC setup

Use this guide to deploy and finish setup for the MC KVM host created by the `mc-instance` module. This MC instance is the deployment management VM.

For environments without public package repository access, use [complete-mc-setup-offline.md](./complete-mc-setup-offline.md) instead.

## Overview

Terraform creates an MC host VM and injects cloud-init. Cloud-init prepares the host by:

- installing or validating KVM/libvirt packages
- enabling libvirt services
- creating the default libvirt NAT network
- writing `/opt/kove/setup-kove-mc.sh`
- writing host-side port-forwarding helpers
- creating `kove-mc-port-forwarding.service`

The operator then copies the MC disk image to the host, imports it as a libvirt guest, and validates service access through the MC host IP.

## Prerequisites

Before deploying:

- Terraform is initialized for this repo.
- OCI credentials and compartment inputs are configured.
- The MC host subnet can reach the package source required by your deployment mode.
- The MC guest image is available as either a qcow2 file or an OVA that can be converted to qcow2.
- OCI security rules allow required inbound traffic to the MC host IP, typically TCP `2222`, `443`, and `8443`.

## Terraform inputs

Enable the MC host:

```hcl
enable_mc_instance = true
```

For a prebuilt MC host image:

```hcl
mc_deployment_mode   = "custom_image"
mc_custom_image_ocid = "ocid1.image.oc1..REPLACE_ME"
```

For a base RHEL/Oracle Linux image prepared by cloud-init:

```hcl
mc_deployment_mode  = "cloud_init_setup"
rhel8_10_image_ocid = "ocid1.image.oc1..REPLACE_ME"
```

If `mc_custom_image_ocid` is empty, the MC instance uses `rhel8_10_image_ocid`.

Optional MC host sizing:

```hcl
mc_shape                  = "VM.Standard3.Flex"
mc_ocpus                  = 3
mc_memory_gbs             = 32
mc_boot_volume_size_gbs   = 200
```

Optional secondary VNIC settings:

```hcl
mc_secondary_vnic_enabled    = true
mc_secondary_vnic_subnet_id  = "ocid1.subnet.oc1..REPLACE_ME"
mc_secondary_vnic_private_ip = "10.0.2.58"
mc_secondary_vnic_interface  = "eth1"
```

Default MC guest settings:

```hcl
mc_guest_vm_name   = "kove-mc"
mc_guest_disk_path = "/var/lib/libvirt/images/kove-mc.qcow2"
mc_guest_vcpus     = 2
mc_guest_memory_mb = 8192
```

## Deploy

Run Terraform from the repo root:

```bash
terraform init
terraform plan
terraform apply
```

After apply completes, collect the MC host private IP from Terraform outputs:

```bash
terraform output mc_private_ip
```

## Verify cloud-init

SSH to the MC host and verify cloud-init completed:

```bash
sudo cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
```

Verify libvirt:

```bash
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl is-active libvirtd
else
  sudo systemctl is-active virtqemud.socket virtnetworkd.socket virtstoraged.socket
fi

sudo virsh --connect qemu:///system net-list --all
```

The `default` libvirt network should be active and configured to autostart.

## Prepare the MC disk image

The helper script expects the guest disk at:

```text
/var/lib/libvirt/images/kove-mc.qcow2
```

If you already have a qcow2 file:

```bash
sudo mkdir -p /var/lib/libvirt/images
sudo cp /path/to/kove-mc.qcow2 /var/lib/libvirt/images/kove-mc.qcow2
sudo chown root:root /var/lib/libvirt/images/kove-mc.qcow2
sudo chmod 0644 /var/lib/libvirt/images/kove-mc.qcow2
sudo restorecon -Rv /var/lib/libvirt/images 2>/dev/null || true
```

If you have an OVA:

```bash
mkdir -p ~/kove-mc-ova
tar -xf /path/to/kove-mc.ova -C ~/kove-mc-ova
ls -lh ~/kove-mc-ova

sudo mkdir -p /var/lib/libvirt/images
sudo qemu-img convert -p -f vmdk -O qcow2 \
  ~/kove-mc-ova/*.vmdk \
  /var/lib/libvirt/images/kove-mc.qcow2
sudo restorecon -Rv /var/lib/libvirt/images 2>/dev/null || true
```

## Import the MC guest

### What the helper script does

Cloud-init writes `/opt/kove/setup-kove-mc.sh` on the MC host. The script is a repeatable wrapper around `virsh` and `virt-install`.

When you run it, the script:

- uses the default guest name, disk path, vCPU count, and memory from Terraform unless you pass explicit arguments
- verifies the qcow2 disk exists before making libvirt changes
- stops and undefines any existing guest with the same name
- starts and enables the default libvirt NAT network
- imports the qcow2 disk as a libvirt guest
- enables guest autostart
- prints the guest interface address and VNC display when available

The helper does not copy, extract, or convert the MC image. Complete the disk image preparation step before running it.

### Run the helper script

Run the helper script:

```bash
sudo /opt/kove/setup-kove-mc.sh
```

Or pass explicit values:

```bash
sudo /opt/kove/setup-kove-mc.sh \
  kove-mc \
  /var/lib/libvirt/images/kove-mc.qcow2 \
  2 \
  8192
```

Verify the guest:

```bash
sudo virsh --connect qemu:///system list --all
sudo virsh --connect qemu:///system domifaddr kove-mc --full
sudo virsh --connect qemu:///system autostart kove-mc
```

## Apply forwarding

Cloud-init creates a forwarding service that maps MC host ports to the guest:

| MC host port | Guest port |
|---|---|
| `2222` | `22` |
| `443` | `443` |
| `8443` | `8443` |

After the guest has an IP address, restart forwarding:

```bash
sudo systemctl restart kove-mc-port-forwarding.service
sudo nft list chain ip nat PREROUTING
```

## Validate access

From the MC host, test the guest directly:

```bash
curl -k --connect-timeout 12 \
  https://<guest-ip>:8443/host_api/v1/fabric_type
```

From a bastion or client that can reach the MC host IP, test the forwarded path:

```bash
curl -k --connect-timeout 15 \
  https://<mc-host-ip>:8443/host_api/v1/fabric_type
```

Expected response:

```text
"RoCE"
```

For SSH to the guest through the MC host:

```bash
ssh -p 2222 <guest-user>@<mc-host-ip>
```

## Troubleshooting

Check cloud-init:

```bash
sudo cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
```

Check libvirt:

```bash
sudo virsh --connect qemu:///system list --all
sudo virsh --connect qemu:///system net-list --all
sudo virsh --connect qemu:///system domifaddr kove-mc --full
```

Check forwarding:

```bash
sudo systemctl status kove-mc-port-forwarding.service
sudo nft list table ip nat
sudo nft list table ip filter
```

Common issues:

| Symptom | Likely cause |
|---|---|
| Guest has no IP | Guest did not boot, wrong network, or libvirt DHCP lease not ready |
| Host can reach guest but remote client cannot | OCI security rule, wrong MC host IP, or forwarding not restarted |
| Remote client connects but session fails | Return routing or guest firewall issue |
| `setup-kove-mc.sh` cannot find disk | qcow2 is not at `mc_guest_disk_path` |
| `virt-install` fails | Missing virtualization packages or unsupported image format |

If the guest requires console interaction during first boot:

```bash
sudo virsh --connect qemu:///system console kove-mc
sudo virsh --connect qemu:///system vncdisplay kove-mc
```
