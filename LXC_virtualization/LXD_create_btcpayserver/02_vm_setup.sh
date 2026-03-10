#!/bin/bash
# =============================================================================
# 02_vm_setup.sh
# Run INSIDE the LXD VM (as root)
# Installs system dependencies for BTCPayServer Docker deployment
# NOTE: Do NOT install nginx here — BTCPayServer Docker binds port 80 directly
# =============================================================================

set -euo pipefail

echo "============================================="
echo " BTCPayServer VM — In-VM Setup Script"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Update system ──────────────────────────────────────────────────────────
echo "[1/4] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install dependencies ───────────────────────────────────────────────────
echo "[2/4] Installing dependencies..."
apt-get install -y -qq \
  curl \
  wget \
  git \
  gnupg \
  ca-certificates \
  unzip \
  jq \
  ufw \
  fail2ban \
  htop \
  lsb-release \
  apt-transport-https \
  net-tools

# ── 3. Configure UFW baseline ─────────────────────────────────────────────────
echo "[3/4] Configuring UFW baseline..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable

# ── 4. Enable fail2ban ────────────────────────────────────────────────────────
echo "[4/4] Enabling fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

echo ""
echo "============================================="
echo " VM base setup complete!"
echo "============================================="
echo ""
echo " Now run:"
echo "   lxc exec btcpayserver -- bash /root/03_btcpayserver_configure.sh"
echo ""
