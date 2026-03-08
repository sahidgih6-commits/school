#!/bin/bash
# SmartGardenHub VPS Deployment Script
# Run this on your VPS at /var/www/school

set -e  # Exit on error

echo "🚀 SmartGardenHub VPS Deployment Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/var/www/school"
VENV_DIR="$PROJECT_DIR/venv"
SERVICE_NAME="saro"

echo -e "${YELLOW}Step 1: Stopping existing services...${NC}"
pkill -f "flask run" || true
pkill -f "python run.py" || true
pkill -f "gunicorn" || true
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true

echo -e "${GREEN}✓ Services stopped${NC}"

echo -e "${YELLOW}Step 2: Navigating to project directory...${NC}"
cd $PROJECT_DIR
echo -e "${GREEN}✓ Current directory: $(pwd)${NC}"

echo -e "${YELLOW}Step 3: Pulling latest code from GitHub...${NC}"
git fetch origin
git pull origin main
echo -e "${GREEN}✓ Code updated${NC}"

echo -e "${YELLOW}Step 4: Activating virtual environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi
source $VENV_DIR/bin/activate
echo -e "${GREEN}✓ Virtual environment activated${NC}"

echo -e "${YELLOW}Step 5: Upgrading pip...${NC}"
pip install --upgrade pip
echo -e "${GREEN}✓ Pip upgraded${NC}"

echo -e "${YELLOW}Step 6: Installing dependencies...${NC}"
pip install -r requirements.txt
pip install gunicorn
echo -e "${GREEN}✓ Dependencies installed${NC}"

echo -e "${YELLOW}Step 7: Setting up environment file...${NC}"
if [ ! -f ".env" ]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo -e "${RED}⚠️  IMPORTANT: Edit .env file with your API keys!${NC}"
    echo "   nano .env"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

echo -e "${YELLOW}Step 8: Setting up database...${NC}"
python create_default_users.py 2>/dev/null || echo "Default users may already exist"
echo -e "${GREEN}✓ Database ready${NC}"

echo -e "${YELLOW}Step 9: Creating systemd service...${NC}"
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=SmartGardenHub Flask Application
After=network.target

[Service]
Type=notify
User=root
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 --timeout 120 --access-logfile - --error-logfile - "app:create_app()"
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}✓ Service file created${NC}"

echo -e "${YELLOW}Step 10: Enabling and starting service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
echo -e "${GREEN}✓ Service started${NC}"

echo ""
echo "========================================"
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "========================================"
echo ""
echo "📊 Service Status:"
sudo systemctl status $SERVICE_NAME --no-pager
echo ""
echo "📝 Useful Commands:"
echo "  View logs:        sudo journalctl -u $SERVICE_NAME -f"
echo "  Restart service:  sudo systemctl restart $SERVICE_NAME"
echo "  Stop service:     sudo systemctl stop $SERVICE_NAME"
echo "  Check status:     sudo systemctl status $SERVICE_NAME"
echo ""
echo "🌐 Application URL: http://your-vps-ip:5000"
echo ""
echo -e "${YELLOW}⚠️  Don't forget to:${NC}"
echo "  1. Edit .env file with your actual API keys"
echo "  2. Configure your firewall to allow port 5000"
echo "  3. Set up Nginx as reverse proxy (recommended)"
echo ""
