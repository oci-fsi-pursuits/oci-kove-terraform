#cloud-config
package_update: false
package_upgrade: false

write_files:
  - path: /etc/kove/mc-instance.conf
    owner: root:root
    permissions: "0644"
    content: |
      KOVE_GUEST_VM_NAME=${jsonencode(guest_vm_name)}
      KOVE_GUEST_DISK_PATH=${jsonencode(guest_disk_path)}
      KOVE_GUEST_VCPUS=${jsonencode(guest_vcpus)}
      KOVE_GUEST_MEMORY_MB=${jsonencode(guest_memory_mb)}
      KOVE_SETUP_SCRIPT_PATH=${jsonencode(setup_script_path)}
      KOVE_SECONDARY_VNIC_IF=${jsonencode(try(secondary_vnic_interface, ""))}
      KOVE_SECONDARY_PRIVATE_IP=${jsonencode(try(secondary_vnic_private_ip, ""))}
      KOVE_SECONDARY_PREFIX=${jsonencode(try(secondary_vnic_prefix, "24"))}
      KOVE_SECONDARY_ENABLED=${format("%t", try(secondary_vnic_enabled, length(trimspace(try(secondary_vnic_interface, ""))) > 0))}

  - path: /usr/local/sbin/kove-oci-resolve-secondary.py
    owner: root:root
    permissions: "0755"
    content: |
      #!/usr/bin/env python3
      """Resolve secondary OCI VNIC by matching IMDS VNIC MACs to sysfs."""
      import json
      import pathlib
      import subprocess
      import sys
      import urllib.error
      import urllib.request
      from typing import List

      def vnics() -> List[dict]:
          for url, headers in (
              ("http://169.254.169.254/opc/v2/vnics/", {"Authorization": "Bearer Oracle"}),
              ("http://169.254.169.254/opc/v1/vnics/", {}),
          ):
              req = urllib.request.Request(url, headers=headers)
              try:
                  with urllib.request.urlopen(req, timeout=3) as resp:
                      data = json.load(resp)
                      if isinstance(data, list):
                          return data
              except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError):
                  continue
          return []

      def default_dev() -> str:
          try:
              out = subprocess.check_output(
                  ["ip", "-4", "route", "show", "default"],
                  universal_newlines=True,
                  timeout=5,
              )
          except (subprocess.CalledProcessError, FileNotFoundError):
              return ""
          parts = out.split()
          if "dev" in parts:
              i = parts.index("dev")
              if i + 1 < len(parts):
                  return parts[i + 1]
          return ""

      def mac_for(dev: str) -> str:
          p = pathlib.Path("/sys/class/net") / dev / "address"
          try:
              return p.read_text().strip().lower()
          except OSError:
              return ""

      def ifnames_for_mac(target: str) -> List[str]:
          target = target.strip().lower()
          out: List[str] = []
          base = pathlib.Path("/sys/class/net")
          if not base.is_dir():
              return out
          for child in base.iterdir():
              name = child.name
              if name == "lo":
                  continue
              try:
                  m = (child / "address").read_text().strip().lower()
              except OSError:
                  continue
              if m == target:
                  out.append(name)
          return out

      def pick_ip(v: dict) -> str:
          pip = (v.get("privateIp") or "").strip()
          secs = v.get("secondaryPrivateIps") or []
          if isinstance(secs, list) and secs:
              s0 = str(secs[0]).strip()
              if s0:
                  return s0
          return pip

      def main() -> None:
          mode = sys.argv[1] if len(sys.argv) > 1 else "ifname"
          prim = default_dev()
          pm = mac_for(prim) if prim else ""
          for v in vnics():
              mac = (v.get("macAddr") or "").strip().lower()
              if not mac or mac == pm:
                  continue
              names = ifnames_for_mac(mac)
              if not names:
                  continue
              ifname = names[0]
              if prim and ifname == prim and len(names) > 1:
                  ifname = names[1]
              ip = pick_ip(v)
              if mode == "ifname":
                  print(ifname)
              elif mode == "ip":
                  print(ip)
              else:
                  print(f"{ifname} {ip}")
              return
          print("")

      if __name__ == "__main__":
          main()

  - path: /usr/local/sbin/oci-vnic2-routing.sh
    owner: root:root
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      CONF=/etc/kove/mc-instance.conf
      if [[ -f "$CONF" ]]; then
        set -a
        # shellcheck disable=SC1090
        . "$CONF"
        set +a
      fi
      [[ "$${KOVE_SECONDARY_ENABLED:-false}" == "true" ]] || exit 0
      SECONDARY_IF="$${KOVE_SECONDARY_VNIC_IF:-}"
      if [[ -z "$${SECONDARY_IF}" && "$${KOVE_SECONDARY_ENABLED:-false}" == "true" ]]; then
        SECONDARY_IF="$(/usr/local/sbin/kove-oci-resolve-secondary.py ifname 2>/dev/null || true)"
      fi
      if [[ -z "$${SECONDARY_IF}" ]]; then SECONDARY_IF="${secondary_vnic_interface}"; fi
      TABLE_ID=200
      TABLE_NAME=vnic2
      if ! ip link show "$${SECONDARY_IF}" >/dev/null 2>&1; then exit 0; fi
      ip link set "$${SECONDARY_IF}" up || true
      SECONDARY_CIDR="$(ip -o -4 addr show dev "$${SECONDARY_IF}" | awk '{print $4}' | head -n1)"
      if [[ -z "$${SECONDARY_CIDR}" ]]; then
        META_IP="$${KOVE_SECONDARY_PRIVATE_IP:-}"
        if [[ -z "$${META_IP}" ]]; then
          META_IP="$(/usr/local/sbin/kove-oci-resolve-secondary.py ip 2>/dev/null || true)"
        fi
        if [[ -n "$${META_IP}" ]]; then
          ip addr replace "$${META_IP}/$${KOVE_SECONDARY_PREFIX:-24}" dev "$${SECONDARY_IF}" 2>/dev/null || true
          SECONDARY_CIDR="$(ip -o -4 addr show dev "$${SECONDARY_IF}" | awk '{print $4}' | head -n1)"
        fi
      fi
      if [[ -z "$${SECONDARY_CIDR}" ]]; then exit 0; fi
      SECONDARY_IP="$${SECONDARY_CIDR%/*}"
      SUBNET_CIDR="$(ip -4 route show dev "$${SECONDARY_IF}" proto kernel scope link | awk 'NR==1 {print $1}')"
      [[ -z "$${SUBNET_CIDR}" ]] && SUBNET_CIDR="$${SECONDARY_CIDR}"
      SECONDARY_GW="$(ip route | awk -v dev="$${SECONDARY_IF}" '$1=="default" && $0~("dev " dev){print $3; exit}')"
      if [[ -z "$${SECONDARY_GW}" ]]; then
        export SECONDARY_CIDR
        SECONDARY_GW="$(python3 - <<'PY'
      import ipaddress, os
      net = ipaddress.ip_interface(os.environ['SECONDARY_CIDR']).network
      print(next(net.hosts()))
      PY
      )"
      fi
      awk -v tid="$${TABLE_ID}" -v tn="$${TABLE_NAME}" '$1==tid && $2==tn {found=1} END{exit !found}' /etc/iproute2/rt_tables 2>/dev/null || echo "$${TABLE_ID} $${TABLE_NAME}" >> /etc/iproute2/rt_tables
      ip route replace "$${SUBNET_CIDR}" dev "$${SECONDARY_IF}" src "$${SECONDARY_IP}" table "$${TABLE_NAME}"
      ip route replace default via "$${SECONDARY_GW}" dev "$${SECONDARY_IF}" table "$${TABLE_NAME}"
      ip rule add from "$${SECONDARY_IP}/32" table "$${TABLE_NAME}" priority 1000 2>/dev/null || true
      ip rule add to "$${SECONDARY_IP}/32" table "$${TABLE_NAME}" priority 1001 2>/dev/null || true
      PRIMARY_IF="$(ip -4 route show default | awk 'NR==1 {print $5}')"
      [[ -z "$${PRIMARY_IF}" ]] && PRIMARY_IF="eth0"
      cat >/etc/sysctl.d/99-kove-multi-vnic.conf <<SYSCTL
      net.ipv4.conf.all.rp_filter=2
      net.ipv4.conf.default.rp_filter=2
      net.ipv4.conf.$${PRIMARY_IF}.rp_filter=2
      net.ipv4.conf.$${SECONDARY_IF}.rp_filter=2
      SYSCTL
      sysctl --system >/dev/null 2>&1 || true

  - path: /usr/local/sbin/oci-mc-port-forwarding.sh
    owner: root:root
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      CONF=/etc/kove/mc-instance.conf
      if [[ -f "$CONF" ]]; then
        set -a
        # shellcheck disable=SC1090
        . "$CONF"
        set +a
      fi
      [[ "$${KOVE_SECONDARY_ENABLED:-false}" == "true" ]] || exit 0
      GUEST_VM="$${KOVE_GUEST_VM_NAME:-${guest_vm_name}}"
      SECONDARY_IF="$${KOVE_SECONDARY_VNIC_IF:-}"
      if [[ -z "$${SECONDARY_IF}" && "$${KOVE_SECONDARY_ENABLED:-false}" == "true" ]]; then
        SECONDARY_IF="$(/usr/local/sbin/kove-oci-resolve-secondary.py ifname 2>/dev/null || true)"
      fi
      if [[ -z "$${SECONDARY_IF}" ]]; then SECONDARY_IF="${secondary_vnic_interface}"; fi
      LIBVIRT_BR="virbr0"
      SECONDARY_IP_CIDR="$(ip -o -4 addr show dev "$${SECONDARY_IF}" 2>/dev/null | awk '{print $4}' | head -n1)"
      SECONDARY_IP="$${SECONDARY_IP_CIDR%/*}"
      if [[ -z "$${SECONDARY_IP}" && "$${KOVE_SECONDARY_ENABLED:-false}" == "true" && -n "$${SECONDARY_IF}" ]]; then
        META_IP="$(/usr/local/sbin/kove-oci-resolve-secondary.py ip 2>/dev/null || true)"
        if [[ -n "$${META_IP}" ]]; then
          PREFIX="$${KOVE_SECONDARY_PREFIX:-24}"
          ip addr replace "$${META_IP}/$${PREFIX}" dev "$${SECONDARY_IF}" 2>/dev/null || true
          SECONDARY_IP_CIDR="$(ip -o -4 addr show dev "$${SECONDARY_IF}" 2>/dev/null | awk '{print $4}' | head -n1)"
          SECONDARY_IP="$${SECONDARY_IP_CIDR%/*}"
        fi
      fi
      [[ -z "$${SECONDARY_IP}" ]] && exit 0
      cat >/etc/sysctl.d/98-kove-ip-forward.conf <<SYSCTL
      net.ipv4.ip_forward = 1
      SYSCTL
      sysctl --system >/dev/null 2>&1 || true
      sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
      GUEST_IP="$(virsh --connect qemu:///system domifaddr "$${GUEST_VM}" --source lease 2>/dev/null | awk '/ipv4/ {split($4,a,"/"); print a[1]; exit}')"
      if [[ -z "$${GUEST_IP}" ]]; then
        GUEST_IP="$(virsh --connect qemu:///system net-dhcp-leases default 2>/dev/null | awk '/ipv4/ {split($5,a,"/"); print a[1]; exit}')"
      fi
      [[ -z "$${GUEST_IP}" ]] && exit 0
      nft list table ip nat >/dev/null 2>&1 || nft add table ip nat
      nft list chain ip nat PREROUTING >/dev/null 2>&1 || nft add chain ip nat PREROUTING '{ type nat hook prerouting priority dstnat; policy accept; }'
      nft list table ip filter >/dev/null 2>&1 || nft add table ip filter
      nft list chain ip filter FORWARD >/dev/null 2>&1 || nft add chain ip filter FORWARD '{ type filter hook forward priority filter; policy accept; }'
      nft list chain ip nat POSTROUTING >/dev/null 2>&1 || nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority srcnat; policy accept; }'
      add_dnat(){ local i=$1 hip=$2 hp=$3 gp=$4; [[ -z "$hip" ]] && return 0; local p="iifname \"$i\" ip daddr $hip tcp dport $hp counter dnat to $GUEST_IP:$gp"; nft list chain ip nat PREROUTING | grep -Fq "$p" || nft add rule ip nat PREROUTING iifname "$i" ip daddr "$hip" tcp dport "$hp" counter dnat to "$GUEST_IP:$gp"; }
      add_fwd(){ local port=$1; local op="oifname \"$LIBVIRT_BR\" ip daddr $GUEST_IP tcp dport $port ct state new,established counter accept"; local ip="iifname \"$LIBVIRT_BR\" ip saddr $GUEST_IP tcp sport $port ct state established counter accept"; nft list chain ip filter FORWARD | grep -Fq "$op" || nft insert rule ip filter FORWARD oifname "$LIBVIRT_BR" ip daddr "$GUEST_IP" tcp dport "$port" ct state new,established counter accept; nft list chain ip filter FORWARD | grep -Fq "$ip" || nft insert rule ip filter FORWARD iifname "$LIBVIRT_BR" ip saddr "$GUEST_IP" tcp sport "$port" ct state established counter accept; }
      GUEST_SNAT_NET="$(ip route show dev "$${LIBVIRT_BR}" scope link 2>/dev/null | awk 'NR==1 {print $1; exit}')"
      [[ -z "$${GUEST_SNAT_NET}" ]] && GUEST_SNAT_NET="192.168.122.0/24"
      add_snat_sec(){
        nft list chain ip nat POSTROUTING | grep -Fq "comment \"kove-guest-snat\"" || nft insert rule ip nat POSTROUTING position 0 oifname "$${SECONDARY_IF}" ip saddr "$${GUEST_SNAT_NET}" counter masquerade comment \"kove-guest-snat\"
      }
      add_dnat "$${SECONDARY_IF}" "$${SECONDARY_IP}" 2222 22
      add_dnat "$${SECONDARY_IF}" "$${SECONDARY_IP}" 443 443
      add_dnat "$${SECONDARY_IF}" "$${SECONDARY_IP}" 8443 8443
      add_snat_sec
      add_fwd 22; add_fwd 443; add_fwd 8443
      GUEST_SUBNET="$(ip -o -4 addr show dev "$${LIBVIRT_BR}" 2>/dev/null | awk '{print $4}' | head -n1)"
      if [[ -n "$${GUEST_SUBNET}" ]]; then ip rule add iif "$${LIBVIRT_BR}" lookup vnic2 priority 998 2>/dev/null || true; ip rule add from "$${GUEST_SUBNET}" lookup vnic2 priority 999 2>/dev/null || true; fi

  - path: ${setup_script_path}
    owner: root:root
    permissions: "0750"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      CONF=/etc/kove/mc-instance.conf
      if [[ -f "$CONF" ]]; then
        set -a
        # shellcheck disable=SC1090
        . "$CONF"
        set +a
      fi
      log(){ printf '\n==> %s\n' "$*" >&2; }
      warn(){ printf '\nWARNING: %s\n' "$*" >&2; }
      VM_NAME="$${1:-$${KOVE_GUEST_VM_NAME:-${guest_vm_name}}}"
      DISK_PATH="$${KOVE_GUEST_DISK_PATH:-${guest_disk_path}}"
      IMAGE_SOURCE=""
      if [[ -n "$${2:-}" ]]; then
        case "$${2,,}" in
          *.ova)
            IMAGE_SOURCE="$${2}"
            ;;
          *)
            echo "ERROR: The optional second argument must be an OVA path."
            exit 1
            ;;
        esac
      fi
      VCPUS="$${3:-$${KOVE_GUEST_VCPUS:-${guest_vcpus}}}"
      MEMORY_MB="$${4:-$${KOVE_GUEST_MEMORY_MB:-${guest_memory_mb}}}"
      image_owner_home() {
        if [[ -n "$${SUDO_USER:-}" && "$${SUDO_USER}" != "root" ]]; then
          getent passwd "$${SUDO_USER}" | awk -F: '{print $6}'
        else
          printf '%s\n' "$${HOME:-/root}"
        fi
      }
      find_input_image() {
        local base="$(image_owner_home)"
        find "$${base}" -maxdepth 2 -type f -iname '*.ova' 2>/dev/null | sort | head -n1
      }
      prepare_disk() {
        local input="$${1:-}"
        log "Preparing MC guest disk"
        mkdir -p "$(dirname "$${DISK_PATH}")"
        if [[ -f "$${DISK_PATH}" ]]; then
          log "Using existing disk: $${DISK_PATH}"
          return 0
        fi
        if [[ -z "$${input}" ]]; then
          input="$(find_input_image)"
        fi
        [[ -n "$${input}" && -f "$${input}" ]] || { echo "ERROR: No OVA found. Copy the MC OVA into $(image_owner_home) or pass an OVA path as the second argument."; exit 1; }
        log "Using OVA: $${input}"
        case "$${input,,}" in
          *.ova)
            command -v qemu-img >/dev/null 2>&1 || { echo "ERROR: qemu-img is required to convert OVA images."; exit 1; }
            workdir="$(mktemp -d /var/tmp/kove-mc-ova.XXXXXX)"
            trap 'rm -rf "$${workdir:-}"' EXIT
            tar -xf "$${input}" -C "$${workdir}"
            vmdk="$(find "$${workdir}" -type f -iname '*.vmdk' | sort | head -n1)"
            [[ -n "$${vmdk}" ]] || { echo "ERROR: OVA does not contain a VMDK: $${input}"; exit 1; }
            log "Converting OVA disk to $${DISK_PATH}"
            qemu-img convert -p -f vmdk -O qcow2 "$${vmdk}" "$${DISK_PATH}"
            ;;
          *)
            echo "ERROR: Unsupported MC image format: $${input}. Expected .ova."
            exit 1
            ;;
        esac
        chown root:root "$${DISK_PATH}"
        chmod 0644 "$${DISK_PATH}"
        restorecon -Rv "$(dirname "$${DISK_PATH}")" 2>/dev/null || true
      }
      configure_secondary_vnic() {
        /usr/local/sbin/oci-vnic2-routing.sh || true
      }
      wait_for_guest_ip() {
        local i ip
        log "Waiting up to 3 minutes for $${VM_NAME} DHCP lease"
        for i in $(seq 1 36); do
          ip="$(virsh --connect qemu:///system domifaddr "$${VM_NAME}" --source lease 2>/dev/null | awk '/ipv4/ {split($4,a,"/"); print a[1]; exit}')"
          if [[ -n "$${ip}" ]]; then
            printf '%s\n' "$${ip}"
            return 0
          fi
          sleep 5
        done
        return 1
      }
      show_verification() {
        local guest_ip="$${1:-}"
        local secondary_if="$${KOVE_SECONDARY_VNIC_IF:-${secondary_vnic_interface}}"
        local secondary_ip=""
        secondary_ip="$(ip -o -4 addr show dev "$${secondary_if}" 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
        if [[ -z "$${secondary_ip}" ]]; then
          secondary_ip="$(/usr/local/sbin/kove-oci-resolve-secondary.py ip 2>/dev/null || true)"
        fi
        log "Verification"
        virsh --connect qemu:///system list --all || true
        virsh --connect qemu:///system domifaddr "$${VM_NAME}" --source lease || true
        nft list ruleset | grep -E '2222|8443|kove|dnat|masquerade' -n || true
        if [[ -n "$${secondary_ip}" ]]; then
          printf '\nMC setup complete. From an XPD node or another client that can reach the MC secondary VNIC, test with:\n'
          printf 'curl -k --connect-timeout 15 https://%s:8443/host_api/v1/fabric_type\n' "$${secondary_ip}"
          printf '\nExpected response: "RoCE"\n'
        else
          warn "Could not determine the MC secondary VNIC IP for the client-side curl command."
        fi
      }
      log "Starting MC guest setup for $${VM_NAME}"
      prepare_disk "$${IMAGE_SOURCE}"
      configure_secondary_vnic
      [[ -f "$${DISK_PATH}" ]] || { echo "ERROR: Disk image not found: $${DISK_PATH}"; exit 1; }
      virsh --connect qemu:///system destroy "$${VM_NAME}" 2>/dev/null || true
      virsh --connect qemu:///system undefine "$${VM_NAME}" --nvram 2>/dev/null || virsh --connect qemu:///system undefine "$${VM_NAME}" 2>/dev/null || true
      virsh --connect qemu:///system net-start default 2>/dev/null || true
      virsh --connect qemu:///system net-autostart default >/dev/null || true
      log "Importing $${VM_NAME}"
      virt-install --connect qemu:///system --name "$${VM_NAME}" --memory "$${MEMORY_MB}" --vcpus "$${VCPUS}" --cpu Westmere,-svm,-x2apic,-tsc-deadline,-invtsc --machine pc --disk path="$${DISK_PATH}",format=qcow2,bus=sata,target=sda --network network=default,model=e1000 --os-variant rhel8.7 --graphics vnc,listen=127.0.0.1 --serial pty --console pty,target_type=serial --import --noautoconsole
      virsh --connect qemu:///system autostart "$${VM_NAME}" >/dev/null || true
      GUEST_IP="$(wait_for_guest_ip || true)"
      if [[ -n "$${GUEST_IP}" ]]; then
        log "Guest DHCP lease found: $${GUEST_IP}"
      else
        warn "No guest DHCP lease found after 3 minutes. The VM may still be booting; rerun sudo /usr/local/sbin/oci-mc-port-forwarding.sh after the lease appears."
      fi
      log "Applying secondary-VNIC forwarding"
      configure_secondary_vnic
      /usr/local/sbin/oci-mc-port-forwarding.sh || true
      show_verification "$${GUEST_IP:-}"

  - path: /etc/systemd/system/kove-mc-port-forwarding.service
    owner: root:root
    permissions: "0644"
    content: |
      [Unit]
      Description=Configure MC libvirt port forwarding and dual-NIC return routing
      After=network-online.target libvirtd.service virtqemud.service
      Wants=network-online.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/oci-mc-port-forwarding.sh
      RemainAfterExit=true

      [Install]
      WantedBy=multi-user.target

  - path: /usr/local/sbin/kove-install-rpms.sh
    owner: root:root
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euxo pipefail

      OFFLINE_REPO_TARBALL_URL=${jsonencode(offline_repo_tarball_url)}
      OFFLINE_REPO_TARBALL_SHA256=${jsonencode(offline_repo_tarball_sha256)}
      OFFLINE_RPM_PACKAGES=${jsonencode(offline_rpm_packages)}
      OFFLINE_REPO_DIR="/opt/kove/offline-rpm-repo"
      OFFLINE_REPO_FILE="/var/tmp/kove-offline-rpm-repo.tar.gz"

      download_file() {
        local src="$1"
        local dest="$2"
        case "$src" in
          file://*) cp "$(printf '%s' "$src" | sed 's#^file://##')" "$dest" ;;
          /*) cp "$src" "$dest" ;;
          http://*|https://*)
            if command -v curl >/dev/null 2>&1; then
              curl -fL "$src" -o "$dest"
            elif command -v python3 >/dev/null 2>&1; then
              URL="$src" DEST="$dest" python3 - <<'PY'
      import os
      import urllib.request
      urllib.request.urlretrieve(os.environ["URL"], os.environ["DEST"])
      PY
            else
              echo "ERROR: curl or python3 is required to download $src" >&2
              return 1
            fi
            ;;
          *) echo "ERROR: unsupported offline repo tarball source: $src" >&2; return 1 ;;
        esac
      }

      configure_offline_repo() {
        [ -n "$OFFLINE_REPO_TARBALL_URL" ] || return 0
        mkdir -p "$OFFLINE_REPO_DIR"
        download_file "$OFFLINE_REPO_TARBALL_URL" "$OFFLINE_REPO_FILE"
        if [ -n "$OFFLINE_REPO_TARBALL_SHA256" ]; then
          printf '%s  %s\n' "$OFFLINE_REPO_TARBALL_SHA256" "$OFFLINE_REPO_FILE" | sha256sum -c -
        fi
        tar -xzf "$OFFLINE_REPO_FILE" -C "$OFFLINE_REPO_DIR"
        local repomd=""
        repomd=$(find "$OFFLINE_REPO_DIR" -path '*/repodata/repomd.xml' -type f | head -n 1)
        [ -n "$repomd" ] || { echo "ERROR: offline repo tarball does not contain repodata/repomd.xml" >&2; return 1; }
        local repo_dir
        repo_dir=$(dirname "$(dirname "$repomd")")
        cat >/etc/yum.repos.d/kove-offline.repo <<EOF
      [kove-offline]
      name=Kove Offline RPM Repo
      baseurl=file://$repo_dir
      enabled=1
      gpgcheck=0
      EOF
      }

      install_packages() {
        [ -n "$(echo "$OFFLINE_RPM_PACKAGES" | tr -d '[:space:]')" ] || return 0
        if [ -n "$OFFLINE_REPO_TARBALL_URL" ]; then
          configure_offline_repo
          if command -v dnf >/dev/null 2>&1; then
            dnf -y --disablerepo='*' --enablerepo='kove-offline' install $OFFLINE_RPM_PACKAGES
          elif command -v yum >/dev/null 2>&1; then
            yum -y --disablerepo='*' --enablerepo='kove-offline' install $OFFLINE_RPM_PACKAGES
          else
            echo "ERROR: dnf or yum is required to install offline RPM packages" >&2
            return 1
          fi
        elif command -v dnf >/dev/null 2>&1; then
          dnf -y install $OFFLINE_RPM_PACKAGES
        elif command -v yum >/dev/null 2>&1; then
          yum -y install $OFFLINE_RPM_PACKAGES
        fi
      }

      install_packages

runcmd:
  - /usr/local/sbin/kove-install-rpms.sh
  - [bash, -lc, "set -euxo pipefail; mkdir -p /opt/kove"]
  - [bash, -lc, "set -euxo pipefail; if systemctl list-unit-files | grep -q '^libvirtd.service'; then systemctl enable --now libvirtd; else systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket; fi"]
  - [bash, -lc, "set -euxo pipefail; CANDIDATES='192.168.122.0/24 192.168.123.0/24 172.16.122.0/24'; SELECTED=''; for cidr in $${CANDIDATES}; do if ! ip -4 route | awk '{print $1}' | grep -q \"^$${cidr}$\"; then SELECTED=$${cidr}; break; fi; done; [ -n \"$${SELECTED}\" ] || SELECTED='192.168.122.0/24'; export SELECTED; GW=$(python3 - <<'PY'\nimport ipaddress, os\nnet = ipaddress.ip_network(os.environ['SELECTED'], strict=False)\nprint(str(next(net.hosts())))\nPY\n); NETMASK=$(python3 - <<'PY'\nimport ipaddress, os\nnet = ipaddress.ip_network(os.environ['SELECTED'], strict=False)\nprint(str(net.netmask))\nPY\n); cat >/tmp/default-net.xml <<EOF\n<network>\n  <name>default</name>\n  <forward mode='nat'/>\n  <bridge name='virbr0' stp='on' delay='0'/>\n  <ip address='$${GW}' netmask='$${NETMASK}'>\n    <dhcp>\n      <range start='$${GW%.*}.2' end='$${GW%.*}.254'/>\n    </dhcp>\n  </ip>\n</network>\nEOF\nvirsh --connect qemu:///system net-destroy default 2>/dev/null || true\nvirsh --connect qemu:///system net-undefine default 2>/dev/null || true\nvirsh --connect qemu:///system net-define /tmp/default-net.xml\nvirsh --connect qemu:///system net-start default\nvirsh --connect qemu:///system net-autostart default || true"]
  - [bash, -lc, "systemctl daemon-reload\nsystemctl enable kove-mc-port-forwarding.service || true"]
  - [bash, -lc, "echo 'MC host bootstrap complete. Run: sudo ${setup_script_path}' >/etc/motd.d/99-kove-mc"]
  - [bash, -lc, "set -a; . /etc/kove/mc-instance.conf 2>/dev/null || true; set +a; IF=\"$${KOVE_SECONDARY_VNIC_IF:-}\"; if [[ -z \"$${IF}\" && \"$${KOVE_SECONDARY_ENABLED:-false}\" == \"true\" ]]; then IF=\"$(/usr/local/sbin/kove-oci-resolve-secondary.py ifname 2>/dev/null || true)\"; fi; if [[ -z \"$${IF}\" ]]; then IF=\"${secondary_vnic_interface}\"; fi; if command -v nmcli >/dev/null 2>&1 && [[ -n \"$${IF}\" ]] && ip link show \"$${IF}\" >/dev/null 2>&1; then CONN_NAME=$(nmcli -t -f DEVICE,NAME con show | awk -F: -v d=\"$${IF}\" '$1==d {print $2; exit}'); if [[ -n \"$${CONN_NAME}\" ]]; then nmcli con mod \"$${CONN_NAME}\" connection.autoconnect yes || true; if [[ -n \"$${KOVE_SECONDARY_PRIVATE_IP:-}\" ]]; then nmcli con mod \"$${CONN_NAME}\" ipv4.method auto ipv4.addresses \"$${KOVE_SECONDARY_PRIVATE_IP}/$${KOVE_SECONDARY_PREFIX:-24}\" || true; nmcli con up \"$${CONN_NAME}\" || true; fi; fi; fi"]
  - [bash, -lc, "IF=\"${secondary_vnic_interface}\"; set -a; . /etc/kove/mc-instance.conf 2>/dev/null || true; set +a; IF=\"$${KOVE_SECONDARY_VNIC_IF:-$IF}\"; if [[ -z \"$${IF}\" && \"$${KOVE_SECONDARY_ENABLED:-false}\" == \"true\" ]]; then IF=\"$(/usr/local/sbin/kove-oci-resolve-secondary.py ifname 2>/dev/null || true)\"; fi; if ip link show \"$${IF}\" >/dev/null 2>&1; then /usr/local/sbin/oci-vnic2-routing.sh || true; fi"]
  - [bash, -lc, "/usr/local/sbin/oci-mc-port-forwarding.sh || true"]
