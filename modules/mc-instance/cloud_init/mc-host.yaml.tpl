#cloud-config
package_update: false
package_upgrade: false

write_files:
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
  - [bash, -lc, "cat >/usr/local/sbin/oci-vnic2-routing.sh <<'EOF'\n#!/usr/bin/env bash\nset -euo pipefail\nSECONDARY_IF=\"${secondary_vnic_interface}\"\nTABLE_ID=200\nTABLE_NAME=vnic2\nif ! ip link show \"$${SECONDARY_IF}\" >/dev/null 2>&1; then exit 0; fi\nip link set \"$${SECONDARY_IF}\" up || true\nSECONDARY_CIDR=\"$(ip -o -4 addr show dev \"$${SECONDARY_IF}\" | awk '{print $4}' | head -n1)\"\nif [[ -z \"$${SECONDARY_CIDR}\" ]]; then exit 0; fi\nSECONDARY_IP=\"$${SECONDARY_CIDR%/*}\"\nSUBNET_CIDR=\"$(ip -4 route show dev \"$${SECONDARY_IF}\" proto kernel scope link | awk 'NR==1 {print $1}')\"\n[[ -z \"$${SUBNET_CIDR}\" ]] && SUBNET_CIDR=\"$${SECONDARY_CIDR}\"\nSECONDARY_GW=\"$(ip route | awk -v dev=\"$${SECONDARY_IF}\" '$1==\"default\" && $0~(\"dev \" dev){print $3; exit}')\"\nif [[ -z \"$${SECONDARY_GW}\" ]]; then\n  export SECONDARY_CIDR\n  SECONDARY_GW=\"$(python3 - <<'PY'\nimport ipaddress, os\nnet = ipaddress.ip_interface(os.environ['SECONDARY_CIDR']).network\nprint(next(net.hosts()))\nPY\n)\"\nfi\ngrep -q \"^$${TABLE_ID} $${TABLE_NAME}$\" /etc/iproute2/rt_tables || echo \"$${TABLE_ID} $${TABLE_NAME}\" >> /etc/iproute2/rt_tables\nip route replace \"$${SUBNET_CIDR}\" dev \"$${SECONDARY_IF}\" src \"$${SECONDARY_IP}\" table \"$${TABLE_NAME}\"\nip route replace default via \"$${SECONDARY_GW}\" dev \"$${SECONDARY_IF}\" table \"$${TABLE_NAME}\"\nip rule add from \"$${SECONDARY_IP}/32\" table \"$${TABLE_NAME}\" priority 1000 2>/dev/null || true\nip rule add to \"$${SECONDARY_IP}/32\" table \"$${TABLE_NAME}\" priority 1001 2>/dev/null || true\ncat >/etc/sysctl.d/99-kove-multi-vnic.conf <<SYSCTL\nnet.ipv4.conf.all.rp_filter=2\nnet.ipv4.conf.default.rp_filter=2\nnet.ipv4.conf.eth0.rp_filter=2\nnet.ipv4.conf.${secondary_vnic_interface}.rp_filter=2\nSYSCTL\nsysctl --system >/dev/null 2>&1 || true\nEOF\nchmod 0755 /usr/local/sbin/oci-vnic2-routing.sh"]
  - [bash, -lc, "cat >/usr/local/sbin/oci-mc-port-forwarding.sh <<'EOF'\n#!/usr/bin/env bash\nset -euo pipefail\nSECONDARY_IF=\"${secondary_vnic_interface}\"\nGUEST_VM=\"${guest_vm_name}\"\nLIBVIRT_BR=\"virbr0\"\nPRIMARY_IF=\"$(ip -4 route show default | awk 'NR==1 {print $5}')\"\nPRIMARY_IP_CIDR=\"$${PRIMARY_IF:+$(ip -o -4 addr show dev \"$${PRIMARY_IF}\" | awk '{print $4}' | head -n1)}\"\nPRIMARY_IP=\"$${PRIMARY_IP_CIDR%/*}\"\nSECONDARY_IP_CIDR=\"$(ip -o -4 addr show dev \"$${SECONDARY_IF}\" 2>/dev/null | awk '{print $4}' | head -n1)\"\nSECONDARY_IP=\"$${SECONDARY_IP_CIDR%/*}\"\n[[ -z \"$${PRIMARY_IP}\" && -z \"$${SECONDARY_IP}\" ]] && exit 0\ncat >/etc/sysctl.d/98-kove-ip-forward.conf <<SYSCTL\nnet.ipv4.ip_forward = 1\nSYSCTL\nsysctl --system >/dev/null 2>&1 || true\nGUEST_IP=\"$(virsh --connect qemu:///system domifaddr \"$${GUEST_VM}\" --source lease 2>/dev/null | awk '/ipv4/ {split($4,a,\"/\"); print a[1]; exit}')\"\nif [[ -z \"$${GUEST_IP}\" ]]; then\n  GUEST_IP=\"$(virsh --connect qemu:///system net-dhcp-leases default 2>/dev/null | awk '/ipv4/ {split($5,a,\"/\"); print a[1]; exit}')\"\nfi\n[[ -z \"$${GUEST_IP}\" ]] && exit 0\nnft list table ip nat >/dev/null 2>&1 || nft add table ip nat\nnft list chain ip nat PREROUTING >/dev/null 2>&1 || nft add chain ip nat PREROUTING '{ type nat hook prerouting priority dstnat; policy accept; }'\nnft list table ip filter >/dev/null 2>&1 || nft add table ip filter\nnft list chain ip filter FORWARD >/dev/null 2>&1 || nft add chain ip filter FORWARD '{ type filter hook forward priority filter; policy accept; }'\nadd_dnat(){ local i=$1 hip=$2 hp=$3 gp=$4; [[ -z \"$hip\" ]] && return 0; local p=\"iifname \\\"$i\\\" ip daddr $hip tcp dport $hp counter dnat to $GUEST_IP:$gp\"; nft list chain ip nat PREROUTING | grep -Fq \"$p\" || nft add rule ip nat PREROUTING iifname \"$i\" ip daddr \"$hip\" tcp dport \"$hp\" counter dnat to \"$GUEST_IP:$gp\"; }\nadd_fwd(){ local port=$1; local op=\"oifname \\\"$LIBVIRT_BR\\\" ip daddr $GUEST_IP tcp dport $port ct state new,established counter accept\"; local ip=\"iifname \\\"$LIBVIRT_BR\\\" ip saddr $GUEST_IP tcp sport $port ct state established counter accept\"; nft list chain ip filter FORWARD | grep -Fq \"$op\" || nft insert rule ip filter FORWARD oifname \"$LIBVIRT_BR\" ip daddr \"$GUEST_IP\" tcp dport \"$port\" ct state new,established counter accept; nft list chain ip filter FORWARD | grep -Fq \"$ip\" || nft insert rule ip filter FORWARD iifname \"$LIBVIRT_BR\" ip saddr \"$GUEST_IP\" tcp sport \"$port\" ct state established counter accept; }\nif [[ -n \"$${PRIMARY_IF}\" ]]; then add_dnat \"$${PRIMARY_IF}\" \"$${PRIMARY_IP}\" 2222 22; add_dnat \"$${PRIMARY_IF}\" \"$${PRIMARY_IP}\" 443 443; add_dnat \"$${PRIMARY_IF}\" \"$${PRIMARY_IP}\" 8443 8443; fi\nif [[ -n \"$${SECONDARY_IP}\" ]]; then add_dnat \"$${SECONDARY_IF}\" \"$${SECONDARY_IP}\" 2222 22; add_dnat \"$${SECONDARY_IF}\" \"$${SECONDARY_IP}\" 443 443; add_dnat \"$${SECONDARY_IF}\" \"$${SECONDARY_IP}\" 8443 8443; fi\nadd_fwd 22; add_fwd 443; add_fwd 8443\nGUEST_SUBNET=\"$(ip -o -4 addr show dev \"$${LIBVIRT_BR}\" 2>/dev/null | awk '{print $4}' | head -n1)\"\nif [[ -n \"$${GUEST_SUBNET}\" ]]; then ip rule add iif \"$${LIBVIRT_BR}\" lookup vnic2 priority 998 2>/dev/null || true; ip rule add from \"$${GUEST_SUBNET}\" lookup vnic2 priority 999 2>/dev/null || true; fi\nEOF\nchmod 0755 /usr/local/sbin/oci-mc-port-forwarding.sh"]
  - [bash, -lc, "set -euxo pipefail; mkdir -p /opt/kove"]
  - [bash, -lc, "set -euxo pipefail; if systemctl list-unit-files | grep -q '^libvirtd.service'; then systemctl enable --now libvirtd; else systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket; fi"]
  - [bash, -lc, "set -euxo pipefail; CANDIDATES='192.168.122.0/24 192.168.123.0/24 172.16.122.0/24'; SELECTED=''; for cidr in $${CANDIDATES}; do if ! ip -4 route | awk '{print $1}' | grep -q \"^$${cidr}$\"; then SELECTED=$${cidr}; break; fi; done; [ -n \"$${SELECTED}\" ] || SELECTED='192.168.122.0/24'; export SELECTED; GW=$(python3 - <<'PY'\nimport ipaddress, os\nnet = ipaddress.ip_network(os.environ['SELECTED'], strict=False)\nprint(str(next(net.hosts())))\nPY\n); NETMASK=$(python3 - <<'PY'\nimport ipaddress, os\nnet = ipaddress.ip_network(os.environ['SELECTED'], strict=False)\nprint(str(net.netmask))\nPY\n); cat >/tmp/default-net.xml <<EOF\n<network>\n  <name>default</name>\n  <forward mode='nat'/>\n  <bridge name='virbr0' stp='on' delay='0'/>\n  <ip address='$${GW}' netmask='$${NETMASK}'>\n    <dhcp>\n      <range start='$${GW%.*}.2' end='$${GW%.*}.254'/>\n    </dhcp>\n  </ip>\n</network>\nEOF\nvirsh --connect qemu:///system net-destroy default 2>/dev/null || true\nvirsh --connect qemu:///system net-undefine default 2>/dev/null || true\nvirsh --connect qemu:///system net-define /tmp/default-net.xml\nvirsh --connect qemu:///system net-start default\nvirsh --connect qemu:///system net-autostart default || true"]
  - [bash, -lc, "cat >${setup_script_path} <<'EOF'\n#!/usr/bin/env bash\nset -euo pipefail\nVM_NAME=\"$${1:-${guest_vm_name}}\"\nDISK_PATH=\"$${2:-${guest_disk_path}}\"\nVCPUS=\"$${3:-${guest_vcpus}}\"\nMEMORY_MB=\"$${4:-${guest_memory_mb}}\"\n[[ -f \"$${DISK_PATH}\" ]] || { echo \"ERROR: Disk image not found: $${DISK_PATH}\"; exit 1; }\nvirsh --connect qemu:///system destroy \"$${VM_NAME}\" 2>/dev/null || true\nvirsh --connect qemu:///system undefine \"$${VM_NAME}\" --nvram 2>/dev/null || virsh --connect qemu:///system undefine \"$${VM_NAME}\" 2>/dev/null || true\nvirsh --connect qemu:///system net-start default 2>/dev/null || true\nvirsh --connect qemu:///system net-autostart default || true\nvirt-install --connect qemu:///system --name \"$${VM_NAME}\" --memory \"$${MEMORY_MB}\" --vcpus \"$${VCPUS}\" --cpu Westmere,-svm,-x2apic,-tsc-deadline,-invtsc --machine pc --disk path=\"$${DISK_PATH}\",format=qcow2,bus=sata,target=sda --network network=default,model=e1000 --os-variant rhel8.7 --graphics vnc,listen=127.0.0.1 --serial pty --console pty,target_type=serial --import --noautoconsole\nvirsh --connect qemu:///system autostart \"$${VM_NAME}\" || true\nvirsh --connect qemu:///system domifaddr \"$${VM_NAME}\" || true\nvirsh --connect qemu:///system vncdisplay \"$${VM_NAME}\" || true\nEOF\nchmod 750 ${setup_script_path}"]
  - [bash, -lc, "echo 'MC host bootstrap complete. Run: sudo ${setup_script_path} ${guest_vm_name} ${guest_disk_path} ${guest_vcpus} ${guest_memory_mb}' >/etc/motd.d/99-kove-mc"]
  - [bash, -lc, "if ip link show ${secondary_vnic_interface} >/dev/null 2>&1; then /usr/local/sbin/oci-vnic2-routing.sh || true; fi"]
  - [bash, -lc, "cat >/etc/systemd/system/kove-mc-port-forwarding.service <<'EOF'\n[Unit]\nDescription=Configure MC libvirt port forwarding and dual-NIC return routing\nAfter=network-online.target libvirtd.service virtqemud.service\nWants=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/usr/local/sbin/oci-mc-port-forwarding.sh\nRemainAfterExit=true\n\n[Install]\nWantedBy=multi-user.target\nEOF\nsystemctl daemon-reload\nsystemctl enable --now kove-mc-port-forwarding.service || true"]
  - [bash, -lc, "/usr/local/sbin/oci-mc-port-forwarding.sh || true"]
  - [bash, -lc, "if command -v nmcli >/dev/null 2>&1; then nmcli con mod ${secondary_vnic_interface} connection.autoconnect yes || true; fi"]
