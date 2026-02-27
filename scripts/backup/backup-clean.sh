#!/usr/bin/env bash
# Clean Deployable Backup — a fresh copy anyone can clone and run
# Includes: code repos (without runtime state, secrets, or memories)
# Destination: Google Drive > MilkbotBackups/clean-deploy/
set -euo pipefail

# Load backup config
if [ -f /root/.backup-env ]; then
  set -a
  source /root/.backup-env
  set +a
fi

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_NAME="openclaw-clean-${TIMESTAMP}"
BACKUP_DIR="/tmp/backups"
GDRIVE_REMOTE="gdrive:MilkbotBackups/clean-deploy"

echo "[$(date)] Starting clean deployable backup: ${BACKUP_NAME}"

rm -rf "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Export each repo as a clean archive (no .git history bloat)
echo "[$(date)] Archiving openclaw fork..."
git -C /root/openclaw archive HEAD | tar -x -C "${BACKUP_DIR}/${BACKUP_NAME}/"

echo "[$(date)] Archiving Agents repo..."
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/Agents"
git -C /root/Agents archive HEAD | tar -x -C "${BACKUP_DIR}/${BACKUP_NAME}/Agents/"

echo "[$(date)] Archiving binaryrogue repo..."
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/binaryrogue"
git -C /root/binaryrogue archive HEAD | tar -x -C "${BACKUP_DIR}/${BACKUP_NAME}/binaryrogue/"

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
- `Agents/` — Agent doctrine and org chart
- `binaryrogue/` — Binary Rogue website
SETUP

# Create tarball
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "${BACKUP_DIR}" "${BACKUP_NAME}/"

# Upload to Google Drive
echo "[$(date)] Uploading to ${GDRIVE_REMOTE}/"
rclone copy "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "${GDRIVE_REMOTE}/" --progress

# Prune — keep last 7 clean snapshots
echo "[$(date)] Pruning old clean backups (keeping last 7)..."
rclone lsf "${GDRIVE_REMOTE}/" --files-only | sort | head -n -7 | while read -r old; do
  echo "  Deleting: ${old}"
  rclone deletefile "${GDRIVE_REMOTE}/${old}"
done

# Cleanup temp
rm -rf "${BACKUP_DIR}"

echo "[$(date)] Clean deployable backup complete."
