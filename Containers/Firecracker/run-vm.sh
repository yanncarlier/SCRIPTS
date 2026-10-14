#!/usr/bin/env bash
# run-vm.sh - Sets up host networking and boots the Firecracker microVM.
# Keep this running in one terminal; use connect.sh from another.
set -euo pipefail

WORKDIR="${HOME}/firecracker-demo"
cd "${WORKDIR}"

TAP_DEV="tap0"
TAP_IP="172.16.0.1"
MASK_SHORT="/30"
GUEST_MAC="06:00:AC:10:00:02"   # the guest derives its IP (172.16.0.2) from this MAC
API_SOCKET="/tmp/firecracker.socket"

HOST_IFACE="$(ip -j route list default | jq -r '.[0].dev')"
echo "Host outbound interface: ${HOST_IFACE}"

cleanup() {
  echo "Cleaning up network..."
  sudo iptables -t nat -D POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE 2>/dev/null || true
  sudo iptables -D FORWARD -i "${TAP_DEV}" -o "${HOST_IFACE}" -j ACCEPT 2>/dev/null || true
  sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
  sudo ip link del "${TAP_DEV}" 2>/dev/null || true
  rm -f "${API_SOCKET}"
}
trap cleanup EXIT

# --- Host networking --------------------------------------------------------
sudo ip link del "${TAP_DEV}" 2>/dev/null || true
sudo ip tuntap add dev "${TAP_DEV}" mode tap
sudo ip addr add "${TAP_IP}${MASK_SHORT}" dev "${TAP_DEV}"
sudo ip link set dev "${TAP_DEV}" up

sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
sudo iptables -t nat -A POSTROUTING -o "${HOST_IFACE}" -j MASQUERADE
sudo iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I FORWARD 1 -i "${TAP_DEV}" -o "${HOST_IFACE}" -j ACCEPT

# --- VM configuration -------------------------------------------------------
cat > "${WORKDIR}/vm_config.json" <<EOF
{
  "boot-source": {
    "kernel_image_path": "${WORKDIR}/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "${WORKDIR}/rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "${GUEST_MAC}",
      "host_dev_name": "${TAP_DEV}"
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  }
}
EOF

# --- Boot -------------------------------------------------------------------
rm -f "${API_SOCKET}"
echo "Booting microVM (type 'reboot' inside the guest to shut it down)..."
firecracker --api-sock "${API_SOCKET}" --config-file "${WORKDIR}/vm_config.json"