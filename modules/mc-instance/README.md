# mc-instance module

Deploys the MC instance. In the root deployment, this is the management VM.
Cloud-init KVM/libvirt automation is controlled by `enable_kvm_automation` (root input: `mc_enable_kvm_automation`, default `false`).

For the end-to-end operator workflow, see [../../docs/complete-mc-setup.md](../../docs/complete-mc-setup.md). For offline package installation, see [../../docs/complete-mc-setup-offline.md](../../docs/complete-mc-setup-offline.md).

## Supported deployment modes

- `custom_image`
  - Use a prebuilt custom image for the MC host.
  - Still runs cloud-init on first boot to apply the standardized MC host setup.
- `cloud_init_setup`
  - Uses a base image and installs KVM/libvirt via cloud-init.
  - Drops a helper script on the host to complete the guest import after you copy or convert the MC disk image.

The root module resolves the MC image from `mc_custom_image_ocid` when set, otherwise `rhel8_10_image_ocid`.

## Defaults for MC host

- shape: `VM.Standard3.Flex`
- ocpus: `3`
- memory: `32` GB

## Secondary VNIC behavior

The root module always attaches a secondary VNIC for the MC host.
It uses the platform private subnet from the root deployment, lets OCI assign the private IP dynamically, and exposes it to the host as `eth1`.

When KVM automation is enabled, cloud-init includes a boot-time routing helper that discovers the secondary interface IP/subnet/gateway and configures:

- `rt_tables` entry (`200 vnic2`)
- source-based routes/rules for the secondary IP
- `rp_filter=2` (loose mode) for multi-VNIC policy routing

When KVM automation is enabled, cloud-init also installs a boot-time MC forwarding helper that discovers:

- secondary VNIC interface/IP (from config, then OCI metadata fallback)
- guest VM IP from libvirt DHCP/leases

Then it applies nftables DNAT/FORWARD rules for:

- `2222 -> guest:22`
- `443 -> guest:443`
- `8443 -> guest:8443`

Forwarding is bound to the secondary VNIC only.

This is wired as a systemd oneshot (`kove-mc-port-forwarding.service`) so forwarding is re-applied on boot.

When KVM automation is disabled, follow [../../docs/mc-setup-manual-end-to-end.md](../../docs/mc-setup-manual-end-to-end.md).

## Manual completion flow

1. Copy the OVA to the MC host user's home directory.
2. Run:

```bash
sudo /opt/kove/setup-kove-mc.sh
```

The helper converts the OVA/VMDK input for libvirt, configures secondary-VNIC routing, imports the guest, and reapplies forwarding. Use `sudo virsh --connect qemu:///system ...` for checks; plain `virsh` can prompt for root authentication through polkit.

Or pass explicit values, including an image path:

```bash
sudo /opt/kove/setup-kove-mc.sh kove-mc /home/cloud-user/kove-mc.ova 2 8192
```
