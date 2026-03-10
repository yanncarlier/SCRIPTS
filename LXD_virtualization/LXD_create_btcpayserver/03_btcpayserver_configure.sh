#!/bin/bash
# =============================================================================
# 03_btcpayserver_configure.sh
# Run INSIDE the LXD VM (as root) after 02_vm_setup.sh
# Deploys BTCPayServer via the official btcpayserver-docker installer
#
# REVERSEPROXY=none — BTCPayServer binds port 80 directly, no nginx needed
# To enable TLS later: set BTCPAY_HOST and change BTCPAYGEN_REVERSEPROXY=nginx
# =============================================================================

set -euo pipefail

echo "============================================="
echo " BTCPayServer — Docker Deployment"
echo "============================================="

# ── ⚙  Edit these before running ─────────────────────────────────────────────
BTCPAY_HOST=""               # e.g. "pay.yourdomain.com" — leave blank for HTTP/IP
NBITCOIN_NETWORK="mainnet"   # "mainnet" | "testnet" | "regtest"
LIGHTNING=""                 # "lnd" | "clightning" | "" (blank = no Lightning)
STORAGE_FRAGMENT="opt-save-storage-xxs"  # pruned node ~25 GB — safe for 60 GB disk

# opt-save-storage: Prunes to 100 GB (~1 year of blocks).
# opt-save-storage-s: Prunes to 50 GB (~6 months of blocks).
# opt-save-storage-xs: Prunes to 25 GB (~3 months of blocks).
# opt-save-storage-xxs: Prunes to 5 GB (~2 weeks of blocks). Note: Lightning is not

# ── 1. Install Docker ─────────────────────────────────────────────────────────
echo "[1/4] Installing Docker..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "Docker version        : $(docker --version)"
echo "Docker Compose version: $(docker compose version)"

# ── 2. Clone BTCPayServer Docker repo ─────────────────────────────────────────
echo "[2/4] Cloning btcpayserver-docker..."

BTCPAY_BASE_DIR="/opt/btcpayserver"
rm -rf "${BTCPAY_BASE_DIR}/btcpayserver-docker"
mkdir -p "${BTCPAY_BASE_DIR}"

git clone https://github.com/btcpayserver/btcpayserver-docker \
  "${BTCPAY_BASE_DIR}/btcpayserver-docker"

# ── 3. Export all required environment variables ──────────────────────────────
echo "[3/4] Configuring environment..."

FRAGMENTS="${STORAGE_FRAGMENT}"
if [ -n "${LIGHTNING}" ]; then
  FRAGMENTS="${FRAGMENTS};${LIGHTNING}"
fi

export BTCPAY_HOST="${BTCPAY_HOST}"
export BTCPAY_ADDITIONAL_HOSTS=""
export NBITCOIN_NETWORK="${NBITCOIN_NETWORK}"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2=""
export BTCPAYGEN_LIGHTNING="${LIGHTNING}"
export BTCPAYGEN_REVERSEPROXY="none"   # BTCPayServer binds port 80 directly
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="${FRAGMENTS}"
export BTCPAY_ENABLE_SSH="false"
export BTCPAY_BASE_DIRECTORY="${BTCPAY_BASE_DIR}"

echo "  Host         : ${BTCPAY_HOST:-<none — access via IP:80>}"
echo "  Network      : ${NBITCOIN_NETWORK}"
echo "  Lightning    : ${LIGHTNING:-none}"
echo "  Reverse proxy: none (direct port 80)"
echo "  Storage      : ${STORAGE_FRAGMENT}"

# ── 4. Run the official BTCPayServer setup ────────────────────────────────────
echo "[4/4] Running btcpay-setup.sh -i ..."
echo "      (pulling Docker images — 5 to 15 min depending on connection)"

cd "${BTCPAY_BASE_DIR}/btcpayserver-docker"

# set +u required — btcpay-setup.sh uses unset internal vars that would
# trigger our strict mode and kill the script prematurely
set +u
. ./btcpay-setup.sh -i

# ── UFW — open BTCPayServer ports ─────────────────────────────────────────────
ufw allow 80/tcp   comment 'BTCPayServer HTTP'
ufw allow 8333/tcp comment 'Bitcoin P2P'
# ufw allow 443/tcp  # Uncomment when adding TLS
# ufw allow 9735/tcp # Uncomment when adding Lightning
ufw reload

# ── Disk space watchdog ───────────────────────────────────────────────────────
cat > /usr/local/bin/btcpay-diskwatch.sh << 'WATCHEOF'
#!/bin/bash
THRESHOLD_GB=8
AVAIL_GB=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
if [ "${AVAIL_GB}" -lt "${THRESHOLD_GB}" ]; then
  MSG="[btcpay-diskwatch] WARNING: only ${AVAIL_GB} GB free on /. Run: df -h /"
  logger -t btcpay-diskwatch "${MSG}"
  echo "${MSG}" | wall 2>/dev/null || true
fi
WATCHEOF
chmod +x /usr/local/bin/btcpay-diskwatch.sh
echo "*/30 * * * * root /usr/local/bin/btcpay-diskwatch.sh" > /etc/cron.d/btcpay-diskwatch

# ── Done ──────────────────────────────────────────────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================="
echo " BTCPayServer deployed!"
echo "============================================="
echo ""
echo " Open in browser: http://${HOST_IP}"
echo ""
echo " Container status : docker ps"
echo " BTCPay logs      : docker logs generated_btcpayserver_1 -f"
echo " Bitcoin sync     : docker exec btcpayserver_bitcoind bitcoin-cli getblockchaininfo"
echo " Stop all         : btcpay-down.sh"
echo " Start all        : btcpay-up.sh"
echo " Restart          : btcpay-restart.sh"
echo " Update           : btcpay-update.sh"
echo " Disk space       : df -h /"
echo ""
echo " To enable TLS later:"
echo "   Set BTCPAY_HOST and BTCPAYGEN_REVERSEPROXY=nginx"
echo "   Then run: btcpay-setup.sh -i"
echo ""
echo " !! Create your admin account now — registration closes after first user !!"
echo ""
