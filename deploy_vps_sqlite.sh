#!/bin/bash

#####################################################################
# VPS Deployment Script - SmartGardenHub (Saro Student Management)
# SQLite Database + Port 8001
#####################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "════════════════════════════════════════════════════════════"
echo "  🚀 VPS DEPLOYMENT - SmartGardenHub (SQLite + Port 8001)"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Configuration
APP_DIR="/var/www/school"
SERVICE_NAME="saro"
VENV_DIR="$APP_DIR/venv"
PORT=8001

#####################################################################
# Step 1: Pre-deployment checks
#####################################################################
echo -e "\n${YELLOW}📋 Step 1: Pre-deployment checks...${NC}"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root or with sudo${NC}"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}❌ Application directory not found: $APP_DIR${NC}"
    echo -e "${YELLOW}Creating directory...${NC}"
    mkdir -p $APP_DIR
    echo -e "${GREEN}✅ Directory created${NC}"
fi

cd $APP_DIR
echo -e "${GREEN}✅ Changed to application directory: $APP_DIR${NC}"

#####################################################################
# Step 2: Stop existing service
#####################################################################
echo -e "\n${YELLOW}🛑 Step 2: Stopping existing service...${NC}"

if systemctl is-active --quiet $SERVICE_NAME; then
    systemctl stop $SERVICE_NAME
    echo -e "${GREEN}✅ Service stopped${NC}"
else
    echo -e "${YELLOW}⚠️  Service was not running${NC}"
fi

#####################################################################
# Step 3: Pull latest code from GitHub
#####################################################################
echo -e "\n${YELLOW}📥 Step 3: Pulling latest code from GitHub...${NC}"

# Initialize git if needed
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠️  Git repository not initialized${NC}"
    echo -e "${YELLOW}Please initialize git manually and then run this script again${NC}"
    exit 1
fi

# Stash any local changes
git stash

# Pull latest changes
git pull origin main

echo -e "${GREEN}✅ Latest code pulled from GitHub${NC}"

#####################################################################
# Step 4: Setup Python virtual environment
#####################################################################
echo -e "\n${YELLOW}🐍 Step 4: Setting up Python virtual environment...${NC}"

if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv $VENV_DIR
    echo -e "${GREEN}✅ Virtual environment created${NC}"
fi

# Activate virtual environment and install dependencies
source $VENV_DIR/bin/activate

echo -e "${YELLOW}Installing/updating dependencies...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${GREEN}✅ Dependencies installed${NC}"

#####################################################################
# Step 5: Configure environment for production
#####################################################################
echo -e "\n${YELLOW}⚙️  Step 5: Configuring environment...${NC}"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    cat > .env <<EOF
FLASK_ENV=production
PORT=8001
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
EOF
    echo -e "${GREEN}✅ Environment file created${NC}"
else
    echo -e "${YELLOW}⚠️  .env file already exists, skipping creation${NC}"
fi

#####################################################################
# Step 6: Initialize SQLite database
#####################################################################
echo -e "\n${YELLOW}💾 Step 6: Initializing SQLite database...${NC}"

# Set environment variable for production
export FLASK_ENV=production

# Initialize database
python3 -c "
from app import create_app
from models import db

app = create_app('production')
with app.app_context():
    db.create_all()
    print('Database tables created successfully!')
"

echo -e "${GREEN}✅ SQLite database initialized${NC}"

#####################################################################
# Step 7: Install systemd service
#####################################################################
echo -e "\n${YELLOW}🔧 Step 7: Installing systemd service...${NC}"

# Copy service file to systemd directory
if [ -f "saro_vps.service" ]; then
    cp saro_vps.service /etc/systemd/system/$SERVICE_NAME.service
    echo -e "${GREEN}✅ Service file copied${NC}"
else
    echo -e "${RED}❌ Service file not found: saro_vps.service${NC}"
    exit 1
fi

# Reload systemd daemon
systemctl daemon-reload
echo -e "${GREEN}✅ Systemd daemon reloaded${NC}"

# Enable service to start on boot
systemctl enable $SERVICE_NAME
echo -e "${GREEN}✅ Service enabled for auto-start${NC}"

#####################################################################
# Step 8: Configure firewall for port 8001
#####################################################################
echo -e "\n${YELLOW}🔥 Step 8: Configuring firewall...${NC}"

# Check if ufw is installed and active
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        ufw allow $PORT/tcp
        echo -e "${GREEN}✅ Firewall configured for port $PORT${NC}"
    else
        echo -e "${YELLOW}⚠️  UFW is installed but not active${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  UFW not installed, skipping firewall configuration${NC}"
fi

#####################################################################
# Step 9: Start the service
#####################################################################
echo -e "\n${YELLOW}🚀 Step 9: Starting the service...${NC}"

systemctl start $SERVICE_NAME

# Wait for service to start
sleep 3

#####################################################################
# Step 10: Verify deployment
#####################################################################
echo -e "\n${YELLOW}✅ Step 10: Verifying deployment...${NC}"

# Check service status
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✅ Service is running!${NC}"
    
    # Show service status
    systemctl status $SERVICE_NAME --no-pager | head -20
    
    # Test the endpoint
    echo -e "\n${YELLOW}Testing endpoint...${NC}"
    sleep 2
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health | grep -q "200"; then
        echo -e "${GREEN}✅ Application is responding on port $PORT${NC}"
    else
        echo -e "${YELLOW}⚠️  Application may not be responding yet, check logs${NC}"
    fi
else
    echo -e "${RED}❌ Service failed to start!${NC}"
    echo -e "${YELLOW}Checking logs:${NC}"
    journalctl -u $SERVICE_NAME -n 50 --no-pager
    exit 1
fi

#####################################################################
# Deployment Summary
#####################################################################
echo -e "\n${GREEN}"
echo "════════════════════════════════════════════════════════════"
echo "  ✅ DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "════════════════════════════════════════════════════════════"
echo -e "${NC}"

echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo -e "   Database: ${GREEN}SQLite${NC} (smartgardenhub_production.db)"
echo -e "   Port: ${GREEN}$PORT${NC}"
echo -e "   Service: ${GREEN}$SERVICE_NAME${NC}"
echo -e "   Status: ${GREEN}Running${NC}"
echo ""
echo -e "${BLUE}🌐 Access URLs:${NC}"
echo -e "   Local: ${GREEN}http://localhost:$PORT${NC}"
echo -e "   Public: ${GREEN}http://$(curl -s ifconfig.me):$PORT${NC}"
echo ""
echo -e "${BLUE}📝 Useful Commands:${NC}"
echo -e "   ${YELLOW}sudo systemctl status $SERVICE_NAME${NC}  - Check status"
echo -e "   ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC} - Restart service"
echo -e "   ${YELLOW}sudo systemctl stop $SERVICE_NAME${NC}    - Stop service"
echo -e "   ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}  - View logs (live)"
echo -e "   ${YELLOW}sudo journalctl -u $SERVICE_NAME -n 100${NC} - View last 100 log lines"
echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo -e "   1. Configure your domain DNS to point to this server"
echo -e "   2. Set up Nginx reverse proxy for HTTPS (optional)"
echo -e "   3. Configure backup for SQLite database"
echo -e "   4. Update SECRET_KEY in .env file for security"
echo ""
echo -e "${GREEN}🎉 Your application is now live!${NC}"
echo ""
