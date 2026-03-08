#!/bin/bash
# Quick Reload Script for VPS
# Run this on your VPS to reload the latest code

echo "🔄 Reloading SmartGardenHub Application"
echo "========================================"

cd /var/www/school

# Pull latest code
echo "📥 Pulling latest code from GitHub..."
git pull origin main

# Activate virtual environment
source venv/bin/activate

# Install any new dependencies
echo "📦 Updating dependencies..."
pip install -r requirements.txt --quiet

# Restart the service
echo "🔄 Restarting application..."
sudo systemctl restart saro

# Wait a moment
sleep 3

# Check status
echo ""
echo "📊 Service Status:"
sudo systemctl status saro --no-pager | head -15

echo ""
echo "✅ Reload complete!"
echo ""
echo "📝 If you see issues, check logs with:"
echo "   sudo journalctl -u saro -f"
