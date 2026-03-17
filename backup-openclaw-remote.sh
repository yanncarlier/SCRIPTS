#!/usr/bin/env bash
# ============================================================
# backup-openclaw-remote.sh
# Backs up OpenClaw from a remote machine (non-LXD) via SSH/SCP
# ============================================================
set -euo pipefail

# ─── CONFIG ──────────────────────────────────────────────────
REMOTE_USER="user"                 # <-- set your remote username
REMOTE_HOST="host.example.local"   # <-- set your remote host IP or hostname
REMOTE_PORT="22"
SSH_KEY=""                        # e.g. ~/.ssh/id_ed25519 — leave empty to use default
BACKUP_DIR="./"                   # local destination folder
# ─────────────────────────────────────────────────────────────

# Derive home directory from user (handles root → /root, others → /home/user)
if [[ "${REMOTE_USER}" == "root" ]]; then
    REMOTE_HOME="/root"
else
    REMOTE_HOME="/home/${REMOTE_USER}"
fi

REMOTE_BACKUP_DIR="${REMOTE_HOME}/.openclaw"  # folder to backup

# Build SSH options
SSH_OPTS="-p ${REMOTE_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=10"
[[ -n "${SSH_KEY}" ]] && SSH_OPTS="${SSH_OPTS} -i ${SSH_KEY}"

# Shorthand wrappers
ssh_exec() { ssh ${SSH_OPTS} "${REMOTE_USER}@${REMOTE_HOST}" "$@"; }
scp_pull() { scp ${SSH_OPTS//-p/-P} "$@"; }   # scp uses -P (uppercase) for port

# ─── MAIN ─────────────────────────────────────────────────────
echo "==> [0/4] Retrieving remote hostname..."
MACHINE_NAME=$(ssh_exec "hostname -s" | tr -d '[:space:]')
echo "    Machine name: ${MACHINE_NAME}"

echo "==> [1/4] Stopping OpenClaw gateway on ${REMOTE_HOST}..."
ssh_exec "${REMOTE_HOME}/.npm-global/bin/openclaw gateway stop"

echo "==> [2/4] Creating backup archive on remote..."
BACKUP_FILENAME=$(ssh_exec "bash -c 'FNAME=\"${REMOTE_HOME}/${MACHINE_NAME}-openclaw-backup-\$(date +%Y%m%d-%H%M).tar.gz\"; tar -czf \"\$FNAME\" -C ${REMOTE_BACKUP_DIR} . && echo \"\$FNAME\"'")
echo "    Remote archive: ${BACKUP_FILENAME}"

echo "==> [3/4] Restarting OpenClaw gateway..."
ssh_exec "${REMOTE_HOME}/.npm-global/bin/openclaw gateway start"

echo "==> [4/4] Pulling backup to local machine..."
mkdir -p "${BACKUP_DIR}"
scp_pull "${REMOTE_USER}@${REMOTE_HOST}:${BACKUP_FILENAME}" "${BACKUP_DIR}/"

LOCAL_FILE="${BACKUP_DIR}/$(basename "${BACKUP_FILENAME}")"
echo ""
echo "✔  Backup complete: ${LOCAL_FILE}"
echo "   Size: $(du -sh "${LOCAL_FILE}" | cut -f1)"
