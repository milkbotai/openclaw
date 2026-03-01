#!/usr/bin/env bash
# Clean Deployable Backup — a fresh copy anyone can clone and run
# Includes: code repos (without runtime state, secrets, or memories)
# Destination: Google Drive > MilkbotBackups/clean-deploy/ (mounted via Google Drive for Desktop)
set -euo pipefail

HOME_DIR="${HOME}"
PROJECTS_DIR="${HOME_DIR}/Projects/Binary Rogue"
GDRIVE_DIR="${HOME_DIR}/Library/CloudStorage/GoogleDrive-iambinaryrogue@gmail.com/My Drive/MilkbotBackups/clean-deploy"
BACKUP_DIR="/tmp/backups"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="openclaw-clean-${TIMESTAMP}"
LOG_TAG="[clean-backup]"

echo "${LOG_TAG} [$(date)] Starting clean deployable backup: ${BACKUP_NAME}"

# Verify Google Drive is mounted
if [ ! -d "${GDRIVE_DIR}" ]; then
  echo "${LOG_TAG} [ERROR] Google Drive not mounted at ${GDRIVE_DIR}" >&2
  exit 1
fi

rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Export each repo as a clean archive (no .git history bloat)
echo "${LOG_TAG} [$(date)] Archiving openclaw fork..."
git -C "${PROJECTS_DIR}/openclaw" archive HEAD | tar -x -C "${BACKUP_DIR}/${BACKUP_NAME}/"

echo "${LOG_TAG} [$(date)] Archiving binaryrogue repo..."
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/binaryrogue"
git -C "${PROJECTS_DIR}/binaryrogue" archive HEAD | tar -x -C "${BACKUP_DIR}/${BACKUP_NAME}/binaryrogue/"

# Include knowledge-api if it's a git repo
if git -C "${PROJECTS_DIR}/knowledge-api" rev-parse --is-inside-work-tree &>/dev/null; then
  echo "${LOG_TAG} [$(date)] Archiving knowledge-api repo..."
  mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/knowledge-api"
  git -C "${PROJECTS_DIR}/knowledge-api" archive HEAD | tar -x -C "${BACKUP_DIR}/${BACKUP_NAME}/knowledge-api/"
fi

# Include a setup guide
cat > "${BACKUP_DIR}/${BACKUP_NAME}/SETUP.md" << 'SETUP'
# OpenClaw Clean Deploy

## Quick Start
```bash
cd openclaw
pnpm install
pnpm build
openclaw onboard --install-daemon
```

## What you need
- Node.js 22+
- pnpm (`npm install -g pnpm`)
- API keys for your preferred AI provider (see .env.example)

## Repos included
- `openclaw/` — Main AI gateway (milkbotai fork)
- `binaryrogue/` — Binary Rogue website
- `knowledge-api/` — Knowledge base API
SETUP

# Create tarball
echo "${LOG_TAG} [$(date)] Compressing..."
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "${BACKUP_DIR}" "${BACKUP_NAME}/"

# Copy to Google Drive
echo "${LOG_TAG} [$(date)] Copying to Google Drive..."
cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "${GDRIVE_DIR}/"

# Prune — keep last 7 clean snapshots
echo "${LOG_TAG} [$(date)] Pruning old clean backups (keeping last 7)..."
ls -1t "${GDRIVE_DIR}"/openclaw-clean-*.tar.gz 2>/dev/null | tail -n +8 | while read -r old; do
  echo "${LOG_TAG}   Deleting: $(basename "${old}")"
  rm -f "${old}"
done

# Cleanup temp
rm -rf "${BACKUP_DIR}"

echo "${LOG_TAG} [$(date)] Clean deployable backup complete."
