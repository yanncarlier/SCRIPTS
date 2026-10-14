#!/usr/bin/env bash
# ai-sandbox.sh - Run Ollama inside a locked-down rootless Podman container.
#
# Usage:
#
#chmod +x ai-sandbox.sh
#./ai-sandbox.sh pull llama3.2
#./ai-sandbox.sh chat llama3.2
#
#   ./ai-sandbox.sh pull <model>   # needs internet; downloads the model into a volume
#   ./ai-sandbox.sh chat <model>   # fully offline; interactive chat with the model
#
# Requirements: podman (rootless). For NVIDIA GPU support, install
# nvidia-container-toolkit and generate the CDI spec once with:
#   sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
# Set USE_GPU=0 to run on CPU only.

set -euo pipefail

MODE="${1:-}"
MODEL="${2:-}"

IMAGE="docker.io/ollama/ollama:latest"
NAME="ai-sandbox"
VOLUME="ai-sandbox-models"   # persistent storage for model files
MEM_LIMIT="16g"              # adjust to your RAM
CPU_LIMIT="8"                # adjust to your CPU cores
USE_GPU="${USE_GPU:-1}"

if [[ -z "$MODE" || -z "$MODEL" ]]; then
  echo "Usage: $0 {pull|chat} <model>" >&2
  exit 1
fi

# Hardening flags shared by both modes
COMMON_FLAGS=(
  --rm
  --name "$NAME"
  --cap-drop=ALL                      # drop every Linux capability
  --security-opt=no-new-privileges    # block privilege escalation
  --read-only                         # immutable root filesystem
  --tmpfs /tmp:rw,size=1g             # scratch space only
  --pids-limit=512                    # contain fork bombs
  --memory="$MEM_LIMIT"
  --cpus="$CPU_LIMIT"
  -v "$VOLUME":/root/.ollama:Z        # only writable persistent path
)

if [[ "$USE_GPU" == "1" ]]; then
  COMMON_FLAGS+=(--device nvidia.com/gpu=all)
fi

# Clean up any leftover container with the same name
podman rm -f "$NAME" >/dev/null 2>&1 || true

case "$MODE" in
  pull)
    # Network ENABLED so the model can be downloaded
    podman run -d "${COMMON_FLAGS[@]}" "$IMAGE" >/dev/null
    echo "Waiting for the Ollama server to start..."
    sleep 5
    podman exec -it "$NAME" ollama pull "$MODEL"
    podman stop "$NAME" >/dev/null
    echo "Done. Model '$MODEL' is stored in volume '$VOLUME'."
    ;;

  chat)
    # Network DISABLED: the model cannot phone home or exfiltrate anything
    podman run -d --network=none "${COMMON_FLAGS[@]}" "$IMAGE" >/dev/null
    echo "Waiting for the Ollama server to start..."
    sleep 5
    # Always stop the container when the chat session ends
    trap 'podman stop "$NAME" >/dev/null 2>&1 || true' EXIT
    podman exec -it "$NAME" ollama run "$MODEL"
    ;;

  *)
    echo "Unknown mode: $MODE (use 'pull' or 'chat')" >&2
    exit 1
    ;;
esac