# Kove MC on OCI KVM: From Host Build to VNC Access

This guide walks through a fresh setup on an OCI bare metal host (for example `BM.Optimized3.36`) and ends with viewing the Management Console (MC) in TigerVNC.

## 1) Install KVM and libvirt on the host

Run on the OCI host:

```bash
sudo dnf -y update
sudo dnf -y groupinstall "Virtualization Host"
sudo dnf -y install virt-install qemu-img libguestfs-tools-c
```

Start virtualization services:

```bash
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl enable --now libvirtd
else
  sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
fi
```

Validate:

```bash
lsmod | grep kvm
sudo virsh --connect qemu:///system list --all
```

## 2) Extract OVA and convert to qcow2

```bash
mkdir -p ~/ova && cd ~/ova
tar -xvf ~/kove-mc-2503-mcvirt.ova
ls -lh *.vmdk *.ovf
```

Convert the VMDK found above (example name: `kove-mc-1.vmdk`):

```bash
qemu-img convert -p -f vmdk -O qcow2 kove-mc-1.vmdk kove-mc.qcow2
```

Move image into libvirt storage:

```bash
sudo mkdir -p /var/lib/libvirt/images
sudo mv kove-mc.qcow2 /var/lib/libvirt/images/
sudo restorecon -Rv /var/lib/libvirt/images
```

## 3) Define `default` libvirt network (assume missing)

```bash
cat >/tmp/default-net.xml <<'EOF'
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

sudo virsh --connect qemu:///system net-define /tmp/default-net.xml 2>/dev/null || true
sudo virsh --connect qemu:///system net-start default 2>/dev/null || true
sudo virsh --connect qemu:///system net-autostart default
sudo virsh --connect qemu:///system net-list --all
```

## 4) Create the VM (known-good baseline)

This is the baseline domain config we used successfully:

```bash
sudo virt-install \
  --connect qemu:///system \
  --name kove-mc \
  --memory 8192 \
  --vcpus 1 \
  --cpu host-model \
  --disk path=/var/lib/libvirt/images/kove-mc.qcow2,format=qcow2,bus=sata,target=sda \
  --network network=default,model=e1000 \
  --os-variant rhel8.7 \
  --graphics vnc,listen=127.0.0.1 \
  --serial pty \
  --console pty,target_type=serial \
  --import \
  --noautoconsole
```

Notes:
- `bus=sata,target=sda` is intentional for this appliance.
- Start at `1` vCPU for stability; increase later if stable.

## 5) Start, autostart, and basic checks

```bash
sudo virsh --connect qemu:///system start kove-mc
sudo virsh --connect qemu:///system autostart kove-mc
sudo virsh --connect qemu:///system domstate kove-mc
sudo virsh --connect qemu:///system domifaddr kove-mc
```

Serial console (optional):

```bash
sudo virsh --connect qemu:///system console kove-mc --devname serial0
```

Exit console with `Ctrl + ]`.

## 6) Get VNC display on host

```bash
sudo virsh --connect qemu:///system vncdisplay kove-mc
```

Typical result: `127.0.0.1:0` (means port `5900` on the host loopback).

## 7) Tunnel VNC to your laptop

From your local machine (PowerShell example):

```powershell
ssh -L 5901:127.0.0.1:5900 -i "C:\Users\<you>\Documents\<key-path>\kove-priv.key" cloud-user@<KVM_HOST_PUBLIC_IP>
```

Keep this SSH session open.

If host user is `opc`, use `opc@<KVM_HOST_PUBLIC_IP>` instead.

## 8) Open TigerVNC Viewer

In TigerVNC, connect to:

```text
127.0.0.1:5901
```

You should now see the MC VM display.

## 9) Useful troubleshooting

### VM says CPU incompatible (`svm`, etc.)

Recreate VM with `--cpu host-model` and remove old domain definition:

```bash
sudo virsh --connect qemu:///system destroy kove-mc 2>/dev/null || true
sudo virsh --connect qemu:///system undefine kove-mc --nvram 2>/dev/null || sudo virsh --connect qemu:///system undefine kove-mc
```

### VM fails with memory allocation

Lower memory/vCPU:

```bash
sudo virsh --connect qemu:///system setmaxmem kove-mc 6144M --config
sudo virsh --connect qemu:///system setmem kove-mc 6144M --config
```

### Serial console is blank

Use VNC path; serial may not have interactive getty even when boot logs appear.

### XMS/Platform errors in guest console

`XMSConnectionRefusedError` means XPD cannot connect to Platform service endpoint. This is an in-guest service/startup issue, not a libvirt start failure.

## 10) Optional: increase vCPU after stable boot

```bash
sudo virsh --connect qemu:///system setvcpus kove-mc 2 --config
# later, if stable
sudo virsh --connect qemu:///system setvcpus kove-mc 4 --config
```

Verify:

```bash
sudo virsh --connect qemu:///system vcpuinfo kove-mc
```
