#!/usr/bin/env bash
# Master backup script — runs both full state and clean deployable backups
# Designed to be called by cron twice daily
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/openclaw-backup.log"

# Load backup passphrase if configured
if [ -f /root/.backup-env ]; then
  source /root/.backup-env
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
