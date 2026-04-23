#cloud-config
package_update: true
packages:
  - qemu-kvm
  - libvirt
  - virt-install
  - qemu-img
  - libguestfs-tools-c

runcmd:
  - [bash, -lc, "set -euxo pipefail; mkdir -p /opt/kove"]
  - [bash, -lc, "set -euxo pipefail; if systemctl list-unit-files | grep -q '^libvirtd.service'; then systemctl enable --now libvirtd; else systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket; fi"]
  - [bash, -lc, "cat >/tmp/default-net.xml <<'EOF'\n<network>\n  <name>default</name>\n  <forward mode='nat'/>\n  <bridge name='virbr0' stp='on' delay='0'/>\n  <ip address='192.168.122.1' netmask='255.255.255.0'>\n    <dhcp>\n      <range start='192.168.122.2' end='192.168.122.254'/>\n    </dhcp>\n  </ip>\n</network>\nEOF\nvirsh --connect qemu:///system net-define /tmp/default-net.xml 2>/dev/null || true\nvirsh --connect qemu:///system net-start default 2>/dev/null || true\nvirsh --connect qemu:///system net-autostart default || true"]
  - [bash, -lc, "cat >${setup_script_path} <<'EOF'\n#!/usr/bin/env bash\nset -euo pipefail\n\nVM_NAME=\"${1:-${guest_vm_name}}\"\nDISK_PATH=\"${2:-${guest_disk_path}}\"\nVCPUS=\"${3:-${guest_vcpus}}\"\nMEMORY_MB=\"${4:-${guest_memory_mb}}\"\n\nif [[ ! -f \"${DISK_PATH}\" ]]; then\n  echo \"ERROR: Disk image not found: ${DISK_PATH}\"\n  echo \"Copy/convert the appliance disk to this host first, then rerun.\"\n  exit 1\nfi\n\nvirsh --connect qemu:///system destroy \"${VM_NAME}\" 2>/dev/null || true\nvirsh --connect qemu:///system undefine \"${VM_NAME}\" --nvram 2>/dev/null || virsh --connect qemu:///system undefine \"${VM_NAME}\" 2>/dev/null || true\nvirsh --connect qemu:///system net-start default 2>/dev/null || true\nvirsh --connect qemu:///system net-autostart default || true\n\nvirt-install \\\n  --connect qemu:///system \\\n  --name \"${VM_NAME}\" \\\n  --memory \"${MEMORY_MB}\" \\\n  --vcpus \"${VCPUS}\" \\\n  --cpu Westmere,-svm,-x2apic,-tsc-deadline,-invtsc \\\n  --machine pc \\\n  --disk path=\"${DISK_PATH}\",format=qcow2,bus=sata,target=sda \\\n  --network network=default,model=e1000 \\\n  --os-variant rhel8.7 \\\n  --graphics vnc,listen=127.0.0.1 \\\n  --serial pty \\\n  --console pty,target_type=serial \\\n  --import \\\n  --noautoconsole\n\nvirsh --connect qemu:///system autostart \"${VM_NAME}\" || true\nvirsh --connect qemu:///system domifaddr \"${VM_NAME}\" || true\nvirsh --connect qemu:///system vncdisplay \"${VM_NAME}\" || true\n\necho \"MC guest deploy complete for ${VM_NAME}.\"\nEOF\nchmod 750 ${setup_script_path}"]
  - [bash, -lc, "echo 'MC host bootstrap complete. Run: sudo ${setup_script_path} ${guest_vm_name} ${guest_disk_path} ${guest_vcpus} ${guest_memory_mb}' >/etc/motd.d/99-kove-mc"]
