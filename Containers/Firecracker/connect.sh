#!/usr/bin/env bash
# connect.sh - SSH into the running microVM and fix up routing/DNS for internet access.
set -euo pipefail

WORKDIR="${HOME}/firecracker-demo"
GUEST_IP="172.16.0.2"
HOST_TAP_IP="172.16.0.1"

SSH_OPTS=(-i "${WORKDIR}/vm_key"
          -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR)

echo "Waiting for the VM to accept SSH..."
for _ in $(seq 1 30); do
  if ssh "${SSH_OPTS[@]}" -o ConnectTimeout=2 "root@${GUEST_IP}" true 2>/dev/null; then
    break
  fi
  sleep 1
done

# Give the guest a default route and DNS (idempotent)
ssh "${SSH_OPTS[@]}" "root@${GUEST_IP}" \
  "ip route replace default via ${HOST_TAP_IP} dev eth0 && echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

exec ssh "${SSH_OPTS[@]}" "root@${GUEST_IP}"