#!/usr/bin/env bash
#
# install_warp.sh - Install Cloudflare WARP on Ubuntu 24.04 (noble) and 26.04
#
# Usage:
#   sudo ./install_warp.sh              # install only (safe over SSH)
#   sudo ./install_warp.sh --connect    # install, register and connect WARP
#
# WARNING: --connect routes all traffic through WARP. If you are on a remote
# server over SSH, you may lose your connection. Exclude your IP first with:
#   warp-cli tunnel ip add <YOUR_IP>

set -euo pipefail

REPO_HOST="https://pkg.cloudflareclient.com"
KEYRING="/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
LIST_FILE="/etc/apt/sources.list.d/cloudflare-client.list"
FALLBACK_CODENAME="noble"   # Ubuntu 24.04 suite, used if the native one is missing
DO_CONNECT=false

log()  { printf '\n\033[1;34m[*]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- Parse arguments --------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --connect) DO_CONNECT=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) die "Unknown argument: $arg (use --help)" ;;
  esac
done

# ---- Root check -------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  else
    die "Please run as root (or install sudo)."
  fi
fi

# ---- OS check ---------------------------------------------------------------
[[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
# shellcheck disable=SC1091
. /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || die "This script supports Ubuntu only (detected: ${ID:-unknown})."

case "${VERSION_ID:-}" in
  24.04|26.04) log "Detected Ubuntu ${VERSION_ID} (${VERSION_CODENAME:-unknown})." ;;
  *) warn "Ubuntu ${VERSION_ID:-unknown} is untested; trying anyway." ;;
esac

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64|arm64) ;;
  *) die "Unsupported architecture: $ARCH (WARP supports amd64 and arm64)." ;;
esac

CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || true)}"
[[ -n "$CODENAME" ]] || CODENAME="$FALLBACK_CODENAME"

# ---- Prerequisites ----------------------------------------------------------
log "Installing prerequisites..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl gpg lsb-release ca-certificates apt-transport-https

# ---- Add Cloudflare GPG key -------------------------------------------------
log "Adding Cloudflare GPG key..."
curl -fsSL "${REPO_HOST}/pubkey.gpg" | gpg --yes --dearmor --output "$KEYRING"
chmod 644 "$KEYRING"

# ---- Pick a repo suite (native codename, else fallback) ---------------------
if curl -fsI "${REPO_HOST}/dists/${CODENAME}/Release" >/dev/null 2>&1; then
  SUITE="$CODENAME"
else
  warn "No '${CODENAME}' suite found in Cloudflare's repo; falling back to '${FALLBACK_CODENAME}'."
  SUITE="$FALLBACK_CODENAME"
fi

log "Adding Cloudflare WARP apt repository (suite: ${SUITE})..."
echo "deb [arch=${ARCH} signed-by=${KEYRING}] ${REPO_HOST}/ ${SUITE} main" > "$LIST_FILE"

# ---- Install ----------------------------------------------------------------
log "Installing cloudflare-warp..."
apt-get update -y
apt-get install -y cloudflare-warp

# ---- Start the service ------------------------------------------------------
log "Enabling and starting warp-svc..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now warp-svc
  # Give the daemon a moment to come up
  for _ in {1..10}; do
    if warp-cli --accept-tos status >/dev/null 2>&1; then break; fi
    sleep 1
  done
else
  warn "systemd not found; start the daemon manually: warp-svc"
fi

log "Installed: $(warp-cli --version 2>/dev/null || echo 'cloudflare-warp')"

# ---- Optional: register and connect -----------------------------------------
if $DO_CONNECT; then
  log "Registering WARP client..."
  if ! warp-cli --accept-tos registration show >/dev/null 2>&1; then
    warp-cli --accept-tos registration new
  else
    log "Already registered; skipping registration."
  fi

  warn "Connecting WARP now. If you are on SSH, your session may drop."
  warp-cli --accept-tos connect
  sleep 3

  log "Verifying connection..."
  if curl -fsS --max-time 10 https://www.cloudflare.com/cdn-cgi/trace/ | grep -q '^warp=\(on\|plus\)'; then
    log "WARP is ON."
  else
    warn "WARP does not appear to be active. Check: warp-cli status"
  fi
else
  cat <<'EOF'

Done. Next steps:
  warp-cli registration new      # first time only
  warp-cli connect               # turn WARP on
  warp-cli status                # check status
  warp-cli disconnect            # turn WARP off

  Remote server over SSH? Exclude your IP BEFORE connecting:
  warp-cli tunnel ip add <YOUR_IP>

Verify with:
  curl https://www.cloudflare.com/cdn-cgi/trace/   # look for warp=on
EOF
fi