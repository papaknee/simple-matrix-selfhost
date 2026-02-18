#!/bin/bash
set -e

# =============================================================================
# Lightsail Startup Script
# =============================================================================
# This script can be pasted into the Lightsail "Launch Script" (user-data)
# field to automatically bootstrap a Matrix server from an S3-based config.
#
# Prerequisites:
#   1. An S3 bucket with your .env file uploaded (e.g. s3://my-matrix-config/.env)
#   2. A Lightsail instance with the "Amazon Linux 2" or "Ubuntu 22.04" blueprint
#   3. The instance must have an IAM policy allowing s3:GetObject on your bucket
#      (attach via Lightsail instance profile or use access keys below)
#
# Usage (Option A - Lightsail Launch Script):
#   Paste this entire script into the "Launch Script" field when creating
#   your Lightsail instance. Set the variables below before pasting.
#
# Usage (Option B - Run manually on a fresh instance):
#   1. SSH into your Lightsail instance
#   2. Save this script: nano lightsail-startup.sh
#   3. Set your variables below
#   4. Run: sudo bash lightsail-startup.sh
#
# What this script does:
#   1. Installs git, AWS CLI, Docker Engine with compose plugin
#   2. Downloads your .env config file from S3
#   3. Clones the simple-matrix-selfhost repository
#   4. Runs the full installation (SSL certs, Synapse config, Docker services)
#   5. Logs everything to /var/log/matrix-startup.log
# =============================================================================

# ======================== CONFIGURE THESE VALUES =============================
# S3 bucket and path where your .env file is stored
S3_CONFIG_BUCKET="${S3_CONFIG_BUCKET:-}"           # e.g. "my-matrix-config"
S3_CONFIG_PATH="${S3_CONFIG_PATH:-.env}"            # e.g. ".env" or "matrix/.env"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Optional: AWS credentials (not needed if using an instance profile/IAM role)
# It is recommended to use an IAM role attached to your Lightsail instance instead.
# AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
# AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

# Installation directory
INSTALL_DIR="${INSTALL_DIR:-/opt/matrix-server}"

# Git repository
REPO_URL="${REPO_URL:-https://github.com/papaknee/simple-matrix-selfhost.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
# =============================================================================

LOG_FILE="/var/log/matrix-startup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "========================================="
log "Matrix Server Lightsail Startup"
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
    apt-get install -y git curl unzip ca-certificates gnupg >> "$LOG_FILE" 2>&1
elif [ "$OS_ID" = "amzn" ]; then
    yum update -y >> "$LOG_FILE" 2>&1
    yum install -y git curl unzip >> "$LOG_FILE" 2>&1
else
    log "WARNING: Unsupported OS '$OS_ID'. Attempting Ubuntu-style install (may fail on incompatible systems)..."
    apt-get update -y >> "$LOG_FILE" 2>&1 || { log "ERROR: Package manager failed. This script requires Ubuntu or Amazon Linux."; exit 1; }
    apt-get install -y git curl unzip ca-certificates gnupg >> "$LOG_FILE" 2>&1
fi

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
    log "Installing AWS CLI v2..."
    cd /tmp
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >> "$LOG_FILE" 2>&1
    unzip -q -o awscliv2.zip >> "$LOG_FILE" 2>&1
    ./aws/install >> "$LOG_FILE" 2>&1
    rm -rf aws awscliv2.zip
    log "AWS CLI installed: $(aws --version)"
else
    log "AWS CLI already installed: $(aws --version)"
fi

# Clone repository
log "Cloning repository to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    log "Directory $INSTALL_DIR already exists, pulling latest..."
    cd "$INSTALL_DIR"
    git pull origin "$REPO_BRANCH" >> "$LOG_FILE" 2>&1 || true
else
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
    cd "$INSTALL_DIR"
fi

# Download .env from S3
if [ -n "$S3_CONFIG_BUCKET" ]; then
    log "Downloading .env from S3: s3://$S3_CONFIG_BUCKET/$S3_CONFIG_PATH"
    aws s3 cp "s3://$S3_CONFIG_BUCKET/$S3_CONFIG_PATH" "$INSTALL_DIR/.env" \
        --region "$AWS_DEFAULT_REGION" >> "$LOG_FILE" 2>&1

    if [ ! -f "$INSTALL_DIR/.env" ]; then
        log "ERROR: Failed to download .env from S3"
        exit 1
    fi
    log ".env downloaded successfully"
else
    log "No S3_CONFIG_BUCKET set. Checking for existing .env file..."
    if [ ! -f "$INSTALL_DIR/.env" ]; then
        log "No .env file found. Copying .env.example..."
        cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
        log "WARNING: Using default .env.example - you MUST edit $INSTALL_DIR/.env before the server will work correctly"
        log "Edit with: nano $INSTALL_DIR/.env"
        log "Then re-run: cd $INSTALL_DIR && sudo ./install.sh"
        exit 0
    fi
fi

# Run installation
log "Running Matrix server installation..."
cd "$INSTALL_DIR"
chmod +x install.sh create-admin-user.sh update.sh
bash install.sh >> "$LOG_FILE" 2>&1

# Install systemd timers for auto-updates
log "Setting up systemd timers..."
if [ -f "$INSTALL_DIR/matrix-update.service" ]; then
    # Update the service file to point to actual install dir
    sed "s|/opt/matrix-server|$INSTALL_DIR|g" "$INSTALL_DIR/matrix-update.service" > /etc/systemd/system/matrix-update.service
    cp "$INSTALL_DIR/matrix-update.timer" /etc/systemd/system/matrix-update.timer
    cp "$INSTALL_DIR/matrix-reboot.service" /etc/systemd/system/matrix-reboot.service
    cp "$INSTALL_DIR/matrix-reboot.timer" /etc/systemd/system/matrix-reboot.timer
    systemctl daemon-reload
    systemctl enable --now matrix-update.timer >> "$LOG_FILE" 2>&1 || true
    systemctl enable --now matrix-reboot.timer >> "$LOG_FILE" 2>&1 || true
    log "Systemd timers enabled"
fi

log "========================================="
log "Startup complete!"
log "========================================="
log ""
log "Next steps:"
log "  1. Wait 2-3 minutes for all services to start"
log "  2. Create admin user: cd $INSTALL_DIR && sudo ./create-admin-user.sh"
log "  3. Access your server: https://$(grep MATRIX_DOMAIN $INSTALL_DIR/.env | cut -d= -f2)"
log "  4. Admin console: https://$(grep MATRIX_DOMAIN $INSTALL_DIR/.env | cut -d= -f2)/admin/"
log ""
log "Full log: $LOG_FILE"
