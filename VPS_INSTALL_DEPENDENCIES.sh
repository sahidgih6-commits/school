#!/bin/bash

echo "================================"
echo "🔧 Installing Missing Dependencies on VPS"
echo "================================"
echo ""

# Install gunicorn
echo "📦 Installing gunicorn..."
pip3 install gunicorn
echo "✅ Gunicorn installed"
echo ""

# Install all requirements
echo "📦 Installing all requirements from requirements.txt..."
cd /var/www/school
pip3 install -r requirements.txt
echo "✅ All requirements installed"
echo ""

# Verify gunicorn installation
echo "🔍 Verifying gunicorn installation..."
which gunicorn
python3 -m gunicorn --version
echo ""

# Restart service
echo "🔄 Restarting service..."
sudo systemctl daemon-reload
sudo systemctl restart saro_vps
echo ""

# Check status
echo "📊 Service status:"
sudo systemctl status saro_vps --no-pager -l
echo ""

echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "If service is running, check:"
echo "curl http://localhost:8001/api/health"
echo ""
echo "View logs:"
echo "sudo journalctl -u saro_vps -f"
echo ""
