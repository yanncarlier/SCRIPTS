#!/usr/bin/env bash
# setup.sh - Installs Firecracker, downloads a guest kernel and an Ubuntu rootfs,
# and prepares an SSH key so you can log into the microVM.
set -euo pipefail

ARCH="$(uname -m)"
WORKDIR="${HOME}/firecracker-demo"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# --- 1. Check for KVM -------------------------------------------------------
if [ ! -e /dev/kvm ]; then
  echo "ERROR: /dev/kvm not found. Enable virtualization in BIOS/UEFI" >&2
  echo "(or enable nested virtualization if this machine is itself a VM)." >&2
  exit 1
fi

# --- 2. Install host dependencies ------------------------------------------
sudo apt-get update
sudo apt-get install -y curl wget squashfs-tools e2fsprogs iproute2 \
  iptables jq openssh-client acl

# --- 3. Give your user access to /dev/kvm ----------------------------------
sudo usermod -aG kvm "${USER}" || true          # permanent (after re-login)
sudo setfacl -m "u:${USER}:rw" /dev/kvm         # immediate (until reboot)

# --- 4. Download and install the latest Firecracker release ----------------
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest_version="$(basename "$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${release_url}/latest")")"
echo "Latest Firecracker release: ${latest_version}"

curl -fL "${release_url}/download/${latest_version}/firecracker-${latest_version}-${ARCH}.tgz" \
  | tar -xz
sudo install -m 0755 \
  "release-${latest_version}-${ARCH}/firecracker-${latest_version}-${ARCH}" \
  /usr/local/bin/firecracker
firecracker --version

# --- 5. Download a guest kernel and Ubuntu rootfs from Firecracker CI ------
CI_VERSION="${latest_version%.*}"

latest_kernel_key="$(curl -fsS "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/${CI_VERSION}/${ARCH}/vmlinux-&list-type=2" \
  | grep -oP "(?<=<Key>)(firecracker-ci/${CI_VERSION}/${ARCH}/vmlinux-[0-9]+\.[0-9]+\.[0-9]{1,3})(?=</Key>)" \
  | sort -V | tail -1)"
wget -nc "https://s3.amazonaws.com/spec.ccfc.min/${latest_kernel_key}"
ln -sf "$(basename "${latest_kernel_key}")" vmlinux

latest_ubuntu_key="$(curl -fsS "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/${CI_VERSION}/${ARCH}/ubuntu-&list-type=2" \
  | grep -oP "(?<=<Key>)(firecracker-ci/${CI_VERSION}/${ARCH}/ubuntu-[0-9]+\.[0-9]+\.squashfs)(?=</Key>)" \
  | sort -V | tail -1)"
wget -nc -O ubuntu.squashfs "https://s3.amazonaws.com/spec.ccfc.min/${latest_ubuntu_key}"

# --- 6. Build an ext4 rootfs with your SSH key baked in --------------------
sudo rm -rf squashfs-root
sudo unsquashfs ubuntu.squashfs

[ -f vm_key ] || ssh-keygen -t ed25519 -f vm_key -N "" -q
sudo mkdir -p squashfs-root/root/.ssh
sudo cp vm_key.pub squashfs-root/root/.ssh/authorized_keys
sudo chmod 700 squashfs-root/root/.ssh
sudo chmod 600 squashfs-root/root/.ssh/authorized_keys
sudo chown -R root:root squashfs-root

rm -f rootfs.ext4
truncate -s 1G rootfs.ext4
sudo mkfs.ext4 -q -d squashfs-root -F rootfs.ext4
sudo rm -rf squashfs-root

echo
echo "Setup complete. Files are in: ${WORKDIR}"
echo "Log out and back in (or run 'newgrp kvm') so the kvm group applies permanently."
echo "Next: ./run-vm.sh in one terminal, then ./connect.sh in another."