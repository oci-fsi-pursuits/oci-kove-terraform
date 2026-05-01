# mc-instance module

Deploys the MC instance. In the root deployment, this is the management VM.
Cloud-init is applied in both deployment modes.

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

## Secondary VNIC support

The module can optionally attach a second VNIC to the MC host:

- `secondary_vnic_enabled = true`
- `secondary_vnic_subnet_id = "ocid1.subnet..."`
- optional `secondary_vnic_private_ip`
- optional `secondary_vnic_interface` (default `eth1`)

Cloud-init includes a boot-time routing helper that dynamically discovers the secondary interface IP/subnet/gateway and configures:

- `rt_tables` entry (`200 vnic2`)
- source-based routes/rules for the secondary IP
- `rp_filter=2` (loose mode) for multi-VNIC policy routing

Cloud-init also installs a boot-time MC forwarding helper that dynamically discovers:

- primary VNIC interface/IP (from default route)
- secondary VNIC interface/IP (from `secondary_vnic_interface`)
- guest VM IP from libvirt DHCP/leases

Then it applies nftables DNAT/FORWARD rules for:

- `2222 -> guest:22`
- `443 -> guest:443`
- `8443 -> guest:8443`

This is wired as a systemd oneshot (`kove-mc-port-forwarding.service`) so forwarding is re-applied on boot.

## Manual completion flow

1. Copy OVA/qcow2 to the MC host.
2. Convert to qcow2 if needed and place at `/var/lib/libvirt/images/kove-mc.qcow2`.
3. Run:

```bash
sudo /opt/kove/setup-kove-mc.sh
```

Or pass explicit values:

```bash
sudo /opt/kove/setup-kove-mc.sh kove-mc /var/lib/libvirt/images/kove-mc.qcow2 2 8192
```
