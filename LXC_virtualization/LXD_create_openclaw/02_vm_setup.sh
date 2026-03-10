#!/bin/bash
# =============================================================================
# 02_vm_setup.sh
# Run this INSIDE the LXD VM (as root or with sudo)
# Installs: XFCE desktop, Chrome, xdotool, scrot, Node.js, OpenClaw
# =============================================================================

set -euo pipefail

echo "============================================="
echo " OpenClaw VM — In-VM Setup Script"
echo "============================================="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Update system ──────────────────────────────────────────────────────────
echo "[1/9] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install XFCE desktop (lightweight, great for automation) ───────────────
echo "[2/9] Installing XFCE desktop environment..."
apt-get install -y -qq \
  xfce4 \
  xfce4-terminal \
  xfce4-screenshooter \
  lightdm \
  lightdm-gtk-greeter \
  dbus-x11 \
  at-spi2-core

# Enable display manager
systemctl enable lightdm

# ── 3. Install SPICE guest agent & display driver ─────────────────────────────
echo "[3/9] Installing SPICE guest agent..."
apt-get install -y -qq \
  spice-vdagent \
  xserver-xorg-video-qxl \
  qemu-guest-agent

systemctl enable spice-vdagent 2>/dev/null || true
systemctl enable qemu-guest-agent

# ── 4. Install mouse/keyboard control tools ───────────────────────────────────
echo "[4/9] Installing input control tools (xdotool, ydotool, wmctrl)..."
apt-get install -y -qq \
  xdotool \
  wmctrl \
  scrot \
  imagemagick \
  x11-utils \
  x11-xserver-utils \
  xclip \
  xsel \
  libxtst-dev

# ydotool (works on both X11 and Wayland)
apt-get install -y -qq ydotool || true

# ── 5. Install Google Chrome ──────────────────────────────────────────────────
echo "[5/9] Installing Google Chrome..."
apt-get install -y -qq wget curl gnupg ca-certificates

wget -qO /tmp/chrome.deb \
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

apt-get install -y -qq /tmp/chrome.deb || \
  apt-get install -y -f -qq && apt-get install -y -qq /tmp/chrome.deb

rm /tmp/chrome.deb

# Also install Chromium as fallback
apt-get install -y -qq chromium-browser 2>/dev/null || \
apt-get install -y -qq chromium 2>/dev/null || true

# ── 6. Install Playwright system dependencies ─────────────────────────────────
echo "[6/9] Installing Playwright/browser automation dependencies..."
apt-get install -y -qq \
  libnss3 \
  libatk-bridge2.0-0 \
  libdrm2 \
  libxkbcommon0 \
  libgbm1 \
  libasound2t64 \
  libxshmfence1 \
  libxcomposite1 \
  libxdamage1 \
  libxrandr2

# ── 7. Install Node.js (LTS via NodeSource) ───────────────────────────────────
echo "[7/9] Installing Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y -qq nodejs

# Install pnpm globally
npm install -g pnpm

echo "Node version: $(node --version)"
echo "npm version:  $(npm --version)"
echo "pnpm version: $(pnpm --version)"

# ── 8. Install OpenClaw ───────────────────────────────────────────────────────
echo "[8/9] Installing OpenClaw..."
npm install -g openclaw

echo "OpenClaw version: $(openclaw --version 2>/dev/null || echo 'installed')"

# ── 9. Create openclaw user with auto-login ───────────────────────────────────
echo "[9/9] Setting up 'openclaw' user with auto-login..."

# Create dedicated user if not exists
if ! id "openclaw" &>/dev/null; then
  useradd -m -s /bin/bash -G sudo,audio,video,input openclaw
  echo "openclaw:openclaw" | chpasswd
fi

# Configure LightDM autologin
cat > /etc/lightdm/lightdm.conf <<'EOF'
[Seat:*]
autologin-user=openclaw
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

# Configure XFCE session for openclaw user
mkdir -p /home/openclaw/.config/xfce4/xfconf/xfce-perchannel-xml

# Disable screensaver and power management (keeps desktop alive for automation)
cat > /home/openclaw/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
  </property>
</channel>
EOF

# Disable screensaver
cat > /home/openclaw/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
EOF

chown -R openclaw:openclaw /home/openclaw/.config

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo " Setup complete! Rebooting in 5 seconds..."
echo "============================================="
echo ""
echo " After reboot:"
echo "  - Desktop auto-logins as 'openclaw'"
echo "  - Connect via SPICE: remote-viewer spice://127.0.0.1:5900"
echo "  - Then run: bash /root/03_openclaw_configure.sh"
echo ""
sleep 5
reboot
