#!/usr/bin/env bash
# Full State Backup — backs up everything needed to restore this exact machine
# Includes: runtime state, agent memories, sessions, .env, device identity
# Destination: Google Drive > MilkbotBackups/full-state/ (mounted via Google Drive for Desktop)
set -euo pipefail

HOME_DIR="${HOME}"
BACKUP_ENV="${HOME_DIR}/.backup-env"
OPENCLAW_DIR="${HOME_DIR}/.openclaw"
PROJECTS_DIR="${HOME_DIR}/Projects/Binary Rogue"
GDRIVE_DIR="${HOME_DIR}/Library/CloudStorage/GoogleDrive-iambinaryrogue@gmail.com/My Drive/MilkbotBackups/full-state"
BACKUP_DIR="/tmp/backups"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="openclaw-full-${TIMESTAMP}"
LOG_TAG="[full-backup]"

# Load backup passphrase
if [ -f "${BACKUP_ENV}" ]; then
  set -a
  source "${BACKUP_ENV}"
  set +a
fi

echo "${LOG_TAG} [$(date)] Starting full state backup: ${BACKUP_NAME}"

# Verify Google Drive is mounted
if [ ! -d "${GDRIVE_DIR}" ]; then
  echo "${LOG_TAG} [ERROR] Google Drive not mounted at ${GDRIVE_DIR}" >&2
  exit 1
fi

# Clean up old temp files
rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# Create tarball of runtime state
echo "${LOG_TAG} [$(date)] Archiving .openclaw/ and .backup-env..."
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
  --exclude='*/node_modules' \
  --exclude='*/dist' \
  --exclude='*/.git' \
  --exclude='*/browser/profiles/*/Default/Service Worker' \
  --exclude='*/browser/profiles/*/Default/Cache' \
  --exclude='*/logs/*.log' \
  -C "${HOME_DIR}" \
  .openclaw/ \
  .backup-env \
  2>&1 | grep -v "Removing leading" || true

# Encrypt with gpg (symmetric, AES256 — compatible with VPS backups)
if [ -n "${BACKUP_PASSPHRASE:-}" ]; then
  echo "${LOG_TAG} [$(date)] Encrypting with AES256..."
  echo "${BACKUP_PASSPHRASE}" | gpg --batch --yes --symmetric \
    --cipher-algo AES256 --passphrase-fd 0 \
    -o "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg" \
    "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
  rm "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
  FINAL_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.gpg"
else
  echo "${LOG_TAG} [WARN] BACKUP_PASSPHRASE not set — saving unencrypted. Set it in ~/.backup-env" >&2
  FINAL_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
fi

# Copy to Google Drive (local mount — no rclone needed)
echo "${LOG_TAG} [$(date)] Copying to Google Drive..."
cp "${FINAL_FILE}" "${GDRIVE_DIR}/"

# Prune old backups — keep last 14 (7 days at 2x/day)
echo "${LOG_TAG} [$(date)] Pruning old backups (keeping last 14)..."
ls -1t "${GDRIVE_DIR}"/openclaw-full-*.tar.gz* 2>/dev/null | tail -n +15 | while read -r old; do
  echo "${LOG_TAG}   Deleting: $(basename "${old}")"
  rm -f "${old}"
done

# Cleanup temp
rm -rf "${BACKUP_DIR}"

FINAL_SIZE=$(du -sh "${GDRIVE_DIR}" 2>/dev/null | cut -f1)
echo "${LOG_TAG} [$(date)] Full backup complete. Drive folder size: ${FINAL_SIZE}"
