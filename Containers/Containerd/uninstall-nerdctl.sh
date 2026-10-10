#!/usr/bin/env bash
# Completely removes containerd + nerdctl (nerdctl-full bundle) from Ubuntu,
# together with ALL containers, images, volumes, networks and build cache.
#
# Usage (run as your normal user, NOT with sudo; the script calls sudo itself):
#   bash uninstall-nerdctl.sh          # asks for confirmation
#   bash uninstall-nerdctl.sh --yes    # no confirmation prompt
set -uo pipefail

if [[ "$EUID" -eq 0 ]]; then
  echo "Please run this as your normal user (not root), so rootless data in your home folder is cleaned too." >&2
  exit 1
fi

# ---------- Confirmation ----------
if [[ "${1:-}" != "--yes" ]]; then
  echo "WARNING: this will permanently delete ALL containers, images, volumes,"
  echo "networks and build cache, and uninstall containerd, nerdctl, BuildKit,"
  echo "runc and the CNI plugins."
  read -r -p "Type 'yes' to continue: " ANSWER
  if [[ "$ANSWER" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

sudo -v   # ask for the sudo password once, up front

# ---------- 1. Remove all workloads while nerdctl still works ----------
if command -v nerdctl >/dev/null 2>&1; then
  echo "==> Removing containers, images, volumes and networks..."
  # Do it for the default namespace and the Kubernetes one, if present
  for NS in default k8s.io; do
    CONTAINERS="$(sudo nerdctl --namespace "$NS" ps -aq 2>/dev/null)"
    if [[ -n "$CONTAINERS" ]]; then
      # shellcheck disable=SC2086
      sudo nerdctl --namespace "$NS" rm -f $CONTAINERS 2>/dev/null
    fi
    sudo nerdctl --namespace "$NS" system prune -af --volumes 2>/dev/null
  done
fi

# ---------- 2. Rootless setup (only if you installed it) ----------
if command -v containerd-rootless-setuptool.sh >/dev/null 2>&1; then
  echo "==> Removing rootless containerd..."
  containerd-rootless-setuptool.sh uninstall 2>/dev/null
  containerd-rootless-setuptool.sh uninstall-buildkit 2>/dev/null
fi
rm -rf \
  "$HOME/.local/share/containerd" \
  "$HOME/.local/share/nerdctl" \
  "$HOME/.local/share/buildkit" \
  "$HOME/.config/containerd" \
  "$HOME/.config/buildkit" \
  "$HOME/.config/nerdctl" \
  "$HOME/.config/systemd/user/containerd.service" \
  "$HOME/.config/systemd/user/buildkit.service"

# ---------- 3. Stop and disable system services ----------
echo "==> Stopping services..."
for SVC in buildkit containerd stargz-snapshotter; do
  sudo systemctl disable --now "$SVC" 2>/dev/null
done

# Kill leftover shims / daemons that may still be running
sudo pkill -f containerd-shim 2>/dev/null
sudo pkill -x buildkitd 2>/dev/null
sudo pkill -x containerd 2>/dev/null
sleep 1

# Unmount anything containerd left mounted
for MNT in $(mount | awk '/\/var\/lib\/(containerd|nerdctl|buildkit)|\/run\/containerd/ {print $3}' | sort -r); do
  sudo umount -l "$MNT" 2>/dev/null
done

# ---------- 4. Remove installed binaries ----------
echo "==> Removing binaries..."
BINARIES=(
  nerdctl containerd containerd-shim-runc-v2 containerd-shim-runc-v1 containerd-shim
  containerd-stress ctr ctr-enc ctr-remote
  containerd-fuse-overlayfs-grpc containerd-stargz-grpc stargz-store
  containerd-rootless.sh containerd-rootless-setuptool.sh
  buildctl buildkitd
  runc tini fuse-overlayfs
  rootlesskit rootlessctl slirp4netns
  bypass4netns bypass4netnsd
  ipfs
)
for BIN in "${BINARIES[@]}"; do
  sudo rm -f "/usr/local/bin/$BIN" "/usr/local/sbin/$BIN"
done

# ---------- 5. Remove CNI plugins, systemd units and docs ----------
echo "==> Removing CNI plugins, unit files and docs..."
sudo rm -rf \
  /usr/local/libexec/cni \
  /usr/local/lib/systemd/system/containerd.service \
  /usr/local/lib/systemd/system/buildkit.service \
  /usr/local/lib/systemd/system/stargz-snapshotter.service \
  /usr/local/share/doc/nerdctl \
  /usr/local/share/doc/nerdctl-full \
  /usr/local/share/man/man1/nerdctl*
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null

# ---------- 6. Remove data, config and runtime state ----------
echo "==> Removing data and configuration..."
sudo rm -rf \
  /var/lib/containerd \
  /var/lib/nerdctl \
  /var/lib/buildkit \
  /var/lib/cni \
  /var/lib/containerd-stargz-grpc \
  /etc/containerd \
  /etc/buildkit \
  /etc/cni \
  /etc/nerdctl \
  /opt/cni \
  /opt/containerd \
  /run/containerd \
  /run/buildkit \
  /run/nerdctl

# ---------- 7. Remove leftover network bridge ----------
if ip link show nerdctl0 >/dev/null 2>&1; then
  sudo ip link delete nerdctl0 2>/dev/null
fi

# ---------- 8. Optional: apt-installed versions ----------
if dpkg -l containerd containerd.io 2>/dev/null | grep -q '^ii'; then
  echo "==> Removing apt-installed containerd packages..."
  sudo apt-get purge -y containerd containerd.io 2>/dev/null
  sudo apt-get autoremove -y
fi

# ---------- Done ----------
echo
echo "Cleanup finished. Remaining traces (should print nothing below):"
command -v nerdctl containerd runc buildkitd 2>/dev/null
echo
echo "Notes:"
echo "  - Remove any 'alias docker=\"sudo nerdctl\"' line from ~/.bashrc if you added one."
echo "  - A reboot is recommended to clear leftover iptables/nftables rules and network interfaces."