#!/usr/bin/env bash
# Restore full state from Google Drive backup
# Usage: ./restore-full.sh [backup-filename]
# If no filename given, restores the latest backup
set -euo pipefail

GDRIVE_REMOTE="gdrive:MilkbotBackups/full-state"
RESTORE_DIR="/tmp/restore"

# Find the latest backup if none specified
if [ -n "${1:-}" ]; then
  BACKUP_FILE="$1"
else
  echo "Finding latest backup..."
  BACKUP_FILE=$(rclone lsf "${GDRIVE_REMOTE}/" --files-only | sort | tail -1)
  if [ -z "${BACKUP_FILE}" ]; then
    echo "ERROR: No backups found on Google Drive"
    exit 1
  fi
fi

echo "Restoring from: ${BACKUP_FILE}"
echo ""
echo "WARNING: This will overwrite:"
echo "  /root/.openclaw/  (runtime state, memories, sessions)"
echo "  /root/Agents/     (agent doctrine)"
echo ""
read -p "Continue? (yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

rm -rf "${RESTORE_DIR}"
mkdir -p "${RESTORE_DIR}"

# Download
echo "Downloading backup..."
rclone copy "${GDRIVE_REMOTE}/${BACKUP_FILE}" "${RESTORE_DIR}/" --progress

# Decrypt if encrypted
if [[ "${BACKUP_FILE}" == *.gpg ]]; then
  echo "Decrypting..."
  if [ -f /root/.backup-env ]; then
    source /root/.backup-env
  fi
  if [ -n "${BACKUP_PASSPHRASE:-}" ]; then
    echo "${BACKUP_PASSPHRASE}" | gpg --batch --yes --passphrase-fd 0 \
      -d "${RESTORE_DIR}/${BACKUP_FILE}" > "${RESTORE_DIR}/backup.tar.gz"
  else
    gpg -d "${RESTORE_DIR}/${BACKUP_FILE}" > "${RESTORE_DIR}/backup.tar.gz"
  fi
  TARBALL="${RESTORE_DIR}/backup.tar.gz"
else
  TARBALL="${RESTORE_DIR}/${BACKUP_FILE}"
fi

# Stop the service before restoring
echo "Stopping openclaw-gateway..."
systemctl stop openclaw-gateway 2>/dev/null || true

# Restore
echo "Restoring files..."
tar xzf "${TARBALL}" -C /root/

# Restart
echo "Starting openclaw-gateway..."
systemctl start openclaw-gateway

# Cleanup
rm -rf "${RESTORE_DIR}"

echo ""
echo "Restore complete. Verify with:"
echo "  systemctl status openclaw-gateway"
echo "  ls -la /root/.openclaw/"
