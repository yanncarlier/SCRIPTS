## containerd + nerdctl on Ubuntu 26

The simplest route is the official **nerdctl-full** bundle. It includes containerd, runc, CNI plugins, and BuildKit (for `nerdctl build`), so you don’t have to install them separately. The script below always downloads the latest release.

### 1. Install

If you previously installed Docker or the apt `containerd` package, remove them first, because they conflict with the bundle’s own containerd.

bash

```bash
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
```

Run it:

```
bash install-nerdctl.sh
```

### 2. Try it out

This script walks through the everyday commands. Run them one at a time or all together.

bash

```bash
#!/usr/bin/env bash
# Basic nerdctl usage demo. Run from the folder containing the Dockerfile.
set -euo pipefail

# Run a throwaway container (pulls the image automatically)
sudo nerdctl run --rm hello-world

# Run nginx in the background, mapping host port 8080 -> container port 80
sudo nerdctl run -d --name web -p 8080:80 nginx:alpine
curl -s http://localhost:8080 | head -n 5

# List running containers, view logs, open a shell inside
sudo nerdctl ps
sudo nerdctl logs web
sudo nerdctl exec web echo "hello from inside the container"

# Stop and remove it
sudo nerdctl stop web
sudo nerdctl rm web

# Build your own image from the Dockerfile below, then run it
sudo nerdctl build -t my-app:1.0 .
sudo nerdctl run --rm my-app:1.0

# Compose works too (uses compose.yaml below)
sudo nerdctl compose up -d
sudo nerdctl compose ps
sudo nerdctl compose down

# Images and cleanup
sudo nerdctl images
sudo nerdctl system prune -f
```

A sample `Dockerfile` for the build step:

dockerfile

```dockerfile
FROM alpine:latest
RUN echo "Hello from my custom image built with nerdctl" > /message.txt
CMD ["cat", "/message.txt"]
```

And a sample `compose.yaml`:

yaml

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
```

### Handy notes

- **Docker habits carry over.** nerdctl’s CLI mirrors Docker’s, so `nerdctl run/ps/build/compose` all work the same way. You can add `alias docker='sudo nerdctl'` to `~/.bashrc` if you like.
- **Namespaces.** nerdctl uses the `default` containerd namespace, which is separate from Kubernetes’ (`k8s.io`). Use `sudo nerdctl --namespace k8s.io ps` to see those.
- **Avoid typing `sudo` (rootless mode).** Run `sudo apt install -y uidmap`, then `containerd-rootless-setuptool.sh install`, and use `nerdctl` as your normal user. On recent Ubuntu releases, AppArmor restricts unprivileged user namespaces, so rootless mode may need an extra AppArmor profile. If you hit that, the nerdctl docs cover it, and sticking with `sudo` is perfectly fine for a laptop.
- **Uninstall.** Run `sudo systemctl disable --now containerd buildkit`, then delete the installed files from `/usr/local` (`bin`, `lib/systemd/system`, `libexec/cni`, and so on).



## Managing running containers with nerdctl

```
Commands:
  list        Running containers
  list-all    Running and stopped containers
  stats       Live CPU/memory usage
  top   <c>   Processes inside a container
  logs  <c>   Follow a container's logs
  inspect <c> Full container details
  shell <c>   Open a shell inside a container
  stop  <c>   Stop a container
  start <c>   Start a stopped container
  restart <c> Restart a container
  rm    <c>   Force-remove a container
  stop-all    Stop every running container
  images      List images
  volumes     List volumes
  networks    List networks
  disk        Disk usage
  clean       Prune unused containers/networks/images

```



- `sudo nerdctl ps` shows running containers (add `-a` to include stopped ones)
- `sudo nerdctl stats` shows live CPU and memory usage
- `sudo nerdctl logs -f web` follows the logs of a container named `web`
- `sudo nerdctl exec -it web sh` opens a shell inside it
- `sudo nerdctl stop web`, `start web`, `restart web` and `rm -f web` control its lifecycle
- `sudo nerdctl system df` shows disk usage, and `sudo nerdctl system prune -f` cleans up unused data

### Two useful extras

- **Auto-restart on boot.** Start a container with `--restart unless-stopped` (for example `sudo nerdctl run -d --restart unless-stopped --name web -p 8080:80 nginx:alpine`) and containerd brings it back after a reboot.
- **Compose projects.** For anything started with `nerdctl compose up -d`, manage it with `sudo nerdctl compose ps`, `compose logs -f`, and `compose down` from the folder containing your `compose.yaml`.