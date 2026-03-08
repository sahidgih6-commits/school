#!/bin/bash

echo "🚀 FINAL FIX - Pull All Code and Verify"
echo "========================================"
echo ""
echo "Run this on your VPS:"
echo ""

cat << 'VPSCMD'
# Stop service
sudo systemctl stop saro.service
sudo pkill -f gunicorn

# Go to project and pull EVERYTHING
cd /var/www/school
source venv/bin/activate

# Check current commit
echo "Current commit:"
git log --oneline -1

# Pull ALL latest code
git pull origin main

# Verify the fix is present
echo ""
echo "🔍 Verifying fixes are in the code..."
echo ""

# Check if fee fix is present
if grep -q "others_fee=other_fee" routes/fees.py; then
    echo "✅ Fee fix is present (others_fee mapping)"
else
    echo "❌ Fee fix NOT found!"
fi

# Check if SMS template fix is present
if grep -q "# PRIORITY 1: Database (permanent" routes/monthly_exams.py; then
    echo "✅ SMS template fix is present (database priority)"
else
    echo "❌ SMS template fix NOT found!"
fi

echo ""
echo "Latest commit after pull:"
git log --oneline -1

# Restart service
deactivate
sudo systemctl restart saro.service

# Check status
sudo systemctl status saro.service --no-pager -l

# Show access URL
echo ""
echo "================================"
echo "✅ Service should be running at:"
echo "http://194.233.74.48:8001"
echo "================================"

VPSCMD

echo ""
echo "================================"
echo "Expected Latest Commit: 11b1e9d"
echo "================================"
