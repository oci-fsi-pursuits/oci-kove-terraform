# Complete MC setup

Use this guide to deploy and finish setup for the MC KVM host created by the `mc-instance` module. This MC instance is the deployment management VM.

For environments without public package repository access, use [complete-mc-setup-offline.md](./complete-mc-setup-offline.md) instead.

## Overview

> Note: This document applies to automated MC KVM host setup flow. If `mc_enable_kvm_automation = false` (default), use [mc-setup-manual-end-to-end.md](./mc-setup-manual-end-to-end.md).

Terraform creates an MC host VM and injects cloud-init. Cloud-init prepares the host by:

- installing or validating KVM/libvirt packages
- enabling libvirt services
- creating the default libvirt NAT network
- writing `/opt/kove/setup-kove-mc.sh`
- writing host-side port-forwarding helpers
- creating `kove-mc-port-forwarding.service`

The operator then copies the MC OVA image to the MC host home directory and runs one command:

```bash
sudo /opt/kove/setup-kove-mc.sh
```

That helper converts the OVA, imports the guest, waits for the guest IP, applies forwarding, and prints verification output.

## Prerequisites

Before deploying:

- Terraform is initialized for this repo.
- OCI credentials and compartment inputs are configured.
- The MC host subnet can reach the package source required by your deployment mode.
- The MC guest image is available as an OVA.
- OCI security rules allow required inbound traffic to the **MC secondary VNIC** private IP (client access to the guest is via that address), typically TCP `2222`, `443`, and `8443`.

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

Both `mc_deployment_mode = "custom_image"` and `"cloud_init_setup"` should use the same **`/etc/kove/mc-instance.conf`** contract whenever the Terraform module writes cloud-init: the image mode simply ships a pre-baked disk that still expects that file (or IMDS fallback) to be present after apply.

Optional MC host sizing:

```hcl
mc_shape                  = "VM.Standard3.Flex"
mc_ocpus                  = 3
mc_memory_gbs             = 32
mc_boot_volume_size_gbs   = 200
```

The MC secondary VNIC is always attached. It uses the platform private subnet from the root deployment (`existing_private_subnet_id` when using an existing VCN, otherwise the created private subnet), lets OCI assign the private IP dynamically, and uses Linux interface `eth1`. Cloud-init writes these defaults into `/etc/kove/mc-instance.conf`; host scripts source that file and use OCI instance metadata to discover the assigned secondary IP.

Default MC guest settings:

```hcl
mc_guest_vm_name   = "kove-mc"
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

## Copy the MC image

Copy the MC OVA file into the MC host user's home directory:

```bash
scp kove-mc-2503-mcvirt.ova cloud-user@<mc-host-private-ip>:~/
```

The setup helper searches the sudo caller's home directory for the first `.ova` file, converts it for libvirt, and imports the VM. You can also pass an explicit OVA path as the second argument.

## Run the setup helper

This is the only setup command you should need after copying the OVA:

```bash
sudo /opt/kove/setup-kove-mc.sh
```

Cloud-init writes this helper on the MC host. It is a repeatable wrapper around OVA conversion, `virsh`, `virt-install`, secondary-VNIC routing, and forwarding.

When you run it, the script:

- prints each major step as it runs
- finds a `.ova` in the sudo caller's home directory when the libvirt guest disk is not already present
- converts OVA/VMDK content for libvirt
- configures the secondary VNIC IP and `vnic2` routing from OCI metadata when the address is not already on the interface
- stops and undefines any existing guest with the same name
- starts and enables the default libvirt NAT network
- imports the converted disk as a libvirt guest
- enables guest autostart
- waits up to 3 minutes for the guest DHCP lease so `domifaddr` is not blank immediately after import
- reapplies secondary-VNIC forwarding
- prints `virsh list`, `domifaddr`, relevant nftables rules, and the client-side curl command with the MC secondary VNIC IP filled in

If the OVA is not in the sudo caller's home directory, pass the OVA path explicitly:

```bash
sudo /opt/kove/setup-kove-mc.sh \
  kove-mc \
  /home/cloud-user/kove-mc.ova \
  2 \
  8192
```

The end of the script prints output equivalent to:

```bash
sudo virsh --connect qemu:///system list --all
sudo virsh --connect qemu:///system domifaddr kove-mc --source lease
sudo nft list ruleset | grep -E '2222|8443|kove|dnat|masquerade' -n
curl -k --connect-timeout 15 https://<mc-secondary-vnic-ip>:8443/host_api/v1/fabric_type
```

Use `sudo virsh` for system libvirt commands. Running `virsh --connect qemu:///system ...` without sudo can prompt for root authentication through polkit even though the same command works cleanly with sudo.

## Forwarding

Cloud-init creates a forwarding service that maps **the MC secondary VNIC IP** (for example `eth1`) to the libvirt guest. Traffic to the primary VNIC is **not** forwarded to the guest.

| MC host port (on secondary IP) | Guest port |
|---|---|
| `2222` | `22` |
| `443` | `443` |
| `8443` | `8443` |

The setup helper runs `/usr/local/sbin/oci-mc-port-forwarding.sh` after it sees the guest DHCP lease. If the guest takes longer than 3 minutes to receive an IP, wait for the lease and rerun forwarding manually:

```bash
sudo virsh --connect qemu:///system domifaddr kove-mc --source lease
sudo /usr/local/sbin/oci-mc-port-forwarding.sh
sudo nft list ruleset | grep -E '2222|8443|kove|dnat|masquerade' -n
```

## Validate access

From an XPD node, bastion, or another client that can reach the **secondary VNIC private IP** of the MC instance, test the forwarded path:

```bash
curl -k --connect-timeout 15 \
  https://<mc-secondary-vnic-ip>:8443/host_api/v1/fabric_type
```

Expected response:

```text
"RoCE"
```

For SSH to the guest through the MC host (same address as above):

```bash
ssh -p 2222 <guest-user>@<mc-secondary-vnic-ip>
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
| Host can reach guest but remote client cannot | OCI security rule, wrong address (use **secondary** VNIC IP, not primary), **`net.ipv4.ip_forward` off**, missing POSTROUTING masquerade for guest return traffic, or forwarding service not restarted |
| Remote client connects but session fails | Return routing or guest firewall issue |
| `setup-kove-mc.sh` cannot find disk | No `.ova` exists in the sudo caller's home directory, and no explicit OVA path was passed |
| `virt-install` fails | Missing virtualization packages or unsupported image format |
| `kove-mc-port-forwarding.service` did not apply rules | Guest not imported yet, guest has no DHCP lease, or service was not restarted after guest import |

If the guest requires console interaction during first boot:

```bash
sudo virsh --connect qemu:///system console kove-mc
sudo virsh --connect qemu:///system vncdisplay kove-mc
```

During first boot, serial console output can include startup messages and a transient init script failure line. The following pattern is a **normal and healthy sign** that core MC services are coming up during testing:

```text
MC Health Daemon started
Starting XMS Platform Integration ...
XMS Platform Integration started
Starting XMS XPD Communications Service ...
XMS XPD Communications Service started
Starting XMS Allocation Service ...
XMS Allocation Service started
Starting XMS External API Server ...
Starting XMS Host Communications Server ...
XMS Host Communications Server started
XMS External API Server started
Starting XMS Web Server ...
XMS Web Server started
/etc/init.d/xpd_ssui: line 13: [: : integer expression expected
[FAIL] startpar: service(s) returned failure: ipmievd ... failed!
result: 0
```

If you see this sequence while connected with `sudo virsh --connect qemu:///system console kove-mc serial0`, treat it as expected boot behavior for MC validation rather than an immediate deployment failure.
