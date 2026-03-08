#!/bin/bash
#
# Quick Deploy Script - Fast deployment without full optimization
# Use this for code updates when database doesn't need optimization
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_DIR="/var/www/school"
SERVICE_NAME="saro.service"

echo -e "${GREEN}🚀 Quick Deploy Starting...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run with sudo${NC}"
    exit 1
fi

cd $APP_DIR

# Stash any local changes
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  Stashing local changes..."
    git stash
fi

# Pull latest code
echo "📥 Pulling latest code from GitHub..."
git fetch origin
git pull --rebase origin main

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Git pull failed${NC}"
    echo "Check status: cd $APP_DIR && git status"
    exit 1
fi

# Restore stashed changes if any
if git stash list | grep -q "stash@{0}"; then
    git stash pop 2>/dev/null || echo "⚠️  Could not restore stashed changes"
fi

# Restart service
echo "🔄 Restarting service..."
systemctl restart $SERVICE_NAME

# Wait and check status
sleep 2

if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✅ Service restarted successfully${NC}"
    echo ""
    echo "Last commit:"
    git log -1 --oneline
    echo ""
    echo "Service status:"
    systemctl status $SERVICE_NAME --no-pager -l | head -10
else
    echo -e "${RED}❌ Service failed to start${NC}"
    echo "Check logs: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
