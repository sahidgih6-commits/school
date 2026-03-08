#!/bin/bash
# Deploy Roll Fix and Timeout Increase

echo "=================================================="
echo "🚀 Deploying Roll Display Fix & Timeout Increase"
echo "=================================================="

cd /var/www/school

# 1. Pull latest changes
echo ""
echo "📥 Pulling latest code..."
git pull origin main

# 2. Restart service to apply new gunicorn timeout
echo ""
echo "🔄 Restarting service with new timeout settings..."
sudo systemctl restart saro

# 3. Check status
echo ""
echo "✅ Checking service status..."
sudo systemctl status saro --no-pager -l | head -20

echo ""
echo "=================================================="
echo "✅ Deployment Complete!"
echo "=================================================="
echo ""
echo "Changes applied:"
echo "  ✓ Fee section now shows phone instead of 'Roll: N/A'"
echo "  ✓ Gunicorn timeout increased from 30s to 300s (5 min)"
echo "  ✓ Marks can now be saved without timeout errors"
echo ""
echo "Test the changes:"
echo "  1. Go to Fees section - should see phone numbers"
echo "  2. Enter marks for students - should save successfully"
echo ""
