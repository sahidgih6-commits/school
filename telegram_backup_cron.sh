#!/bin/bash
#
# Daily Database Backup Cron Job Script
# This script is called by cron at 2 AM daily
#

# Set environment
export FLASK_ENV=production

# Paths
SCRIPT_DIR="/var/www/school"
PYTHON_BIN="/var/www/school/venv/bin/python3"
BACKUP_SCRIPT="$SCRIPT_DIR/telegram_backup.py"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/telegram_backup.log"

# Telegram Configuration (set these as environment variables)
# export TELEGRAM_BOT_TOKEN="your_bot_token_here"
# export TELEGRAM_CHAT_ID="your_chat_id_here"

# Database Configuration
export DATABASE_PATH="/var/www/school/smartgardenhub.db"
export BACKUP_DIR="/var/www/school/backups"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Run backup script and log output
echo "========================================" >> "$LOG_FILE"
echo "Backup started at: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

$PYTHON_BIN "$BACKUP_SCRIPT" >> "$LOG_FILE" 2>&1

echo "Backup finished at: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Keep only last 30 days of logs
find "$LOG_DIR" -name "telegram_backup.log.*" -mtime +30 -delete 2>/dev/null

# Rotate log if it's too large (> 10MB)
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]; then
    mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d)"
    touch "$LOG_FILE"
fi
