# Complete MC setup with offline RPMs

Use this guide when the MC host is built without public package repository access and Terraform/cloud-init installs RPMs from the offline repository tarball.

Before following this guide, configure the offline RPM tarball variables in your `.tfvars` file using [offline-rpm-install-guide.md](./offline-rpm-install-guide.md).

## What cloud-init handles

Cloud-init prepares the MC host by:

- downloading the offline RPM repository tarball
- verifying the SHA256 checksum when provided
- creating a local `file://` yum repository
- installing the MC host packages
- enabling libvirt services
- creating the MC import helper script
- creating the port-forwarding helper and systemd unit

Do not run manual `dnf` or `yum` package installs on the MC host during normal setup.

## Verify the host

SSH to the MC host and verify the expected packages and services:

```bash
rpm -q qemu-kvm libvirt virt-install qemu-img python3

if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl is-active libvirtd
else
  sudo systemctl is-active virtqemud.socket virtnetworkd.socket virtstoraged.socket
fi

sudo virsh --connect qemu:///system net-list --all
```

The `default` libvirt network should be active. If it is not active, check cloud-init logs:

```bash
sudo cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
```

## Copy the MC image

Copy the MC OVA file into the MC host user's home directory:

```bash
scp kove-mc-2503-mcvirt.ova cloud-user@<mc-host-private-ip>:~/
```

The setup helper searches the sudo caller's home directory for the first `.ova` file, converts it for libvirt, and imports the VM. You can also pass an explicit OVA path as the second argument.

## Import and start the MC guest

Run the helper script that cloud-init created:

```bash
sudo /opt/kove/setup-kove-mc.sh
```

If you changed the defaults, pass explicit values:

```bash
sudo /opt/kove/setup-kove-mc.sh \
  kove-mc \
  /home/cloud-user/kove-mc.ova \
  2 \
  8192
```

Confirm the guest is running:

```bash
sudo virsh --connect qemu:///system list --all
sudo virsh --connect qemu:///system domifaddr kove-mc --full
```

Use `sudo virsh` for system libvirt commands. Running `virsh --connect qemu:///system ...` without sudo can prompt for root authentication through polkit.

## Validate forwarded access

After the guest has an IP address, re-run the forwarding helper or restart the systemd unit:

```bash
sudo systemctl restart kove-mc-port-forwarding.service
sudo nft list chain ip nat PREROUTING
```

From a client or bastion that can reach the MC host secondary IP:

```bash
curl -k --connect-timeout 15 \
  https://<mc-secondary-ip>:8443/host_api/v1/fabric_type
```

Expected response:

```text
"RoCE"
```

If validation fails, check in this order:

1. The MC guest is running and has an IP address.
2. The guest service is listening on port `8443`.
3. The MC host has nftables DNAT rules.
4. The OCI security rules allow inbound traffic to the MC host secondary IP.
5. Cloud-init completed successfully.
