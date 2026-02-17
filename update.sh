#!/bin/bash
set -e

# Auto-update and maintenance script for Matrix server
# This script updates Docker images and restarts services

LOG_FILE="/var/log/matrix-update.log"

echo "[$(date)] Starting Matrix server update..." >> $LOG_FILE

# Navigate to installation directory
cd /opt/matrix-server || exit 1

# Pull latest images
echo "[$(date)] Pulling latest Docker images..." >> $LOG_FILE
docker-compose pull >> $LOG_FILE 2>&1

# Restart services with new images
echo "[$(date)] Restarting services..." >> $LOG_FILE
docker-compose up -d >> $LOG_FILE 2>&1

# Clean up old images
echo "[$(date)] Cleaning up old images..." >> $LOG_FILE
docker image prune -af >> $LOG_FILE 2>&1

echo "[$(date)] Update complete!" >> $LOG_FILE
echo "" >> $LOG_FILE
