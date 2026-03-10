#!/bin/bash
# =============================================================================
# 01_host_create_vm.sh
# Run this on your UBUNTU HOST (not inside the VM)
# Creates the LXD VM for BTCPayServer
# =============================================================================

set -euo pipefail

VM_NAME="btcpayserver"
IMAGE="ubuntu:25.10"
CPUS=2
RAM="4GB"
DISK="30GB"

echo "============================================="
echo " BTCPayServer LXD VM Setup — Host Script"
echo "============================================="

# ── 1. Ensure LXD is initialised ──────────────────────────────────────────────
if ! lxc info &>/dev/null; then
  echo "[!] LXD not initialised. Running lxd init --auto..."
  sudo lxd init --auto
fi

# ── 2. Delete existing VM if present ──────────────────────────────────────────
if lxc info "${VM_NAME}" &>/dev/null; then
  echo "[*] Removing existing VM '${VM_NAME}'..."
  lxc stop "${VM_NAME}" --force 2>/dev/null || true
  lxc delete "${VM_NAME}"
fi

# ── 3. Launch VM ──────────────────────────────────────────────────────────────
echo "[*] Launching VM '${VM_NAME}' from ${IMAGE}..."
lxc launch "${IMAGE}" "${VM_NAME}" \
  --vm \
  --config limits.cpu="${CPUS}" \
  --config limits.memory="${RAM}" \
  --device root,size="${DISK}"

lxc config set "${VM_NAME}" boot.autostart true
lxc config set "${VM_NAME}" boot.autostart.delay 10

echo "[*] Waiting for VM to boot (30s)..."
sleep 30

# ── 4. UFW — allow LXD bridge traffic (required for VM DHCP + internet) ───────
echo "[*] Configuring UFW bridge rules..."
ufw allow in on lxdbr0        2>/dev/null || true
ufw route allow in on lxdbr0  2>/dev/null || true
ufw route allow out on lxdbr0 2>/dev/null || true

# ── 5. Wait for VM to get a DHCP IP ───────────────────────────────────────────
echo "[*] Waiting for VM to get an IP (up to 90s)..."
VM_IP=""
for i in $(seq 1 18); do
  VM_IP=$(lxc list "${VM_NAME}" -c 4 --format csv 2>/dev/null \
    | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1 || true)
  if [ -n "${VM_IP}" ]; then break; fi
  echo "    ...waiting (${i}/18)"
  sleep 5
done

if [ -z "${VM_IP}" ]; then
  echo "[!] VM did not get an IP within 90s."
  echo "    Run: lxc exec ${VM_NAME} -- ip addr"
  exit 1
fi

# ── 6. Port forwarding via lxc network forward ────────────────────────────────
echo "[*] Setting up port forwarding..."
HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
echo "[*] Host IP: ${HOST_IP}  →  VM IP: ${VM_IP}"

lxc network forward delete lxdbr0 "${HOST_IP}" 2>/dev/null || true
lxc network forward create lxdbr0 "${HOST_IP}"
lxc network forward port add lxdbr0 "${HOST_IP}" tcp 80   "${VM_IP}" 80
lxc network forward port add lxdbr0 "${HOST_IP}" tcp 443  "${VM_IP}" 443
lxc network forward port add lxdbr0 "${HOST_IP}" tcp 8333 "${VM_IP}" 8333

echo "[*] Port forwarding active:"
echo "    ${HOST_IP}:80   → ${VM_IP}:80"
echo "    ${HOST_IP}:443  → ${VM_IP}:443"
echo "    ${HOST_IP}:8333 → ${VM_IP}:8333"

# ── 7. Push scripts 02 and 03 into VM ─────────────────────────────────────────
echo "[*] Pushing setup scripts into VM..."
lxc file push 02_vm_setup.sh "${VM_NAME}/root/02_vm_setup.sh"
lxc file push 03_btcpayserver_configure.sh "${VM_NAME}/root/03_btcpayserver_configure.sh"
lxc exec "${VM_NAME}" -- chmod +x /root/02_vm_setup.sh /root/03_btcpayserver_configure.sh

echo ""
echo "============================================="
echo " VM is ready!"
echo "============================================="
echo ""
echo "  VM IP : ${VM_IP}"
echo ""
echo "  Step 2 — run inside VM:"
echo "    lxc exec ${VM_NAME} -- bash /root/02_vm_setup.sh"
echo ""
echo "  Step 3 — run inside VM:"
echo "    lxc exec ${VM_NAME} -- bash /root/03_btcpayserver_configure.sh"
echo ""
