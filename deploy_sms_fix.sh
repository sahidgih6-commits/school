#!/bin/bash

echo "🚀 Deploying SMS Balance Fix to VPS..."
echo ""

# Navigate to project directory
cd /var/www/school || exit 1

# Pull latest changes
echo "📥 Pulling latest changes from GitHub..."
git pull origin main

# Restart service
echo "🔄 Restarting application..."
sudo systemctl restart saro

# Check service status
echo "✅ Checking service status..."
sudo systemctl status saro --no-pager -l

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "✅ Fixed Issues:"
echo "  1. SMS balance now checks actual API (994 SMS) instead of database (0)"
echo "  2. All 6 balance check locations updated"
echo "  3. Short Bangla SMS templates (1 SMS each)"
echo "  4. Correct BulkSMSBD API endpoints and format"
echo ""
echo "📊 Test the fix:"
echo "  - Check SMS balance in header (should show 994 SMS)"
echo "  - Try sending SMS (should work now)"
echo "  - Balance should decrease by 1 per SMS sent"
