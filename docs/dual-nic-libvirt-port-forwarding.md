# Dual NIC + Libvirt NAT Port Forwarding (Quick Steps)

This setup forwards traffic arriving on a host secondary NIC IP to a guest VM on `virbr0` (`192.168.122.0/24`).

## 1) Verify current network layout

```bash
ip -br addr
ip route
ip rule
sudo virsh --connect qemu:///system domiflist kove-mc
sudo virsh --connect qemu:///system net-dumpxml default
```

Expected:
- Host secondary NIC IP: `10.0.2.58` (example)
- Guest on libvirt NAT network: `192.168.122.237` (example)

## 2) Enable IPv4 forwarding

```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf
```

## 3) Add DNAT rules (secondary IP -> guest)

Example ports: `2222 -> 22`, `443 -> 443`, `8443 -> 8443`

```bash
sudo nft add rule ip nat PREROUTING iifname "eth1" ip daddr 10.0.2.58 tcp dport 2222 counter dnat to 192.168.122.237:22
sudo nft add rule ip nat PREROUTING iifname "eth1" ip daddr 10.0.2.58 tcp dport 443  counter dnat to 192.168.122.237:443
sudo nft add rule ip nat PREROUTING iifname "eth1" ip daddr 10.0.2.58 tcp dport 8443 counter dnat to 192.168.122.237:8443
```

## 4) Add FORWARD allow rules

```bash
sudo nft insert rule ip filter FORWARD oifname "virbr0" ip daddr 192.168.122.237 tcp dport 22   ct state new,established counter accept
sudo nft insert rule ip filter FORWARD iifname "virbr0" ip saddr 192.168.122.237 tcp sport 22   ct state established counter accept

sudo nft insert rule ip filter FORWARD oifname "virbr0" ip daddr 192.168.122.237 tcp dport 443  ct state new,established counter accept
sudo nft insert rule ip filter FORWARD iifname "virbr0" ip saddr 192.168.122.237 tcp sport 443  ct state established counter accept

sudo nft insert rule ip filter FORWARD oifname "virbr0" ip daddr 192.168.122.237 tcp dport 8443 ct state new,established counter accept
sudo nft insert rule ip filter FORWARD iifname "virbr0" ip saddr 192.168.122.237 tcp sport 8443 ct state established counter accept
```

## 5) Add policy routing for dual NIC return path

These rules make forwarded guest traffic return out secondary NIC (`eth1`/`10.0.2.58`):

```bash
sudo ip route add 10.0.1.0/24 via 10.0.2.1 dev eth1 table vnic2
sudo ip rule add iif virbr0 lookup vnic2 priority 998
sudo ip rule add from 192.168.122.0/24 lookup vnic2 priority 999
```

Adjust `10.0.1.0/24` to your client/source subnet.

## 6) Validate

```bash
sudo nft list chain ip nat PREROUTING
sudo nft list chain ip filter FORWARD
ip route get 10.0.1.21 iif virbr0 from 192.168.122.237
```

Client tests:

```bash
ssh -p 2222 <guest-user>@10.0.2.58
curl -vk https://10.0.2.58/
curl -vk https://10.0.2.58:8443/
```

## 7) OCI security list checks

- Ingress on host subnet allows needed ports from source CIDR (stateful preferred).
- Egress allows return traffic (or equivalent stateless return rules).
- If asymmetric routing persists, verify source subnet/client-side rules too.

## 8) Persistence reminder

- `nft` rules added manually are runtime unless saved/restored by your OS tooling.
- `ip rule` / `ip route` commands are runtime unless persisted in network config.

