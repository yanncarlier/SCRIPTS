#!/usr/bin/env bash
# Installs containerd + nerdctl (full bundle: runc, CNI, BuildKit) on Ubuntu.
# Usage: bash install-nerdctl.sh
set -euo pipefail

# Detect CPU architecture (amd64 or arm64)
ARCH="$(dpkg --print-architecture)"

# Look up the latest nerdctl release version (without the leading "v")
VERSION="$(curl -fsSL https://api.github.com/repos/containerd/nerdctl/releases/latest \
  | grep -oP '"tag_name":\s*"v\K[^"]+')"

echo "Installing nerdctl-full ${VERSION} for ${ARCH}..."

TARBALL="nerdctl-full-${VERSION}-linux-${ARCH}.tar.gz"
URL="https://github.com/containerd/nerdctl/releases/download/v${VERSION}/${TARBALL}"

# Download to a temp directory
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fL --progress-bar -o "${TMP_DIR}/${TARBALL}" "${URL}"

# Extract into /usr/local (binaries, CNI plugins, systemd units)
sudo tar -C /usr/local -xzf "${TMP_DIR}/${TARBALL}"

# Start containerd and BuildKit now, and on every boot
sudo systemctl daemon-reload
sudo systemctl enable --now containerd buildkit

echo
echo "Done. Versions installed:"
sudo nerdctl --version
sudo containerd --version