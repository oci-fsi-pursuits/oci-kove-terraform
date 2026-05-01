#!/usr/bin/env bash
set -euo pipefail

# Complete MC setup helper based on docs/complete-mc-setup.md
# Safe defaults + env overrides. Run as root on the MC host.

[[ "${EUID}" -eq 0 ]] || { echo "Run as root (sudo)."; exit 1; }

SEC_IF="${SEC_IF:-eth1}"
SEC_IP="${SEC_IP:-}"
SEC_PREFIX="${SEC_PREFIX:-24}"
GW="${GW:-}"
SEC_SUBNET_CIDR="${SEC_SUBNET_CIDR:-}"
CLIENT_SUBNET_CIDR="${CLIENT_SUBNET_CIDR:-}"
LIBVIRT_SUBNET_CIDR="${LIBVIRT_SUBNET_CIDR:-192.168.122.0/24}"
TABLE="${TABLE:-vnic2}"
MAP_ID="${MAP_ID:-200}"
GUEST_VM="${GUEST_VM:-kove-mc}"
GUEST_IP="${GUEST_IP:-}"

log(){ echo "[mc-setup] $*"; }

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1"; exit 1; }; }
for c in dnf ip nft systemctl virsh awk sed; do need "$c"; done

install_pkgs() {
  log "Installing KVM/libvirt/nftables packages"
  dnf -y install qemu-kvm libvirt-daemon-kvm libvirt virt-install libguestfs-tools-c nftables tcpdump --nobest
}

start_libvirt() {
  log "Starting libvirt services"
  if systemctl list-unit-files | grep -q '^libvirtd.service'; then
    systemctl enable --now libvirtd
  else
    systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
  fi
}

configure_secondary_if() {
  [[ -n "$SEC_IP" ]] || { log "SEC_IP not set; skipping nmcli config"; return 0; }
  if command -v nmcli >/dev/null 2>&1; then
    log "Configuring secondary NIC ${SEC_IF} with ${SEC_IP}/${SEC_PREFIX}"
    nmcli con show secondary-vnic >/dev/null 2>&1 || \
      nmcli connection add type ethernet con-name secondary-vnic ifname "$SEC_IF" \
        ipv4.method manual ipv4.addresses "${SEC_IP}/${SEC_PREFIX}" ipv4.never-default yes ipv6.method ignore autoconnect yes
    nmcli con modify secondary-vnic ipv4.addresses "${SEC_IP}/${SEC_PREFIX}" ipv4.never-default yes ipv6.method ignore
    nmcli con up secondary-vnic || true
  fi
}

enable_ip_forward() {
  log "Enabling IPv4 forwarding"
  sysctl -w net.ipv4.ip_forward=1
  echo 'net.ipv4.ip_forward = 1' >/etc/sysctl.d/99-kvm-forward.conf
  sysctl --system >/dev/null || true
}

configure_policy_routing() {
  [[ -n "$SEC_IP" && -n "$GW" && -n "$SEC_SUBNET_CIDR" && -n "$CLIENT_SUBNET_CIDR" ]] || {
    log "Routing vars incomplete; skipping policy routing"; return 0;
  }
  log "Configuring policy routing table ${TABLE} (${MAP_ID})"
  grep -q "^${MAP_ID} ${TABLE}$" /etc/iproute2/rt_tables || echo "${MAP_ID} ${TABLE}" >> /etc/iproute2/rt_tables
  ip route replace "$SEC_SUBNET_CIDR" dev "$SEC_IF" src "$SEC_IP" table "$TABLE"
  ip route replace "$CLIENT_SUBNET_CIDR" via "$GW" dev "$SEC_IF" table "$TABLE" || true
  ip route replace default via "$GW" dev "$SEC_IF" table "$TABLE" || ip route replace "$GW/32" dev "$SEC_IF" table "$TABLE"
  ip rule add iif virbr0 lookup "$TABLE" priority 998 2>/dev/null || true
  ip rule add from "$LIBVIRT_SUBNET_CIDR" lookup "$TABLE" priority 999 2>/dev/null || true
}

ensure_default_libvirt_net() {
  log "Ensuring libvirt default network is active"
  virsh --connect qemu:///system net-start default 2>/dev/null || true
  virsh --connect qemu:///system net-autostart default || true
}

resolve_guest_ip() {
  if [[ -z "$GUEST_IP" ]]; then
    GUEST_IP="$(virsh --connect qemu:///system domifaddr "$GUEST_VM" --source lease 2>/dev/null | awk '/ipv4/ {split($4,a,"/"); print a[1]; exit}')"
  fi
  [[ -n "$GUEST_IP" ]] || GUEST_IP="$(virsh --connect qemu:///system net-dhcp-leases default 2>/dev/null | awk '/ipv4/ {split($5,a,"/"); print a[1]; exit}')"
}

add_rule_if_missing() {
  local list_cmd="$1"; shift
  local grep_text="$1"; shift
  if ! eval "$list_cmd" | grep -Fq "$grep_text"; then
    eval "$*"
  fi
}

configure_nft_port_forwarding() {
  resolve_guest_ip
  [[ -n "$GUEST_IP" ]] || { log "Guest IP not found; skipping nft setup"; return 0; }
  [[ -n "$SEC_IP" ]] || { log "SEC_IP not set; skipping nft setup"; return 0; }

  log "Applying nftables DNAT/FORWARD rules for guest ${GUEST_IP}"
  nft list table ip nat >/dev/null 2>&1 || nft add table ip nat
  nft list chain ip nat PREROUTING >/dev/null 2>&1 || nft add chain ip nat PREROUTING '{ type nat hook prerouting priority dstnat; policy accept; }'
  nft list table ip filter >/dev/null 2>&1 || nft add table ip filter
  nft list chain ip filter FORWARD >/dev/null 2>&1 || nft add chain ip filter FORWARD '{ type filter hook forward priority filter; policy accept; }'

  add_rule_if_missing "nft list chain ip nat PREROUTING" "tcp dport 2222" \
    "nft add rule ip nat PREROUTING iifname \"$SEC_IF\" ip daddr \"$SEC_IP\" tcp dport 2222 counter dnat to \"$GUEST_IP\":22"
  add_rule_if_missing "nft list chain ip nat PREROUTING" "tcp dport 443" \
    "nft add rule ip nat PREROUTING iifname \"$SEC_IF\" ip daddr \"$SEC_IP\" tcp dport 443 counter dnat to \"$GUEST_IP\":443"
  add_rule_if_missing "nft list chain ip nat PREROUTING" "tcp dport 8443" \
    "nft add rule ip nat PREROUTING iifname \"$SEC_IF\" ip daddr \"$SEC_IP\" tcp dport 8443 counter dnat to \"$GUEST_IP\":8443"

  add_rule_if_missing "nft list chain ip filter FORWARD" "tcp dport 22 ct state new,established" \
    "nft insert rule ip filter FORWARD oifname virbr0 ip daddr \"$GUEST_IP\" tcp dport 22 ct state new,established counter accept"
  add_rule_if_missing "nft list chain ip filter FORWARD" "tcp dport 443 ct state new,established" \
    "nft insert rule ip filter FORWARD oifname virbr0 ip daddr \"$GUEST_IP\" tcp dport 443 ct state new,established counter accept"
  add_rule_if_missing "nft list chain ip filter FORWARD" "tcp dport 8443 ct state new,established" \
    "nft insert rule ip filter FORWARD oifname virbr0 ip daddr \"$GUEST_IP\" tcp dport 8443 ct state new,established counter accept"
}

main() {
  install_pkgs
  start_libvirt
  configure_secondary_if
  ensure_default_libvirt_net
  enable_ip_forward
  configure_policy_routing
  configure_nft_port_forwarding
  log "Complete. Validate with: virsh domifaddr ${GUEST_VM}, nft list chain ip nat PREROUTING"
}

main "$@"
