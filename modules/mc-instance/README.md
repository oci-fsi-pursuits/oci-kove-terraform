# mc-instance module

Deploys a dedicated MC KVM host VM so MC lifecycle can be managed separately from the RDMA bare-metal stack.
Cloud-init is applied in both deployment modes.

## Supported deployment modes

- `custom_image`
  - Use a prebuilt custom image for the MC host.
  - Still runs cloud-init on first boot to apply the standardized MC host setup.
- `cloud_init_setup`
  - Uses Oracle Linux 8 (or `base_image_ocid`) and installs KVM/libvirt via cloud-init.
  - Drops a helper script on the host to complete the guest import **manually** after you copy/convert the OVA.

## Defaults for MC host

- shape: `VM.Standard3.Flex`
- ocpus: `3`
- memory: `32` GB

## Manual completion flow (`cloud_init_setup`)

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
