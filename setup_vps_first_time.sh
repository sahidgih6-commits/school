#!/bin/bash
#
# First-time VPS setup script
# Sets up the application directory and clones from GitHub
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   First-Time VPS Setup${NC}"
echo -e "${BLUE}================================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

APP_DIR="/var/www/school"
REPO_URL="https://github.com/sa5613675-jpg/school.git"

echo ""
echo -e "${GREEN}=== Installing System Dependencies ===${NC}"

apt update
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    nginx \
    sqlite3 \
    curl \
    ufw \
    certbot \
    python3-certbot-nginx

echo -e "${GREEN}✅ System dependencies installed${NC}"

echo ""
echo -e "${GREEN}=== Configuring Firewall ===${NC}"

# Allow SSH, HTTP, HTTPS
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

echo -e "${GREEN}✅ Firewall configured${NC}"

echo ""
echo -e "${GREEN}=== Cloning Repository from GitHub ===${NC}"

# Check if directory already exists
if [ -d "$APP_DIR" ]; then
    echo -e "${YELLOW}⚠️  Directory already exists: $APP_DIR${NC}"
    read -p "Delete and re-clone? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf $APP_DIR
    else
        echo "Skipping clone..."
    fi
fi

if [ ! -d "$APP_DIR" ]; then
    # Create parent directory
    mkdir -p /var/www
    
    # Clone repository
    cd /var/www
    git clone $REPO_URL school
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Repository cloned successfully${NC}"
    else
        echo -e "${RED}❌ Failed to clone repository${NC}"
        echo "Check:"
        echo "  1. Repository URL is correct"
        echo "  2. You have access permissions"
        echo "  3. Internet connection is working"
        exit 1
    fi
fi

cd $APP_DIR

echo ""
echo -e "${GREEN}=== Repository Information ===${NC}"
git remote -v
echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Last commit: $(git log -1 --oneline)"

echo ""
echo -e "${GREEN}=== Making Scripts Executable ===${NC}"
chmod +x *.sh
chmod +x *.py
echo -e "${GREEN}✅ Scripts made executable${NC}"

echo ""
echo -e "${GREEN}=== Setting Ownership ===${NC}"
chown -R www-data:www-data $APP_DIR
echo -e "${GREEN}✅ Ownership set to www-data${NC}"

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ First-time setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: sudo ./deploy_sqlite_production.sh"
echo "  2. Configure domain in: /etc/nginx/sites-available/school"
echo "  3. Setup SSL: sudo certbot --nginx -d your_domain.com"
echo ""
echo "Useful commands:"
echo "  - Check status: sudo systemctl status saro.service"
echo "  - View logs: sudo journalctl -u saro.service -f"
echo "  - Update code: sudo ./quick_deploy.sh"
echo -e "${BLUE}================================================${NC}"
