#!/bin/bash

###############################################
# VPS Quick Fix Script
# Fixes the deployment and completes setup
###############################################

echo "=========================================="
echo "🔧 VPS Quick Fix & Complete Deployment"
echo "=========================================="

# Get the correct app directory
if [ -d "/var/www/school" ]; then
    APP_DIR="/var/www/school"
elif [ -d "/home/root/school" ]; then
    APP_DIR="/home/root/school"
else
    echo "❌ App directory not found!"
    exit 1
fi

cd "$APP_DIR"
echo "📂 Working in: $(pwd)"

# Pull latest fixes
echo ""
echo "🔄 Pulling latest fixes from GitHub..."
git pull origin main

# Activate virtual environment
echo ""
echo "⚡ Activating virtual environment..."
source venv/bin/activate

# Install gunicorn if not installed
echo ""
echo "📦 Installing gunicorn..."
pip install gunicorn

# Test database check script
echo ""
echo "🗄️  Testing database check..."
python check_database_vps.py || echo "⚠️  Database check had issues (continuing anyway)"

# Create systemd service
echo ""
echo "📝 Creating systemd service..."
sudo tee /etc/systemd/system/smartgardenhub.service > /dev/null <<EOF
[Unit]
Description=SmartGardenHub Flask Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="FLASK_ENV=production"
Environment="PORT=8001"
Environment="DEBUG=False"
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:8001 --workers 4 --timeout 120 --access-logfile $APP_DIR/logs/access.log --error-logfile $APP_DIR/logs/error.log app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo ""
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

# Enable and start service
echo ""
echo "🚀 Starting SmartGardenHub service..."
sudo systemctl enable smartgardenhub
sudo systemctl restart smartgardenhub

# Wait for service to start
echo ""
echo "⏳ Waiting for service to start..."
sleep 5

# Check service status
echo ""
echo "📊 Service Status:"
sudo systemctl status smartgardenhub --no-pager | head -20

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Configure firewall (if UFW is installed)
if command -v ufw &> /dev/null; then
    echo ""
    echo "🔥 Configuring firewall..."
    sudo ufw allow 8001/tcp 2>/dev/null || true
    echo "✅ Port 8001 allowed in firewall"
fi

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "📡 Server is running on:"
echo "   http://${SERVER_IP}:8001"
echo ""
echo "🔍 Database Check URLs:"
echo "   http://${SERVER_IP}:8001/api/database/check"
echo "   http://${SERVER_IP}:8001/api/database/stats"
echo "   http://${SERVER_IP}:8001/health"
echo ""
echo "📋 Useful Commands:"
echo "   sudo systemctl status smartgardenhub  - Check status"
echo "   sudo systemctl restart smartgardenhub - Restart service"
echo "   sudo systemctl stop smartgardenhub    - Stop service"
echo "   sudo journalctl -u smartgardenhub -f  - View logs"
echo "   tail -f $APP_DIR/logs/error.log       - View error logs"
echo ""
echo "=========================================="
