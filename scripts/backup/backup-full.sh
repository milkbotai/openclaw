#!/usr/bin/env bash
# Full State Backup — backs up everything needed to restore this exact server
# Includes: runtime state, agent memories, sessions, .env, device identity
# Destination: Google Drive > MilkbotBackups/full-state/
set -euo pipefail

# Load backup passphrase
if [ -f /root/.backup-env ]; then
  set -a
  source /root/.backup-env
  set +a
fi

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="openclaw-full-${TIMESTAMP}"
BACKUP_DIR="/tmp/backups"
GDRIVE_REMOTE="gdrive:MilkbotBackups/full-state"

echo "[$(date)] Starting full state backup: ${BACKUP_NAME}"

# Clean up old temp files
rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# Create encrypted tarball of runtime state
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
  --exclude='*/node_modules' \
  --exclude='*/dist' \
  --exclude='*/.git' \
  -C /root \
  .openclaw/ \
  Agents/ \
  2>&1 | grep -v "Removing leading" || true

# Encrypt with gpg (symmetric, passphrase from env or prompt)
if [ -n "${BACKUP_PASSPHRASE:-}" ]; then
  echo "${BACKUP_PASSPHRASE}" | gpg --batch --yes --symmetric \
    --cipher-algo AES256 --passphrase-fd 0 \
    -o "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg" \
    "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
  rm "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
  UPLOAD_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg"
else
  echo "[WARN] BACKUP_PASSPHRASE not set — uploading unencrypted. Set it in /root/.backup-env"
  UPLOAD_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
fi

# Upload to Google Drive
echo "[$(date)] Uploading to ${GDRIVE_REMOTE}/"
rclone copy "${UPLOAD_FILE}" "${GDRIVE_REMOTE}/" --progress

# Prune old backups — keep last 14 (7 days at 2x/day)
echo "[$(date)] Pruning old backups (keeping last 14)..."
rclone lsf "${GDRIVE_REMOTE}/" --files-only | sort | head -n -14 | while read -r old; do
  echo "  Deleting: ${old}"
  rclone deletefile "${GDRIVE_REMOTE}/${old}"
done

# Cleanup temp
rm -rf "${BACKUP_DIR}"

SIZE=$(rclone size "${GDRIVE_REMOTE}/" --json 2>/dev/null | grep -o '"bytes":[0-9]*' | grep -o '[0-9]*')
SIZE_MB=$((SIZE / 1024 / 1024))
echo "[$(date)] Full backup complete. Total backup size on Drive: ${SIZE_MB}MB"
