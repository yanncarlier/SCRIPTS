#!/usr/bin/env bash
# Everyday nerdctl management commands.
# Usage: bash manage.sh <command> [container-name-or-id]
#
# Examples:
#   bash manage.sh list
#   bash manage.sh logs web
#   bash manage.sh shell web
set -euo pipefail

NERDCTL="sudo nerdctl"
CMD="${1:-help}"
TARGET="${2:-}"

# Make sure a container name/ID was given for commands that need one
require_target() {
  if [[ -z "$TARGET" ]]; then
    echo "Error: '$CMD' needs a container name or ID." >&2
    echo "Usage: bash manage.sh $CMD <container>" >&2
    exit 1
  fi
}

case "$CMD" in
  list)
    # Running containers
    $NERDCTL ps
    ;;
  list-all)
    # Running AND stopped containers
    $NERDCTL ps -a
    ;;
  stats)
    # Live CPU / memory usage (press Ctrl+C to quit)
    $NERDCTL stats
    ;;
  top)
    # Processes running inside a container
    require_target
    $NERDCTL top "$TARGET"
    ;;
  logs)
    # Follow the last 50 log lines of a container (Ctrl+C to quit)
    require_target
    $NERDCTL logs -f --tail 50 "$TARGET"
    ;;
  inspect)
    # Full details: IP address, mounts, env vars, ports...
    require_target
    $NERDCTL inspect "$TARGET"
    ;;
  shell)
    # Open an interactive shell inside a running container
    # (falls back to sh if bash isn't installed in the image)
    require_target
    $NERDCTL exec -it "$TARGET" bash 2>/dev/null || $NERDCTL exec -it "$TARGET" sh
    ;;
  stop)
    require_target
    $NERDCTL stop "$TARGET"
    ;;
  start)
    require_target
    $NERDCTL start "$TARGET"
    ;;
  restart)
    require_target
    $NERDCTL restart "$TARGET"
    ;;
  rm)
    # Force-remove a container (stops it first if running)
    require_target
    $NERDCTL rm -f "$TARGET"
    ;;
  stop-all)
    # Stop every running container
    RUNNING="$($NERDCTL ps -q)"
    if [[ -n "$RUNNING" ]]; then
      # shellcheck disable=SC2086
      $NERDCTL stop $RUNNING
    else
      echo "No running containers."
    fi
    ;;
  images)
    $NERDCTL images
    ;;
  volumes)
    $NERDCTL volume ls
    ;;
  networks)
    $NERDCTL network ls
    ;;
  disk)
    # How much space images, containers and volumes use
    $NERDCTL system df
    ;;
  clean)
    # Remove stopped containers, unused networks and dangling images
    $NERDCTL system prune -f
    ;;
  help|*)
    cat <<'EOF'
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
EOF
    ;;
esac