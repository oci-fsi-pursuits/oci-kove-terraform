# RHEL KVM host with libvirt NAT and dual-NIC port forwarding

This document consolidates a working pattern for **Red Hat Enterprise Linux 8** (and similar RHEL-family images) where:

- The hypervisor uses **libvirt’s default NAT** network (`default` / `virbr0`, typically `192.168.122.0/24` unless customized).
- A **secondary physical or cloud VNIC** owns a dedicated **service IP** used for inbound connections.
- **nftables** performs **DNAT** from that service IP to a **single guest** on the NAT segment.
- **Policy routing** ensures return traffic from guests toward clients uses the **secondary uplink** symmetrically.

All addresses below are **placeholders**. Replace them with values from your environment (`ip -br addr`, subnet documentation, and `virsh net-dumpxml default`). Do not commit real keys, tenancy identifiers, or internal hostnames into shared documentation.

---

## 1. Roles and traffic paths

| Role | Typical example | Meaning |
|------|------------------|--------|
| `PRI_IF` / `PRI_IP` | `eth0`, `10.0.0.10/24` | Primary management or default route interface |
| `SEC_IF` / `SEC_IP` | `eth1`, `10.0.0.50/24` | Secondary interface and **public-facing private IP** for forwarded services |
| `GW` | `10.0.0.1` | Default gateway for the **secondary subnet** (confirm in cloud or on-prem subnet settings) |
| `GUEST_IP` | `192.168.122.N` | Guest address on libvirt NAT (from DHCP or static guest config) |
| `LIBVIRT_SUBNET_CIDR` | `192.168.122.0/24` | NAT segment in use by `default` (see `virsh net-dumpxml default`) |
| `CLIENT_SUBNET_CIDR` | e.g. `10.0.1.0/24` | CIDR where clients or bastions originate (adjust to your east–west paths) |

**North–south:** client → cloud security rules → `SEC_IP` → host **nft** DNAT → `GUEST_IP`.

**East–west return:** guest → `virbr0` → host routing → `SEC_IF` → clients (policy routing avoids hairpins through `PRI_IF` when that would break symmetry).

---

## 2. Cloud or data-plane prerequisites (before host commands)

1. Attach a **secondary VNIC** (or physical NIC) with static **`SEC_IP`** on the intended subnet.
2. **Security groups / NSGs / security lists:** allow inbound TCP to `SEC_IP` on the ports you forward (examples: `2222` → guest `22`, `443`, `8443`).
3. Where the platform supports it, enable **skip source/destination check** (or equivalent) on the secondary attachment when the host performs **forwarding/NAT** for another IP.
4. Confirm **route tables** for the secondary subnet send traffic toward your instance as expected.

---

## 3. OS baseline and SSH user

RHEL marketplace or generic RHEL cloud images often default to the **`cloud-user`** account for SSH, with `sudo` configured. Oracle Linux images may use **`opc`** instead—use the account your image documents.

```bash
ssh -i /path/to/your_key.pem cloud-user@<KVM_HOST_IP>
```

---

## 4. Install KVM and libvirt (RHEL 8)

### 4.1 Preferred: modular packages aligned with your minor release

If `dnf groupinstall "Virtualization Host"` fails with dependency conflicts, your repos may be skewed relative to the running kernel userspace. Options used successfully in the field:

- Align **subscription release** (or repo `releasever`) with the installed minor release, then retry; or  
- Install core packages with **`--nobest`** so DNF can pick a consistent set:

```bash
sudo dnf -y install qemu-kvm libvirt-daemon-kvm libvirt virt-install libguestfs-tools-c nftables tcpdump --nobest
```

`bridge-utils` is optional on RHEL 8 (often absent from default repos); omit it or install an equivalent if your playbooks require it.

### 4.2 Start libvirt

RHEL 8 commonly still uses **`libvirtd`**:

```bash
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  sudo systemctl enable --now libvirtd
else
  sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
fi
```

### 4.3 Validation

```bash
ls -l /dev/kvm
sudo virt-host-validate
sudo virsh --connect qemu:///system net-list --all
```

Ensure **`default`** is **active** and **autostart** yes. If you must redefine it, use a static XML definition (bridge name, `192.168.122.1/24`, DHCP range) consistent with your org standard.

### 4.4 Optional: non-root `virsh`

```bash
sudo usermod -aG libvirt cloud-user
# log out and back in for group membership to apply
```

---

## 5. Secondary NIC: Layer-3 on the host

Identify `SEC_IF` with `ip -br addr`. Configure **`SEC_IP`** without introducing a second default route on the same metric as the primary (common pattern: **`ipv4.never-default yes`** on the secondary profile when both NICs share a routing domain).

**NetworkManager example** (same broadcast domain as primary; adjust names and addresses):

```bash
sudo nmcli connection add type ethernet con-name secondary-vnic ifname "${SEC_IF}" \
  ipv4.method manual ipv4.addresses "${SEC_IP}/${PREFIX}" \
  ipv4.never-default yes ipv6.method ignore autoconnect yes
sudo nmcli connection up secondary-vnic
```

If the secondary subnet uses a different gateway or `/32` style addressing, follow your cloud provider’s documentation for **onlink** routes and metadata-derived gateways.

---

## 6. IPv4 forwarding

```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-kvm-forward.conf >/dev/null
sudo sysctl --system
sysctl net.ipv4.ip_forward
```

---

## 7. Policy routing (symmetric return path)

Pick an unused **`rt_tables`** ID and name, for example `MAP_ID=200`, `TABLE=vnic2`.

### What each variable means (read this before filling values)

| Variable | What it is | **Not** |
|----------|------------|--------|
| `SEC_IP` / `SEC_IF` | Private IP and Linux interface for the **secondary VNIC** on the KVM host | Not the guest IP |
| `GW` | Default gateway for traffic leaving via **`SEC_IF`** (often subnet `.1`; confirm in subnet details) | Not `virbr0` |
| `SEC_SUBNET_CIDR` | The **L3 subnet** that contains **`SEC_IP`** (-CIDR form, e.g. `/24`) | Not `192.168.122.0/24` unless your secondary really is on that segment |
| `LIBVIRT_SUBNET_CIDR` | The libvirt **NAT** segment behind **`virbr0`** | Always take from `virsh net-dumpxml default` — typically `192.168.122.0/24` if you kept defaults |
| `CLIENT_SUBNET_CIDR` | **Where clients originate** when they hit **`SEC_IP`** (bastion subnet, jump box subnet, peer workload subnet). Used so replies from the guest can take the **secondary uplink** back to those clients. | **Not** the libvirt virtual network (that is `LIBVIRT_SUBNET_CIDR`) |

**Environment file** (example path `/etc/kvm-secondary-routing.env`):

```bash
SEC_IP=<your-secondary-ip>
SEC_IF=<your-secondary-if>
GW=<your-secondary-subnet-gateway>
SEC_SUBNET_CIDR=<your-secondary-subnet-cidr>
CLIENT_SUBNET_CIDR=<cidr-where-clients-live>
LIBVIRT_SUBNET_CIDR=<from virsh net-dumpxml default>
TABLE=vnic2
MAP_ID=200
```

**Examples (patterns we have used — replace with your real CIDRs):**

**Example A — bastion and KVM secondary on the same cloud subnet (common lab layout)**

- `SEC_IP=10.0.2.158`, `SEC_IF=eth1`, `GW=10.0.2.1`
- `SEC_SUBNET_CIDR=10.0.2.0/24`
- You curl from the bastion using `https://10.0.2.158:8443/...` and the bastion is also in `10.0.2.0/24`:

```bash
CLIENT_SUBNET_CIDR=10.0.2.0/24
LIBVIRT_SUBNET_CIDR=192.168.122.0/24   # confirm: sudo virsh net-dumpxml default
```

**Example B — clients live in a different VCN/subnet than `SEC_IP` (typical east–west)**

If your bastion is e.g. `10.0.5.0/24` but `SEC_IP` is `10.0.2.0/24`, set:

```bash
CLIENT_SUBNET_CIDR=10.0.5.0/24
```

Use the **actual** subnet CIDR of the machines that will call `SEC_IP`.

**One-shot apply logic** (run as root after `network-online` and `libvirtd`):

1. Append `${MAP_ID} ${TABLE}` to `/etc/iproute2/rt_tables` if missing.  
2. `ip route replace` the connected / default / client routes into `table ${TABLE}`.  
3. If `default via ${GW}` fails on some clouds, use the **`${GW}/32` dev `${SEC_IF}`** plus **`default via ${GW} onlink`** pattern from your runbook.  
4. Add policy rules, for example:

```bash
sudo ip rule add iif virbr0 lookup "${TABLE}" priority 998 2>/dev/null || true
sudo ip rule add from "${LIBVIRT_SUBNET_CIDR}" lookup "${TABLE}" priority 999 2>/dev/null || true
```

**Persistence:** use a **`systemd` oneshot** unit (`RemainAfterExit=yes`) sourced from the env file, or NetworkManager **routing-policy-rule** keys—match your operational standard.

---

## 8. nftables: DNAT and FORWARD permits

Libvirt installs **`LIBVIRT_*` jumps** on **`filter/FORWARD`**. Insert **accept** rules **ahead** of those jumps for traffic to/from `GUEST_IP` on the forwarded ports.

**PREROUTING DNAT** (examples; duplicate lines cover both “arrived on `SEC_IF`” and “destination is `SEC_IP`” cases):

- `2222/tcp` → guest `22/tcp`  
- `443/tcp` → guest `443/tcp`  
- `8443/tcp` → guest `8443/tcp`  

**nftables version note:** RHEL 8 ships **nftables 0.9.x**. Avoid **`meta comment`** in rule text if your version rejects it; use an external idempotency check (for example, test whether `nft list chain ip nat PREROUTING` already contains `dnat to ${GUEST_IP}:22`).

**Firewalld:** if **`firewalld`** is active, raw **`ip nat` / `ip filter`** rules often coexist, but validate in your environment. Prefer a controlled change window.

**Idempotency:** before adding rules, grep the live ruleset for an existing DNAT to the same **`GUEST_IP:22`**, then skip or replace deliberately.

---

## 9. After the guest exists: set `GUEST_IP` and apply forwarding

1. Create or import the guest attached to **`network=default`**.  
2. Obtain **`GUEST_IP`**:

   ```bash
   sudo virsh --connect qemu:///system domifaddr <guest-name> --full
   ```

3. Write **`GUEST_IP`** into a small env file (example `/etc/kvm-port-forward.env`) sourced by your apply script.  
4. Run the apply script **once** as root, or restart the associated **`systemd` oneshot** service.

**Validation:**

- From the host, bypass DNAT: `curl -vk "https://${GUEST_IP}/"`  
- From a **remote** client: `curl -vk "https://${SEC_IP}/"` and `ssh -p 2222 user@${SEC_IP}`  

Hairpin tests from the host to its own `SEC_IP` may not traverse **PREROUTING**; treat remote tests as authoritative, or add **OUTPUT** DNAT only if required.

---

## 10. Guest-side requirements

Host DNAT cannot create listeners in the guest. Ensure **sshd** and application ports (**443**, **8443**, etc.) are enabled in the guest firewall and services.

If the disk is **LUKS-encrypted** and you cannot boot interactively, offline **`virt-customize`** requires **keys**; plan unlock paths accordingly.

---

## 11. Persistence checklist

| Item | Typical persistence |
|------|------------------------|
| `ip_forward` | `/etc/sysctl.d/*.conf` |
| `SEC_IF` address | NetworkManager connection profile |
| Policy routes / rules | `systemd` oneshot or NM policy routing |
| nft rules | Apply script + oneshot, or org-standard **`nftables`** unit and include files |

---

## 12. Troubleshooting

| Symptom | Checks |
|---------|--------|
| No SYN on host | Cloud security rules, wrong `SEC_IP`, wrong subnet |
| SYN but no steady session | Asymmetric routing; **`ip route show table ${TABLE}`**, **`ip rule`**, skip src/dst check |
| Host → guest works, remote fails | Missing DNAT or **FORWARD** allows; confirm **`GUEST_IP`** |
| `dnf` conflicts on install | Minor-release alignment; **`--nobest`**; avoid mixing stale module streams |

---

## 13. End-to-end guest import from OVA

This section is the full workflow from bastion to a running guest.

### 13.1 Copy OVA to the KVM host

From bastion:

```bash
scp -i ~/.ssh/<host_key.pem> /path/to/kove-mc-2503-mcvirt.ova \
  cloud-user@<KVM_HOST_IP>:~/
```

Verify on host:

```bash
ls -lh ~/kove-mc-2503-mcvirt.ova
```

### 13.2 Extract and convert VMDK -> qcow2

```bash
mkdir -p ~/ova && cd ~/ova
tar -xf ~/kove-mc-2503-mcvirt.ova
ls -lh *.vmdk *.ovf

sudo mkdir -p /var/lib/libvirt/images
sudo qemu-img convert -p -f vmdk -O qcow2 \
  ~/ova/kove-mc-1.vmdk /var/lib/libvirt/images/kove-mc.qcow2
sudo restorecon -Rv /var/lib/libvirt/images
sudo ls -lh /var/lib/libvirt/images/kove-mc.qcow2
```

### 13.3 Create/import VM

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
  --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
  --import \
  --noautoconsole

sudo virsh --connect qemu:///system autostart kove-mc
sudo virsh --connect qemu:///system list --all
```

### 13.4 Discover guest IP and apply forwarding

```bash
sudo virsh --connect qemu:///system domifaddr kove-mc --full
```

Set discovered IPv4 as `GUEST_IP` (example shown):

```bash
echo 'GUEST_IP=192.168.122.106' | sudo tee /etc/kvm-port-forward.env >/dev/null
sudo systemctl restart kvm-port-forward.service
sudo nft list chain ip nat PREROUTING
```

### 13.5 Console access when the guest is not ready

If services are not listening yet, check unlock/login via:

```bash
sudo virsh console kove-mc
sudo virsh vncdisplay kove-mc
```

If the image uses LUKS, you may need interactive unlock on console before API checks pass.

## 14. Required validation checks (including fabric type API)

Use this exact order:

1. Guest direct test from host (proves guest service readiness):

```bash
curl -k --connect-timeout 12 \
  https://<GUEST_IP>:8443/host_api/v1/fabric_type
```

2. End-to-end forwarded test from bastion/client (proves DNAT + policy routing):

```bash
curl -k --connect-timeout 15 \
  https://<secondaryIP>:8443/host_api/v1/fabric_type
```

Expected success example body:

```text
"RoCE"
```

If step 1 fails but step 2 works later, the guest likely needed additional boot time.  
If both fail, troubleshoot in this order: guest listener -> nft DNAT/FORWARD -> policy routes -> cloud security rules.

---

## 15. Related advanced topics

- **Guest agent** and `qemu-agent-command` automation  
- Disk rebuild and `virsh define` XML edits  
- Optional VNC tunnel workflows through jump hosts
