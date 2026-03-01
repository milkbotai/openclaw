#!/usr/bin/env bash
# Master backup script — runs both full state and clean deployable backups
# Designed to be called by launchd twice daily (8 AM and 8 PM)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/Library/Logs"
LOG_FILE="${LOG_DIR}/openclaw-backup.log"

mkdir -p "${LOG_DIR}"

# Load backup passphrase if configured
if [ -f "${HOME}/.backup-env" ]; then
  set -a
  source "${HOME}/.backup-env"
  set +a
fi

echo "========================================" >> "${LOG_FILE}"
echo "[$(date)] Backup run starting" >> "${LOG_FILE}"

# Run full state backup
echo "[$(date)] Running full state backup..." >> "${LOG_FILE}"
bash "${SCRIPT_DIR}/backup-full.sh" >> "${LOG_FILE}" 2>&1

# Run clean deployable backup (once daily at noon only)
HOUR=$(date +%H)
if [ "${HOUR}" -ge 11 ] && [ "${HOUR}" -le 13 ]; then
  echo "[$(date)] Running clean deployable backup..." >> "${LOG_FILE}"
  bash "${SCRIPT_DIR}/backup-clean.sh" >> "${LOG_FILE}" 2>&1
else
  echo "[$(date)] Skipping clean backup (only runs at noon)" >> "${LOG_FILE}"
fi

echo "[$(date)] Backup run complete" >> "${LOG_FILE}"
echo "========================================" >> "${LOG_FILE}"
