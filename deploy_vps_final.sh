#!/bin/bash

#############################################
# VPS Deployment Script - Final Version
# Port: 8001 | Host: 0.0.0.0
#############################################

set -e  # Exit on error

echo "=========================================="
echo "🚀 VPS Deployment - SmartGardenHub"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}⚠️  Running as root. Consider using a regular user.${NC}"
fi

# Update system
echo -e "\n${GREEN}📦 Updating system packages...${NC}"
sudo apt-get update -y

# Install Python 3 and pip if not installed
echo -e "\n${GREEN}🐍 Checking Python installation...${NC}"
if ! command -v python3 &> /dev/null; then
    echo "Installing Python 3..."
    sudo apt-get install -y python3 python3-pip python3-venv
else
    echo "✅ Python 3 is already installed: $(python3 --version)"
fi

# Install git if not installed
echo -e "\n${GREEN}📥 Checking Git installation...${NC}"
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    sudo apt-get install -y git
else
    echo "✅ Git is already installed: $(git --version)"
fi

# Navigate to app directory (or clone if needed)
APP_DIR="/home/$(whoami)/school"
if [ ! -d "$APP_DIR" ]; then
    echo -e "\n${YELLOW}📂 App directory not found. Please provide GitHub repository URL:${NC}"
    read -p "GitHub repo URL: " REPO_URL
    git clone "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
echo -e "\n${GREEN}📂 Working directory: $(pwd)${NC}"

# Pull latest changes
echo -e "\n${GREEN}🔄 Pulling latest changes from GitHub...${NC}"
git pull origin main || git pull origin master

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo -e "\n${GREEN}🔨 Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
echo -e "\n${GREEN}⚡ Activating virtual environment...${NC}"
source venv/bin/activate

# Upgrade pip
echo -e "\n${GREEN}📦 Upgrading pip...${NC}"
pip install --upgrade pip

# Install dependencies
echo -e "\n${GREEN}📚 Installing Python dependencies...${NC}"
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo -e "${YELLOW}⚠️  requirements.txt not found. Installing essential packages...${NC}"
    pip install flask flask-cors flask-bcrypt flask-session flask-sqlalchemy gunicorn
fi

# Create necessary directories
echo -e "\n${GREEN}📁 Creating necessary directories...${NC}"
mkdir -p logs
mkdir -p uploads
mkdir -p static
mkdir -p templates

# Set environment variables
echo -e "\n${GREEN}🔧 Setting environment variables...${NC}"
export FLASK_ENV=production
export PORT=8001
export DEBUG=False

# Stop any existing instance
echo -e "\n${GREEN}🛑 Stopping existing instances...${NC}"
pkill -f "python.*app.py" || true
pkill -f "gunicorn.*app:app" || true
sleep 2

# Check database
echo -e "\n${GREEN}🗄️  Checking database...${NC}"
python3 check_database_vps.py

# Create systemd service file
echo -e "\n${GREEN}📝 Creating systemd service...${NC}"
sudo tee /etc/systemd/system/smartgardenhub.service > /dev/null <<EOF
[Unit]
Description=SmartGardenHub Flask Application
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="FLASK_ENV=production"
Environment="PORT=8001"
Environment="DEBUG=False"
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:8001 --workers 4 --timeout 120 --access-logfile logs/access.log --error-logfile logs/error.log app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo -e "\n${GREEN}🔄 Reloading systemd...${NC}"
sudo systemctl daemon-reload

# Enable and start service
echo -e "\n${GREEN}🚀 Starting SmartGardenHub service...${NC}"
sudo systemctl enable smartgardenhub
sudo systemctl restart smartgardenhub

# Wait for service to start
echo -e "\n${GREEN}⏳ Waiting for service to start...${NC}"
sleep 5

# Check service status
echo -e "\n${GREEN}📊 Service Status:${NC}"
sudo systemctl status smartgardenhub --no-pager || true

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Configure firewall (if UFW is installed)
if command -v ufw &> /dev/null; then
    echo -e "\n${GREEN}🔥 Configuring firewall...${NC}"
    sudo ufw allow 8001/tcp || true
    echo "✅ Port 8001 allowed in firewall"
fi

echo -e "\n=========================================="
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "=========================================="
echo ""
echo -e "📡 Server is running on:"
echo -e "   ${GREEN}http://${SERVER_IP}:8001${NC}"
echo ""
echo -e "🔍 Database Check URLs:"
echo -e "   ${GREEN}http://${SERVER_IP}:8001/api/database/check${NC}"
echo -e "   ${GREEN}http://${SERVER_IP}:8001/api/database/stats${NC}"
echo -e "   ${GREEN}http://${SERVER_IP}:8001/health${NC}"
echo ""
echo -e "📋 Useful Commands:"
echo -e "   ${YELLOW}sudo systemctl status smartgardenhub${NC}  - Check status"
echo -e "   ${YELLOW}sudo systemctl restart smartgardenhub${NC} - Restart service"
echo -e "   ${YELLOW}sudo systemctl stop smartgardenhub${NC}    - Stop service"
echo -e "   ${YELLOW}sudo journalctl -u smartgardenhub -f${NC}  - View logs"
echo -e "   ${YELLOW}tail -f logs/error.log${NC}                - View error logs"
echo ""
echo -e "🎯 Next Steps:"
echo -e "   1. Visit http://${SERVER_IP}:8001 in your browser"
echo -e "   2. Check database: http://${SERVER_IP}:8001/api/database/check"
echo -e "   3. Login with your credentials"
echo ""
echo "=========================================="
