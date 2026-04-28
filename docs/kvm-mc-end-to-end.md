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

## 7) Single-step VNC tunnel (Desktop -> Bastion -> MC)

Use one SSH command to tunnel VNC through bastion to MC.

PowerShell:

```powershell
ssh -N -L 5901:127.0.0.1:5900 -o IdentitiesOnly=yes -i "<Private key path on Desktop>" -o 'ProxyCommand=ssh -o IdentitiesOnly=yes -i "<Private key path on Desktop>" opc@<Bastion_IP> ssh -i ~/.ssh/<Private Key to ssh from bastion to MC> -W %h:%p cloud-user@<MC_IP>' cloud-user@<MC_IP>
```

Git Bash:

```bash
ssh -N -L 5901:127.0.0.1:5900 \
  -o IdentitiesOnly=yes \
  -i "<private_key_path_on_desktop>" \
  -o 'ProxyCommand=ssh -o IdentitiesOnly=yes -i "<private_key_path_on_desktop>" opc@<bastion_ip> ssh -i ~/.ssh/<private_key_on_bastion_for_mc> -W %h:%p cloud-user@<mc_ip>' \
  cloud-user@<mc_ip>
```

Then open VNC Viewer to:

```text
127.0.0.1:5901
```
