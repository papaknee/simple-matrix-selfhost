#!/bin/bash
set -e

# =============================================================================
# Lightsail Launch Script (Pre-install Only)
# =============================================================================
# This script can be pasted into the Lightsail "Launch Script" (user-data)
# field when creating your instance. It pre-installs dependencies and clones
# the repository so the server is ready for setup when you SSH in.
#
# IMPORTANT: This script does NOT run the full Matrix installation because
# networking (static IP, firewall, DNS) must be configured first via the
# Lightsail console. After configuring networking and DNS, SSH in and run
# the interactive setup script.
#
# What this script does:
#   1. Installs git, curl, and other prerequisites
#   2. Clones the simple-matrix-selfhost repository to /opt/matrix-server
#   3. Logs output to /var/log/matrix-startup.log
#
# After the instance starts, configure networking and DNS, then SSH in and run:
#   cd /opt/matrix-server && sudo ./setup.sh
# =============================================================================

INSTALL_DIR="${INSTALL_DIR:-/opt/matrix-server}"
REPO_URL="${REPO_URL:-https://github.com/papaknee/simple-matrix-selfhost.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

LOG_FILE="/var/log/matrix-startup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "========================================="
log "Matrix Server Pre-Install"
log "========================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
else
    OS_ID="unknown"
fi

log "Detected OS: $OS_ID"

# Install prerequisites
log "Installing prerequisites..."
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >> "$LOG_FILE" 2>&1
    apt-get install -y git curl ca-certificates gnupg >> "$LOG_FILE" 2>&1
elif [ "$OS_ID" = "amzn" ]; then
    yum update -y >> "$LOG_FILE" 2>&1
    yum install -y git curl >> "$LOG_FILE" 2>&1
else
    log "WARNING: Unsupported OS '$OS_ID'. Attempting Ubuntu-style install..."
    apt-get update -y >> "$LOG_FILE" 2>&1 || { log "ERROR: Package manager failed."; exit 1; }
    apt-get install -y git curl ca-certificates gnupg >> "$LOG_FILE" 2>&1
fi

# Clone repository
log "Cloning repository to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    log "Directory $INSTALL_DIR already exists, pulling latest..."
    cd "$INSTALL_DIR"
    git pull origin "$REPO_BRANCH" >> "$LOG_FILE" 2>&1 || true
else
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
fi

chmod +x "$INSTALL_DIR/setup.sh" "$INSTALL_DIR/install.sh" "$INSTALL_DIR/create-admin-user.sh" "$INSTALL_DIR/update.sh"

log "========================================="
log "Pre-install complete!"
log "========================================="
log ""
log "Next steps:"
log "  1. Go to the Lightsail console and configure networking:"
log "     - Attach a static IP to this instance"
log "     - Open firewall ports: 80, 443, 8448, 22"
log "  2. Point your domain's DNS A record to the static IP"
log "  3. Wait 5-10 minutes for DNS to propagate"
log "  4. SSH in and run: cd $INSTALL_DIR && sudo ./setup.sh"
log ""
log "Full log: $LOG_FILE"
