#!/bin/bash

#####################################################################
# Quick Update Script - For VPS
# Use this after initial deployment to quickly update the application
#####################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Quick Update - SmartGardenHub${NC}"
echo ""

# Navigate to app directory
cd /var/www/school

# Pull latest changes
echo -e "${YELLOW}📥 Pulling latest code...${NC}"
git pull origin main

# Install any new dependencies
echo -e "${YELLOW}📦 Updating dependencies...${NC}"
source venv/bin/activate
pip install -r requirements.txt

# Restart service
echo -e "${YELLOW}🔄 Restarting service...${NC}"
sudo systemctl restart saro

# Wait for restart
sleep 2

# Check status
if systemctl is-active --quiet saro; then
    echo -e "${GREEN}✅ Update completed successfully!${NC}"
    sudo systemctl status saro --no-pager | head -10
else
    echo -e "${YELLOW}⚠️  Service may have issues, checking logs...${NC}"
    sudo journalctl -u saro -n 20 --no-pager
fi

echo ""
echo -e "${GREEN}🎉 Done!${NC}"
