#!/bin/bash
# =============================================================================
# 01_host_create_vm.sh
# Run this on your UBUNTU HOST (not inside the VM)
# Creates the LXD VM with SPICE display + full desktop for OpenClaw computer-use
# =============================================================================

set -euo pipefail

VM_NAME="openclaw"
IMAGE="ubuntu:25.10"         # questing desktop VM (Option 3 from LXD UI)
CPUS=4
RAM="8GB"
DISK="40GB"

echo "============================================="
echo " OpenClaw LXD VM Setup — Host Script"
echo "============================================="

# ── 1. Ensure LXD is initialised ──────────────────────────────────────────────
if ! lxc info &>/dev/null; then
  echo "[!] LXD not initialised. Running lxd init --auto..."
  sudo lxd init --auto
fi

# ── 2. Launch the VM from the desktop image ───────────────────────────────────
echo "[*] Launching VM '${VM_NAME}' from ${IMAGE} desktop..."
lxc launch "${IMAGE}" "${VM_NAME}" \
  --vm \
  --config limits.cpu="${CPUS}" \
  --config limits.memory="${RAM}" \
  --device root,size="${DISK}"

echo "[*] Waiting for VM to boot (30s)..."
sleep 30

# ── 3. Configure SPICE display ────────────────────────────────────────────────
echo "[*] Configuring SPICE display..."

# Add a SPICE GPU device (virtio-gpu with SPICE server)
lxc config device add "${VM_NAME}" spice-gpu gpu \
  gputype=physical 2>/dev/null || true

# Set SPICE display
lxc config set "${VM_NAME}" raw.qemu="-vga qxl -spice port=5900,addr=127.0.0.1,disable-ticketing=on"

# ── 4. Resource tuning for computer-use workloads ─────────────────────────────
echo "[*] Tuning VM config..."
lxc config set "${VM_NAME}" boot.autostart true
lxc config set "${VM_NAME}" boot.autostart.delay 5

# Allow nested virtualisation (useful if OpenClaw spins up sub-agents)
lxc config set "${VM_NAME}" security.nesting true

# ── 5. Restart to apply SPICE config ─────────────────────────────────────────
echo "[*] Restarting VM to apply SPICE settings..."
lxc restart "${VM_NAME}"
sleep 20

echo "[*] VM is up. Pushing in-VM setup script..."
lxc file push 02_vm_setup.sh "${VM_NAME}/root/02_vm_setup.sh"
lxc exec "${VM_NAME}" -- chmod +x /root/02_vm_setup.sh

echo ""
echo "============================================="
echo " Next steps:"
echo "============================================="
echo ""
echo "  1. Connect via SPICE viewer:"
echo "     remote-viewer spice://127.0.0.1:5900"
echo "     (install with: sudo apt install virt-viewer)"
echo ""
echo "  2. Or exec directly:"
echo "     lxc exec ${VM_NAME} -- bash"
echo ""
echo "  3. Then run inside the VM:"
echo "     bash /root/02_vm_setup.sh"
echo ""
