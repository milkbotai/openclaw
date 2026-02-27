#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Binary Rogue — Migrate to Mac
# Run this script ON your MacBook to set up everything.
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

GITHUB_USER="milkbotai"
GDRIVE_FOLDER="MilkbotBackups"
STATE_DIR="$HOME/.openclaw"
WORKSPACE="$HOME/Developer"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Binary Rogue — Mac Migration Script        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# -------------------------------------------------------
# Step 1: Check prerequisites
# -------------------------------------------------------
echo -e "${YELLOW}[1/8] Checking prerequisites...${NC}"

if ! command -v brew &>/dev/null; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "  Homebrew: OK"
fi

if ! command -v node &>/dev/null || [[ "$(node -v | sed 's/v//' | cut -d. -f1)" -lt 22 ]]; then
  echo "  Installing Node.js 22+..."
  brew install node
else
  echo "  Node.js: OK ($(node -v))"
fi

if ! command -v pnpm &>/dev/null; then
  echo "  Installing pnpm..."
  brew install pnpm
else
  echo "  pnpm: OK ($(pnpm -v))"
fi

if ! command -v git &>/dev/null; then
  echo "  Installing git..."
  brew install git
else
  echo "  git: OK"
fi

if ! command -v rclone &>/dev/null; then
  echo "  Installing rclone (for Google Drive backups)..."
  brew install rclone
else
  echo "  rclone: OK"
fi

if ! command -v gpg &>/dev/null; then
  echo "  Installing gnupg (for backup decryption)..."
  brew install gnupg
else
  echo "  gpg: OK"
fi

echo -e "${GREEN}  All prerequisites installed.${NC}"
echo ""

# -------------------------------------------------------
# Step 2: Configure git
# -------------------------------------------------------
echo -e "${YELLOW}[2/8] Configuring git...${NC}"
git config --global user.name "$GITHUB_USER"
git config --global user.email "luciusmilko@outlook.com"
echo "  Git identity: $GITHUB_USER <luciusmilko@outlook.com>"
echo ""

# -------------------------------------------------------
# Step 3: Create workspace
# -------------------------------------------------------
echo -e "${YELLOW}[3/8] Setting up workspace at $WORKSPACE...${NC}"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
echo "  Workspace: $WORKSPACE"
echo ""

# -------------------------------------------------------
# Step 4: Clone repos
# -------------------------------------------------------
echo -e "${YELLOW}[4/8] Cloning repositories...${NC}"

clone_repo() {
  local repo=$1
  local dir=$2
  if [ -d "$dir" ]; then
    echo "  $dir already exists, pulling latest..."
    cd "$dir" && git pull --rebase && cd "$WORKSPACE"
  else
    echo "  Cloning $repo..."
    git clone "https://github.com/$GITHUB_USER/$repo.git" "$dir"
  fi
}

clone_repo "openclaw" "openclaw"
clone_repo "Agents" "Agents"
clone_repo "Binaryrogue-website" "binaryrogue"

echo -e "${GREEN}  All repos cloned.${NC}"
echo ""

# -------------------------------------------------------
# Step 5: Configure rclone for Google Drive
# -------------------------------------------------------
echo -e "${YELLOW}[5/8] Setting up Google Drive access...${NC}"

if ! rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
  echo ""
  echo -e "${YELLOW}  rclone needs to be configured for Google Drive.${NC}"
  echo "  This will open a browser for Google OAuth."
  echo ""
  read -p "  Press Enter to start rclone config (or Ctrl+C to skip)..."
  rclone config create gdrive drive
else
  echo "  rclone gdrive remote: OK"
fi
echo ""

# -------------------------------------------------------
# Step 6: Download and restore full-state backup
# -------------------------------------------------------
echo -e "${YELLOW}[6/8] Restoring full-state backup from Google Drive...${NC}"

LATEST_BACKUP=$(rclone ls "gdrive:$GDRIVE_FOLDER/full-state/" 2>/dev/null | sort -k2 | tail -1 | awk '{print $2}')

if [ -z "$LATEST_BACKUP" ]; then
  echo -e "${RED}  No backups found in gdrive:$GDRIVE_FOLDER/full-state/${NC}"
  echo "  You'll need to set up ~/.openclaw manually or run a backup on your server first."
else
  echo "  Latest backup: $LATEST_BACKUP"
  TEMP_DIR=$(mktemp -d)

  echo "  Downloading..."
  rclone copy "gdrive:$GDRIVE_FOLDER/full-state/$LATEST_BACKUP" "$TEMP_DIR/"

  if [[ "$LATEST_BACKUP" == *.gpg ]]; then
    echo ""
    echo -e "${YELLOW}  Backup is encrypted. Enter your backup passphrase.${NC}"
    echo "  (This is the BACKUP_PASSPHRASE from /root/.backup-env on your server)"
    echo ""
    read -sp "  Passphrase: " PASSPHRASE
    echo ""

    DECRYPTED="${TEMP_DIR}/${LATEST_BACKUP%.gpg}"
    gpg --batch --yes --passphrase "$PASSPHRASE" --decrypt "$TEMP_DIR/$LATEST_BACKUP" > "$DECRYPTED"
    ARCHIVE="$DECRYPTED"
  else
    ARCHIVE="$TEMP_DIR/$LATEST_BACKUP"
  fi

  if [ -d "$STATE_DIR" ]; then
    echo ""
    echo -e "${YELLOW}  WARNING: $STATE_DIR already exists.${NC}"
    read -p "  Overwrite? (y/N): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      echo "  Skipping restore. Existing state preserved."
      ARCHIVE=""
    fi
  fi

  if [ -n "${ARCHIVE:-}" ]; then
    echo "  Extracting to home directory..."
    mkdir -p "$STATE_DIR"
    tar -xzf "$ARCHIVE" -C "$HOME/" 2>/dev/null || tar -xzf "$ARCHIVE" -C "/" 2>/dev/null
    echo -e "${GREEN}  State restored to $STATE_DIR${NC}"
  fi

  rm -rf "$TEMP_DIR"
fi
echo ""

# -------------------------------------------------------
# Step 7: Install OpenClaw dependencies
# -------------------------------------------------------
echo -e "${YELLOW}[7/8] Installing OpenClaw dependencies...${NC}"
cd "$WORKSPACE/openclaw"
pnpm install
echo -e "${GREEN}  Dependencies installed.${NC}"
echo ""

# -------------------------------------------------------
# Step 8: Build
# -------------------------------------------------------
echo -e "${YELLOW}[8/8] Building OpenClaw...${NC}"
pnpm build
echo -e "${GREEN}  Build complete.${NC}"
echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Migration Complete!                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Workspace:    $WORKSPACE"
echo "  OpenClaw:     $WORKSPACE/openclaw"
echo "  Agents:       $WORKSPACE/Agents"
echo "  Website:      $WORKSPACE/binaryrogue"
echo "  State:        $STATE_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Check your .env file:"
echo "     cat ~/.openclaw/.env"
echo "     (Make sure API keys are set: ANTHROPIC_API_KEY, etc.)"
echo ""
echo "  2. Build the Mac app (optional):"
echo "     cd $WORKSPACE/openclaw"
echo "     ./scripts/package-mac-app.sh"
echo ""
echo "  3. Or install the CLI globally:"
echo "     cd $WORKSPACE/openclaw && npm install -g ./"
echo ""
echo "  4. Run the health check:"
echo "     openclaw doctor"
echo ""
echo "  5. Start the gateway:"
echo "     openclaw gateway run"
echo ""
echo -e "${GREEN}Your VPS is still running 24/7. This Mac setup${NC}"
echo -e "${GREEN}gives you the full desktop experience alongside it.${NC}"
echo ""
