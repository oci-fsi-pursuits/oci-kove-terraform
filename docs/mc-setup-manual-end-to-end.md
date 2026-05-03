# MC Host And Guest Manual Setup

Use this guide when `mc_enable_kvm_automation = false`.

This is intentionally explicit. It does not hide the KVM, image conversion, secondary VNIC routing, or nftables work inside one large script.

Assumptions:

- The MC host is a RHEL or Oracle Linux 8 VM in OCI.
- The MC host has a primary VNIC for administration and a secondary VNIC for guest access.
- The secondary VNIC appears as `eth1`.
- The secondary VNIC is on the platform private subnet.
- OCI assigns the secondary VNIC private IP dynamically.
- The MC image is an OVA copied to the MC host user's home directory.
- Libvirt guest IP is discovered dynamically from DHCP leases.
- Use `sudo virsh --connect qemu:///system ...` for libvirt commands.

Do not use plain `virsh --connect qemu:///system ...` without `sudo`; it can prompt for root authentication through polkit.

## 1. Copy The OVA To The MC Host

Run from your workstation:

```bash
scp kove-mc-2503-mcvirt.ova cloud-user@<mc-host-private-ip>:~/
```

SSH to the MC host:

```bash
ssh cloud-user@<mc-host-private-ip>
```

Confirm the OVA is present:

```bash
ls -lh ~/*.ova
```

Expected: one OVA file in the home directory.

## 2. Become Root Or Use Sudo Consistently

Either become root:

```bash
sudo su -
```

Or keep using `sudo` in every command below. The examples use `sudo` so they work from the normal `cloud-user` shell.

## 3. Install Required Packages

Install KVM, libvirt, image conversion, nftables, and basic tools:

```bash
sudo dnf install -y \
  qemu-kvm \
  libvirt-daemon-kvm \
  libvirt \
  libvirt-client \
  virt-install \
  qemu-img \
  python3 \
  nftables \
  tar
```

Verify key commands exist:

```bash
command -v virsh
command -v virt-install
command -v qemu-img
command -v nft
command -v python3
```

## 4. Start Libvirt Services

Different RHEL 8 images expose libvirt as either `libvirtd.service` or socket-activated modular daemons.

Run:

```bash
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl enable --now libvirtd
else
  sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
fi
```

Verify:

```bash
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl status libvirtd --no-pager
else
  sudo systemctl status virtqemud.socket virtnetworkd.socket virtstoraged.socket --no-pager
fi
```

## 5. Inspect Host Networking

Show the current interfaces:

```bash
ip -br addr
ip -4 route show default
```

Expected:

- `eth0` has the primary/admin IP and owns the default route.
- `eth1` exists and is the secondary VNIC.
- `eth1` may or may not already have an IPv4 address.

Set the expected secondary interface:

```bash
SECONDARY_IF=eth1
SECONDARY_PREFIX=24
```

Confirm `eth1` exists:

```bash
ip link show "${SECONDARY_IF}"
```

## 6. Discover The Secondary VNIC IP From OCI Metadata

First inspect OCI metadata manually:

```bash
curl -sS -H "Authorization: Bearer Oracle" \
  http://169.254.169.254/opc/v2/vnics/ | python3 -m json.tool
```

Find the primary interface and MAC:

```bash
PRIMARY_IF=$(ip -4 route show default | awk 'NR==1 {print $5}')
PRIMARY_MAC=$(cat "/sys/class/net/${PRIMARY_IF}/address" | tr '[:upper:]' '[:lower:]')
echo "PRIMARY_IF=${PRIMARY_IF}"
echo "PRIMARY_MAC=${PRIMARY_MAC}"
```

Find the secondary IP by skipping the primary VNIC MAC in OCI metadata:

```bash
SECONDARY_IP=$(
  PRIMARY_MAC="${PRIMARY_MAC}" python3 - <<'PY'
import json
import os
import urllib.request

primary_mac = os.environ["PRIMARY_MAC"].strip().lower()
req = urllib.request.Request(
    "http://169.254.169.254/opc/v2/vnics/",
    headers={"Authorization": "Bearer Oracle"},
)
with urllib.request.urlopen(req, timeout=5) as resp:
    vnics = json.load(resp)

for vnic in vnics:
    mac = (vnic.get("macAddr") or "").strip().lower()
    if not mac or mac == primary_mac:
        continue
    secondary_ips = vnic.get("secondaryPrivateIps") or []
    if isinstance(secondary_ips, list) and secondary_ips:
        print(str(secondary_ips[0]).strip())
    else:
        print((vnic.get("privateIp") or "").strip())
    break
PY
)

echo "SECONDARY_IP=${SECONDARY_IP}"
```

If `SECONDARY_IP` is empty, stop here and confirm the OCI secondary VNIC is attached.

Assign the secondary IP to `eth1` if it is not already present:

```bash
sudo ip link set "${SECONDARY_IF}" up
sudo ip addr replace "${SECONDARY_IP}/${SECONDARY_PREFIX}" dev "${SECONDARY_IF}"
ip -br addr show "${SECONDARY_IF}"
```

## 7. Configure The Libvirt Default Network

Pick a libvirt NAT subnet that does not conflict with existing host routes:

```bash
CANDIDATES="192.168.122.0/24 192.168.123.0/24 172.16.122.0/24"
LIBVIRT_NET=""

for cidr in ${CANDIDATES}; do
  if ! ip -4 route | awk '{print $1}' | grep -q "^${cidr}$"; then
    LIBVIRT_NET="${cidr}"
    break
  fi
done

if [ -z "${LIBVIRT_NET}" ]; then
  LIBVIRT_NET="192.168.122.0/24"
fi

echo "LIBVIRT_NET=${LIBVIRT_NET}"
```

Calculate the bridge IP and netmask:

```bash
LIBVIRT_GW=$(
  LIBVIRT_NET="${LIBVIRT_NET}" python3 - <<'PY'
import ipaddress
import os
net = ipaddress.ip_network(os.environ["LIBVIRT_NET"], strict=False)
print(str(next(net.hosts())))
PY
)

LIBVIRT_NETMASK=$(
  LIBVIRT_NET="${LIBVIRT_NET}" python3 - <<'PY'
import ipaddress
import os
net = ipaddress.ip_network(os.environ["LIBVIRT_NET"], strict=False)
print(str(net.netmask))
PY
)

echo "LIBVIRT_GW=${LIBVIRT_GW}"
echo "LIBVIRT_NETMASK=${LIBVIRT_NETMASK}"
```

Write the libvirt network XML:

```bash
cat > /tmp/default-net.xml <<EOF
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='${LIBVIRT_GW}' netmask='${LIBVIRT_NETMASK}'>
    <dhcp>
      <range start='${LIBVIRT_GW%.*}.2' end='${LIBVIRT_GW%.*}.254'/>
    </dhcp>
  </ip>
</network>
EOF
```

Define and start the network:

```bash
sudo virsh --connect qemu:///system net-destroy default 2>/dev/null || true
sudo virsh --connect qemu:///system net-undefine default 2>/dev/null || true
sudo virsh --connect qemu:///system net-define /tmp/default-net.xml
sudo virsh --connect qemu:///system net-start default
sudo virsh --connect qemu:///system net-autostart default
```

Verify:

```bash
sudo virsh --connect qemu:///system net-list --all
ip -br addr show virbr0
```

## 8. Configure Secondary VNIC Policy Routing

Find the secondary interface CIDR:

```bash
SECONDARY_CIDR=$(ip -o -4 addr show dev "${SECONDARY_IF}" | awk '{print $4}' | head -n1)
echo "SECONDARY_CIDR=${SECONDARY_CIDR}"
```

Find the directly connected subnet on `eth1`:

```bash
SECONDARY_SUBNET=$(ip -4 route show dev "${SECONDARY_IF}" proto kernel scope link | awk 'NR==1 {print $1}')

if [ -z "${SECONDARY_SUBNET}" ]; then
  SECONDARY_SUBNET="${SECONDARY_CIDR}"
fi

echo "SECONDARY_SUBNET=${SECONDARY_SUBNET}"
```

Calculate the subnet gateway. In OCI private subnets this is normally the first usable address:

```bash
SECONDARY_GW=$(
  SECONDARY_CIDR="${SECONDARY_CIDR}" python3 - <<'PY'
import ipaddress
import os
net = ipaddress.ip_interface(os.environ["SECONDARY_CIDR"]).network
print(str(next(net.hosts())))
PY
)

echo "SECONDARY_GW=${SECONDARY_GW}"
```

Register routing table `vnic2`:

```bash
grep -qE '^200[[:space:]]+vnic2$' /etc/iproute2/rt_tables 2>/dev/null || \
  echo '200 vnic2' | sudo tee -a /etc/iproute2/rt_tables
```

Add routes and rules:

```bash
sudo ip route replace "${SECONDARY_SUBNET}" dev "${SECONDARY_IF}" src "${SECONDARY_IP}" table vnic2
sudo ip route replace default via "${SECONDARY_GW}" dev "${SECONDARY_IF}" table vnic2
sudo ip rule add from "${SECONDARY_IP}/32" table vnic2 priority 1000 2>/dev/null || true
sudo ip rule add to "${SECONDARY_IP}/32" table vnic2 priority 1001 2>/dev/null || true
```

Set loose reverse-path filtering for multi-VNIC routing:

```bash
cat > /tmp/99-kove-mc-rpfilter.conf <<EOF
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.${PRIMARY_IF}.rp_filter=2
net.ipv4.conf.${SECONDARY_IF}.rp_filter=2
EOF

sudo cp /tmp/99-kove-mc-rpfilter.conf /etc/sysctl.d/99-kove-mc-rpfilter.conf
sudo sysctl -p /etc/sysctl.d/99-kove-mc-rpfilter.conf
```

Verify routing:

```bash
ip rule
ip route show table vnic2
```

## 9. Extract And Convert The OVA

Find the OVA:

```bash
OVA_PATH=$(find "${HOME}" -maxdepth 2 -type f -iname '*.ova' | sort | head -n1)
echo "OVA_PATH=${OVA_PATH}"
```

If `OVA_PATH` is empty, copy the OVA into the home directory and rerun the command.

Create a working directory:

```bash
mkdir -p ~/ova
```

Extract the OVA:

```bash
tar -xf "${OVA_PATH}" -C ~/ova
ls -lh ~/ova
```

Find the VMDK inside the OVA:

```bash
VMDK_PATH=$(find ~/ova -type f -iname '*.vmdk' | sort | head -n1)
echo "VMDK_PATH=${VMDK_PATH}"
```

Create the libvirt image directory:

```bash
sudo mkdir -p /var/lib/libvirt/images
```

Set the converted disk target:

```bash
DISK_PATH=/var/lib/libvirt/images/kove-mc.img
echo "DISK_PATH=${DISK_PATH}"
```

Convert the VMDK to the libvirt disk:

```bash
sudo qemu-img convert -p -f vmdk -O qcow2 "${VMDK_PATH}" "${DISK_PATH}"
sudo chown root:root "${DISK_PATH}"
sudo chmod 0644 "${DISK_PATH}"
sudo restorecon -Rv /var/lib/libvirt/images 2>/dev/null || true
```

Verify the disk:

```bash
sudo qemu-img info "${DISK_PATH}"
ls -lh "${DISK_PATH}"
```

## 10. Import The MC Guest

Set guest parameters:

```bash
VM_NAME=kove-mc
GUEST_MEMORY_MB=8192
GUEST_VCPUS=2
```

Stop and remove any existing guest with the same name:

```bash
sudo virsh --connect qemu:///system destroy "${VM_NAME}" 2>/dev/null || true
sudo virsh --connect qemu:///system undefine "${VM_NAME}" --nvram 2>/dev/null || \
  sudo virsh --connect qemu:///system undefine "${VM_NAME}" 2>/dev/null || true
```

Make sure the libvirt network is running:

```bash
sudo virsh --connect qemu:///system net-start default 2>/dev/null || true
sudo virsh --connect qemu:///system net-autostart default
```

Import the guest:

```bash
sudo virt-install --connect qemu:///system \
  --name "${VM_NAME}" \
  --memory "${GUEST_MEMORY_MB}" \
  --vcpus "${GUEST_VCPUS}" \
  --cpu Westmere,-svm,-x2apic,-tsc-deadline,-invtsc \
  --machine pc \
  --disk path="${DISK_PATH}",format=qcow2,bus=sata,target=sda \
  --network network=default,model=e1000 \
  --os-variant rhel8.7 \
  --graphics vnc,listen=127.0.0.1 \
  --serial pty \
  --console pty,target_type=serial \
  --import \
  --noautoconsole
```

Enable autostart:

```bash
sudo virsh --connect qemu:///system autostart "${VM_NAME}"
```

Verify the guest exists:

```bash
sudo virsh --connect qemu:///system list --all
```

## 11. Wait For The Guest IP

The MC guest gets its IP from the libvirt `default` network. Wait until libvirt reports a DHCP lease:

```bash
sudo virsh --connect qemu:///system domifaddr "${VM_NAME}" --source lease
```

If no IP appears, wait a few minutes and run it again.

Set `GUEST_IP` dynamically:

```bash
GUEST_IP=$(sudo virsh --connect qemu:///system domifaddr "${VM_NAME}" --source lease | awk '/ipv4/ {split($4,a,"/"); print a[1]; exit}')
echo "GUEST_IP=${GUEST_IP}"
```

If `GUEST_IP` is empty, do not continue to forwarding yet.

## 12. Enable IPv4 Forwarding

Enable forwarding now and persist it:

```bash
cat > /tmp/98-kove-mc-ipforward.conf <<'EOF'
net.ipv4.ip_forward=1
EOF

sudo cp /tmp/98-kove-mc-ipforward.conf /etc/sysctl.d/98-kove-mc-ipforward.conf
sudo sysctl -p /etc/sysctl.d/98-kove-mc-ipforward.conf
sudo sysctl -w net.ipv4.ip_forward=1
```

## 13. Add Guest Return Routing Rules

Discover the libvirt guest subnet:

```bash
GUEST_SUBNET=$(ip route show dev virbr0 scope link 2>/dev/null | awk 'NR==1 {print $1; exit}')

if [ -z "${GUEST_SUBNET}" ]; then
  GUEST_SUBNET="${LIBVIRT_NET}"
fi

echo "GUEST_SUBNET=${GUEST_SUBNET}"
```

Route guest-originated traffic through table `vnic2`:

```bash
sudo ip rule add iif virbr0 lookup vnic2 priority 998 2>/dev/null || true
sudo ip rule add from "${GUEST_SUBNET}" lookup vnic2 priority 999 2>/dev/null || true
```

Verify:

```bash
ip rule
```

## 14. Create nftables Tables And Chains

Create NAT table and chains:

```bash
sudo nft list table ip nat >/dev/null 2>&1 || sudo nft add table ip nat

sudo nft list chain ip nat PREROUTING >/dev/null 2>&1 || \
  sudo nft add chain ip nat PREROUTING '{ type nat hook prerouting priority dstnat; policy accept; }'

sudo nft list chain ip nat POSTROUTING >/dev/null 2>&1 || \
  sudo nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority srcnat; policy accept; }'
```

Create filter table and FORWARD chain:

```bash
sudo nft list table ip filter >/dev/null 2>&1 || sudo nft add table ip filter

sudo nft list chain ip filter FORWARD >/dev/null 2>&1 || \
  sudo nft add chain ip filter FORWARD '{ type filter hook forward priority filter; policy accept; }'
```

## 15. Add DNAT Rules On The Secondary VNIC

Forward SSH-on-2222 to guest SSH:

```bash
sudo nft add rule ip nat PREROUTING \
  iifname "${SECONDARY_IF}" \
  ip daddr "${SECONDARY_IP}" \
  tcp dport 2222 \
  counter dnat to "${GUEST_IP}:22"
```

Forward HTTPS 443:

```bash
sudo nft add rule ip nat PREROUTING \
  iifname "${SECONDARY_IF}" \
  ip daddr "${SECONDARY_IP}" \
  tcp dport 443 \
  counter dnat to "${GUEST_IP}:443"
```

Forward HTTPS alternate 8443:

```bash
sudo nft add rule ip nat PREROUTING \
  iifname "${SECONDARY_IF}" \
  ip daddr "${SECONDARY_IP}" \
  tcp dport 8443 \
  counter dnat to "${GUEST_IP}:8443"
```

## 16. Add SNAT/Masquerade For Guest Return Traffic

Add masquerade on the secondary VNIC:

```bash
sudo nft insert rule ip nat POSTROUTING position 0 \
  oifname "${SECONDARY_IF}" \
  ip saddr "${GUEST_SUBNET}" \
  counter masquerade \
  comment \"kove-guest-snat\"
```

## 17. Add FORWARD Accept Rules

Allow inbound forwarded SSH:

```bash
sudo nft insert rule ip filter FORWARD \
  oifname virbr0 \
  ip daddr "${GUEST_IP}" \
  tcp dport 22 \
  ct state new,established \
  counter accept

sudo nft insert rule ip filter FORWARD \
  iifname virbr0 \
  ip saddr "${GUEST_IP}" \
  tcp sport 22 \
  ct state established \
  counter accept
```

Allow inbound forwarded HTTPS 443:

```bash
sudo nft insert rule ip filter FORWARD \
  oifname virbr0 \
  ip daddr "${GUEST_IP}" \
  tcp dport 443 \
  ct state new,established \
  counter accept

sudo nft insert rule ip filter FORWARD \
  iifname virbr0 \
  ip saddr "${GUEST_IP}" \
  tcp sport 443 \
  ct state established \
  counter accept
```

Allow inbound forwarded HTTPS 8443:

```bash
sudo nft insert rule ip filter FORWARD \
  oifname virbr0 \
  ip daddr "${GUEST_IP}" \
  tcp dport 8443 \
  ct state new,established \
  counter accept

sudo nft insert rule ip filter FORWARD \
  iifname virbr0 \
  ip saddr "${GUEST_IP}" \
  tcp sport 8443 \
  ct state established \
  counter accept
```

## 18. Verify nftables

List relevant rules:

```bash
sudo nft list ruleset | grep -E '2222|8443|kove|dnat|masquerade' -n
```

Expected:

- DNAT rules on `eth1`.
- `ip daddr` matches the MC secondary VNIC IP.
- DNAT target matches the dynamic guest IP.
- POSTROUTING masquerade exists on `eth1`.

## 19. Test From The MC Host

Test the guest directly:

```bash
curl -k --connect-timeout 12 "https://${GUEST_IP}:8443/host_api/v1/fabric_type"
```

Expected response:

```text
"RoCE"
```

## 20. Test Through The Secondary VNIC

From a bastion or client that can reach the MC secondary VNIC IP:

```bash
curl -k --connect-timeout 15 "https://${SECONDARY_IP}:8443/host_api/v1/fabric_type"
```

For SSH to the guest through the MC host:

```bash
ssh -p 2222 <guest-user>@${SECONDARY_IP}
```

If testing from another shell where `SECONDARY_IP` is not set, replace it with the actual secondary VNIC private IP.

## 21. Reboot Notes

The manual commands above configure the current host state. After a reboot:

- libvirt network and guest autostart should persist.
- sysctl files should persist.
- nftables rules may not persist unless you save and enable an nftables ruleset.
- `ip rule` and `ip route table vnic2` rules may need to be reapplied unless you persist them with NetworkManager/systemd.

For a quick post-reboot repair, rerun sections 5, 6, 8, 11, 12, 13, 14, 15, 16, and 17.

## 22. Troubleshooting

| Symptom | What to check |
|---|---|
| OVA not found | `ls -lh ~/*.ova` |
| Plain `virsh` asks for a password | Use `sudo virsh --connect qemu:///system ...` |
| `eth1` missing | Confirm the secondary OCI VNIC is attached |
| `SECONDARY_IP` empty | Check `curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/` |
| `ip route show table vnic2` fails | Confirm `200 vnic2` exists in `/etc/iproute2/rt_tables` |
| Guest has no IP | Wait, then rerun `sudo virsh --connect qemu:///system domifaddr kove-mc --source lease` |
| Host reaches guest but client cannot | Check OCI security rules, DNAT rules, `ip_forward`, and masquerade |
| Duplicate nft rules | Use `sudo nft -a list ruleset`, delete duplicate handles, then re-add only the missing rules |
| `qemu-img convert` fails | Confirm the OVA contains a VMDK: `tar -tf ~/kove-mc-2503-mcvirt.ova | grep -i vmdk` |

## 23. Offline Package Note

If the MC host cannot use public package repositories, install these packages from your internal mirror or offline RPM bundle before continuing:

```bash
qemu-kvm libvirt-daemon-kvm libvirt libvirt-client virt-install qemu-img python3 nftables tar
```
