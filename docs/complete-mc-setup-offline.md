# Complete MC Setup (Offline/Airgapped Variant)

This variant keeps cloud-init as the authoritative source of host package installation.

Use this document when:

- the environment is airgapped
- RPMs are delivered through an offline repository tarball
- operators should not run manual `dnf/yum install` post-boot

Authoritative package workflow:

1. `kove-mc-cloud-init.yaml.tpl` configures the offline repo (`OFFLINE_REPO_TARBALL_URL`).
2. cloud-init installs required host virtualization packages from that offline repo.
3. post-boot operator workflow starts at OVA transfer/import and validation only.

Post-boot checks (verification only):

```bash
rpm -q qemu-kvm libvirt-daemon-kvm libvirt virt-install qemu-img nftables
sudo systemctl is-active libvirtd
sudo virsh --connect qemu:///system net-list --all
```

Operator phase (no package installs):

- SCP OVA to host
- Convert VMDK to qcow2
- Import VM with `virt-install --import`
- Set `GUEST_IP` and apply forwarding
- Validate:

```bash
curl -k https://<secondaryIP>:8443/host_api/v1/fabric_type
```
