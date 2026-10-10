#!/usr/bin/env bash
# run-pi.sh: build the image once, then run Pi sandboxed against the current directory.
#
# Usage:
#   export OPENROUTER_API_KEY="sk-or-..."
#   ./run-pi.sh                        # rootless Podman (recommended, no sudo)
#   ENGINE="sudo docker" ./run-pi.sh   # use root-owned Docker instead
set -euo pipefail

ENGINE="${ENGINE:-podman}"
IMAGE="pi-agent"
VOLUME="pi-agent-config"

# Fail early with a clear message if the key isn't set in this shell
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "OPENROUTER_API_KEY is not set. Run: export OPENROUTER_API_KEY=\"sk-or-...\"" >&2
  exit 1
fi

# Extra flags, filled in below depending on the engine
EXTRA_FLAGS=()

# Rootless Podman: map your host user to the container's "node" user (UID/GID 1000)
# so Pi can write to the mounted project folder.
if [[ "$ENGINE" == *podman* ]]; then
  EXTRA_FLAGS+=(--userns=keep-id:uid=1000,gid=1000)
fi

# Build the image (re-running is cheap; layers are cached)
$ENGINE build -t "$IMAGE" .

# Run with all Linux capabilities dropped and privilege escalation blocked.
# - Only the current directory is visible to the agent (/workspace).
# - A named volume keeps Pi's settings and downloaded tools (fd, ripgrep)
#   between runs so they aren't re-downloaded every time.
# - "-e OPENROUTER_API_KEY" (no value) forwards the key from your shell
#   without writing it into the image or the script.
$ENGINE run -it --rm \
  --name pi-agent-session \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  "${EXTRA_FLAGS[@]}" \
  -e OPENROUTER_API_KEY \
  -v "$VOLUME:/home/node/.pi" \
  -v "$(pwd):/workspace" \
  "$IMAGE"