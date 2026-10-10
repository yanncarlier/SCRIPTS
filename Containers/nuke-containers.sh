#!/usr/bin/env bash
# nuke-containers.sh: completely remove Docker and Podman (Ubuntu), with a volume backup first.
#
# Usage:
#   chmod +x nuke-containers.sh
#   ./nuke-containers.sh          # run as your normal user; it calls sudo where needed
#
# Not using "set -e" on purpose: many cleanup steps legitimately fail if
# something was never installed, and the script should keep going.
set -u

BACKUP_DIR="$HOME/container-volume-backup-$(date +%Y%m%d-%H%M%S)"

echo "=============================================================="
echo " This will REMOVE Docker, Podman and ALL their data:"
echo "   containers, images, volumes, networks, configs, apt repos"
echo " Volumes will be backed up first to:"
echo "   $BACKUP_DIR"
echo "=============================================================="
read -r -p "Type DELETE to continue: " CONFIRM
if [[ "$CONFIRM" != "DELETE" ]]; then
  echo "Aborted. Nothing was changed."
  exit 1
fi

sudo -v || { echo "sudo is required"; exit 1; }

# ---------------------------------------------------------------
# 1. BACKUP volumes (root Docker + rootless Podman)
# ---------------------------------------------------------------
echo "[1/8] Backing up volumes..."
mkdir -p "$BACKUP_DIR"

# Stop running containers first so database files are consistent
if command -v docker >/dev/null 2>&1; then
  sudo docker ps -q 2>/dev/null | xargs -r sudo docker stop >/dev/null 2>&1
fi
if command -v podman >/dev/null 2>&1; then
  podman ps -q 2>/dev/null | xargs -r podman stop >/dev/null 2>&1
fi

# Root Docker volumes
if [[ -d /var/lib/docker/volumes ]]; then
  sudo tar -czf "$BACKUP_DIR/docker-volumes.tar.gz" -C /var/lib/docker volumes 2>/dev/null \
    && echo "  Saved Docker volumes -> docker-volumes.tar.gz"
fi

# Rootless Podman volumes
if [[ -d "$HOME/.local/share/containers/storage/volumes" ]]; then
  tar -czf "$BACKUP_DIR/podman-volumes.tar.gz" \
    -C "$HOME/.local/share/containers/storage" volumes 2>/dev/null \
    && echo "  Saved Podman volumes -> podman-volumes.tar.gz"
fi

sudo chown -R "$USER":"$USER" "$BACKUP_DIR" 2>/dev/null
ls -lh "$BACKUP_DIR"

# ---------------------------------------------------------------
# 2. Podman: full reset while it still works (removes everything it owns)
# ---------------------------------------------------------------
echo "[2/8] Resetting Podman..."
if command -v podman >/dev/null 2>&1; then
  podman system reset -f 2>/dev/null
  sudo podman system reset -f 2>/dev/null
fi

# ---------------------------------------------------------------
# 3. Docker: remove all containers, images, volumes, networks
# ---------------------------------------------------------------
echo "[3/8] Wiping Docker data..."
if command -v docker >/dev/null 2>&1; then
  sudo docker ps -aq 2>/dev/null | xargs -r sudo docker rm -f >/dev/null 2>&1
  sudo docker system prune -a --volumes -f >/dev/null 2>&1
fi

# ---------------------------------------------------------------
# 4. Stop and disable services
# ---------------------------------------------------------------
echo "[4/8] Stopping services..."
sudo systemctl stop docker.service docker.socket containerd.service \
  podman.service podman.socket 2>/dev/null
sudo systemctl disable docker.service docker.socket containerd.service \
  podman.service podman.socket 2>/dev/null
systemctl --user stop podman.socket podman.service docker-desktop 2>/dev/null
systemctl --user disable podman.socket podman.service docker-desktop 2>/dev/null

# ---------------------------------------------------------------
# 5. Remove packages (only the ones actually installed)
# ---------------------------------------------------------------
echo "[5/8] Removing packages..."
PKGS=$(dpkg -l 2>/dev/null | awk '/^ii/ {print $2}' | \
  grep -E '^(docker|podman|containerd|runc$|buildah|skopeo|crun$|conmon$|netavark|aardvark-dns|containers-common)' || true)
if [[ -n "$PKGS" ]]; then
  echo "  Purging: $(echo "$PKGS" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  sudo apt-get purge -y --auto-remove $PKGS
fi

# Snap version of Docker, if present
if command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q '^docker '; then
  sudo snap remove --purge docker
fi

sudo apt-get autoremove -y --purge
sudo apt-get autoclean -y

# ---------------------------------------------------------------
# 6. Delete leftover files and directories
# ---------------------------------------------------------------
echo "[6/8] Deleting leftover data and configs..."
sudo rm -rf /var/lib/docker /var/lib/containerd /var/lib/containers
sudo rm -rf /etc/docker /etc/containers /etc/containerd
sudo rm -rf /run/docker /run/containerd /run/podman /var/run/docker.sock
sudo rm -rf /opt/docker-desktop /usr/local/bin/docker-compose \
  /usr/local/bin/docker-model /usr/local/lib/docker
sudo rm -rf /usr/libexec/docker /usr/lib/docker

rm -rf "$HOME/.docker"
rm -rf "$HOME/.local/share/docker" "$HOME/.local/share/containers"
rm -rf "$HOME/.config/docker" "$HOME/.config/containers" "$HOME/.config/Docker Desktop"
rm -rf "$HOME/.cache/containers"
rm -rf "/run/user/$(id -u)/containers" "/run/user/$(id -u)/podman" "/run/user/$(id -u)/docker"*

# ---------------------------------------------------------------
# 7. Remove Docker's apt repository and signing keys
# ---------------------------------------------------------------
echo "[7/8] Removing apt repo entries..."
sudo rm -f /etc/apt/sources.list.d/docker.list \
           /etc/apt/sources.list.d/docker.sources \
           /etc/apt/sources.list.d/docker-ce.list
sudo rm -f /etc/apt/keyrings/docker.asc /etc/apt/keyrings/docker.gpg \
           /usr/share/keyrings/docker-archive-keyring.gpg
sudo apt-get update >/dev/null 2>&1

# ---------------------------------------------------------------
# 8. Remove docker group and leftover network bridge
# ---------------------------------------------------------------
echo "[8/8] Removing group and network leftovers..."
sudo groupdel docker 2>/dev/null
sudo ip link delete docker0 2>/dev/null
sudo ip link delete podman0 2>/dev/null

echo
echo "================ Verification ================"
for bin in docker podman dockerd containerd runc; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "  STILL PRESENT: $bin -> $(command -v "$bin")"
  else
    echo "  gone: $bin"
  fi
done
echo
echo "Backups are in: $BACKUP_DIR"
echo "Reboot recommended to clear leftover iptables rules and bridges:"
echo "  sudo reboot"