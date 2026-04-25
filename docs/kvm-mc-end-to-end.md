# OCI KVM + Kove MC End-to-End (with SCP + VNC)

This guide covers:
- copying the OVA from desktop to bastion
- copying OVA from bastion to MC host in private subnet
- importing/building KVM VM
- accessing console with TigerVNC over SSH tunnel

All key paths are masked placeholders.

## 1) SCP OVA from Desktop -> Bastion

Run from desktop terminal:

```bash
scp -i <DESKTOP_PRIVATE_KEY_PATH> <LOCAL_OVA_PATH>/kove-mc-2503-mcvirt.ova <BASTION_USER>@<BASTION_PUBLIC_IP>:~/
```

Example placeholders:
- `<DESKTOP_PRIVATE_KEY_PATH>` = `C:/path/to/key.pem`
- `<LOCAL_OVA_PATH>` = local directory containing OVA

## 2) SCP OVA from Bastion -> MC Host (private subnet)

SSH to bastion, then run:

```bash
scp -i ~/.ssh/<MC_HOST_KEY_NAME> ~/kove-mc-2503-mcvirt.ova <MC_HOST_USER>@<MC_HOST_PRIVATE_IP>:~/
```

## 3) Install KVM stack on MC host

SSH to MC host and run:

```bash
sudo dnf -y update
sudo dnf -y groupinstall "Virtualization Host"
sudo dnf -y install virt-install qemu-img libguestfs-tools-c
```

```bash
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl enable --now libvirtd
else
  sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
fi
```

Validate:

```bash
ls -l /dev/kvm
sudo virt-host-validate
```

## 4) Convert OVA to qcow2

```bash
mkdir -p ~/ova && cd ~/ova
tar -xvf ~/kove-mc-2503-mcvirt.ova
ls -lh *.vmdk *.ovf
qemu-img convert -p -f vmdk -O qcow2 kove-mc-1.vmdk kove-mc.qcow2
sudo mkdir -p /var/lib/libvirt/images
sudo mv -f kove-mc.qcow2 /var/lib/libvirt/images/
sudo restorecon -Rv /var/lib/libvirt/images
```

## 5) Ensure default libvirt network exists (static)

```bash
cat >/tmp/default-net.xml <<EOF
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF

sudo virsh --connect qemu:///system net-destroy default 2>/dev/null || true
sudo virsh --connect qemu:///system net-undefine default 2>/dev/null || true
sudo virsh --connect qemu:///system net-define /tmp/default-net.xml 2>/dev/null || true
sudo virsh --connect qemu:///system net-start default 2>/dev/null || true
sudo virsh --connect qemu:///system net-autostart default
sudo virsh --connect qemu:///system net-list --all
```

This keeps the libvirt guest NAT network predictable and separate from OCI host subnets (for example `10.0.2.0/24`).

## 5.5) **Create MC host golden image (recommended checkpoint)**

If you need a fresh host image that does **not** carry old guest artifacts, create the OCI custom image **here** (after host prep + static libvirt network, before guest import/build):

- ✅ Include in host image:
  - KVM/libvirt packages and services
  - static default libvirt network setup (`192.168.122.0/24`)
  - host routing / VNIC cloud-init setup
- ❌ Exclude from host image:
  - extracted OVA files
  - converted guest qcow2
  - existing `kove-mc` libvirt domain/metadata

Before imaging, clean host guest artifacts:

```bash
sudo virsh --connect qemu:///system destroy kove-mc 2>/dev/null || true
sudo virsh --connect qemu:///system undefine kove-mc --nvram 2>/dev/null || \
  sudo virsh --connect qemu:///system undefine kove-mc 2>/dev/null || true
sudo rm -f /var/lib/libvirt/images/kove-mc.qcow2
rm -rf ~/ova
```

Then create the OCI custom image from this MC host.

After launching a new MC host from that image, continue with sections **4 -> 9** to finish guest build and validation.

## 6) Create KVM domain

Use conservative known-good settings first:

```bash
sudo virt-install \
  --connect qemu:///system \
  --name kove-mc \
  --memory 8192 \
  --vcpus 2 \
  --cpu Westmere,-svm,-x2apic,-tsc-deadline,-invtsc \
  --machine pc \
  --disk path=/var/lib/libvirt/images/kove-mc.qcow2,format=qcow2,bus=sata,target=sda \
  --network network=default,model=e1000 \
  --os-variant rhel8.7 \
  --graphics vnc,listen=127.0.0.1 \
  --serial pty \
  --console pty,target_type=serial \
  --import \
  --noautoconsole
```

Start and verify:

```bash
sudo virsh --connect qemu:///system start kove-mc
sudo virsh --connect qemu:///system autostart kove-mc
sudo virsh --connect qemu:///system domifaddr kove-mc
sudo virsh --connect qemu:///system vncdisplay kove-mc
```

## 7) TigerVNC access from Desktop (public MC host)

Check VNC display on MC host:

```bash
sudo virsh --connect qemu:///system vncdisplay kove-mc
```

If result is `127.0.0.1:0`, remote VNC port is `5900`.

Create SSH tunnel from desktop:

```bash
ssh -N -L 5901:127.0.0.1:5900 -i <DESKTOP_PRIVATE_KEY_PATH> <MC_HOST_USER>@<MC_HOST_PUBLIC_IP>
```

Then open TigerVNC to:

```text
127.0.0.1:5901
```

If `vncdisplay` shows `127.0.0.1:1`, use host port `5901` in the tunnel.

## 8) Optional: install noVNC on bastion (browser-based console)

Use this only if you want browser access instead of TigerVNC client.

On bastion:

```bash
sudo dnf -y install python3 git
cd /opt
sudo git clone https://github.com/novnc/noVNC.git /opt/noVNC
sudo git clone https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify
```

Create tunnel from bastion to MC host VNC:

```bash
ssh -N -L 15900:127.0.0.1:5900 -i ~/.ssh/<MC_HOST_KEY_NAME> <MC_HOST_USER>@<MC_HOST_PRIVATE_IP>
```

Start noVNC on bastion:

```bash
/opt/noVNC/utils/novnc_proxy --listen 6080 --vnc 127.0.0.1:15900
```

From desktop, tunnel to bastion:

```bash
ssh -N -L 6080:127.0.0.1:6080 -i <DESKTOP_PRIVATE_KEY_PATH> <BASTION_USER>@<BASTION_PUBLIC_IP>
```

Open browser:

```text
http://127.0.0.1:6080/vnc.html
```

## 9) Optional: web UI tunnel instead of VNC

Get guest IP:

```bash
sudo virsh --connect qemu:///system domifaddr kove-mc
```

From bastion to MC host:

```bash
ssh -N -L 8443:<GUEST_IP>:443 -i ~/.ssh/<MC_HOST_KEY_NAME> <MC_HOST_USER>@<MC_HOST_PRIVATE_IP>
```

From desktop to bastion:

```bash
ssh -N -L 8443:127.0.0.1:8443 -i <DESKTOP_PRIVATE_KEY_PATH> <BASTION_USER>@<BASTION_PUBLIC_IP>
```

Open browser:

```text
https://127.0.0.1:8443
```
