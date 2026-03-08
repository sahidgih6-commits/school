#!/bin/bash

echo "================================"
echo "🚀 COMPLETE VPS UPDATE - All Fixes"
echo "================================"
echo ""
echo "This will:"
echo "1. Pull latest code with fee and SMS fixes"
echo "2. Restart service"
echo "3. Verify deployment"
echo ""

echo "Run these commands on your VPS:"
echo ""
echo "================================================"
echo ""

cat << 'VPSCMD'
# Stop service
sudo systemctl stop saro.service

# Go to project and activate venv
cd /var/www/school
source venv/bin/activate

# Pull ALL latest fixes
git pull origin main

# Deactivate venv
deactivate

# Restart service
sudo systemctl restart saro.service

# Check status
sudo systemctl status saro.service

# View logs for any errors
sudo journalctl -u saro.service -n 50 --no-pager

VPSCMD

echo ""
echo "================================================"
echo ""
echo "✅ What This Update Includes:"
echo "================================================"
echo ""
echo "1. FEE SYSTEM FIX:"
echo "   - Fixed 'other_fee' → 'others_fee' column mapping"
echo "   - Now saves exam_fee and other_fee correctly"
echo "   - No more 'Saved 0 fee(s), 1 failed' error"
echo ""
echo "2. SMS TEMPLATE FIX:"
echo "   - Templates save to DATABASE (permanent)"
echo "   - ALL teachers share the same templates"
echo "   - Changes persist across sessions"
echo "   - Database priority over session"
echo ""
echo "3. FILES UPDATED:"
echo "   - routes/fees.py (5 functions)"
echo "   - utils/response.py (serialize_fee)"
echo "   - routes/monthly_exams.py (get_sms_template priority)"
echo "   - routes/sms_templates.py (database-only storage)"
echo ""
echo "================================================"
echo "🧪 After Update, Test:"
echo "================================================"
echo ""
echo "Test 1 - Fee System:"
echo "  1. Go to Fee Management"
echo "  2. Add fee with exam_fee=100, other_fee=50"
echo "  3. Should save WITHOUT errors"
echo "  4. Check total includes both fees"
echo ""
echo "Test 2 - SMS Templates:"
echo "  1. Go to SMS Template Manager"
echo "  2. Edit a custom template"
echo "  3. Save it"
echo "  4. Logout and login (or login as different teacher)"
echo "  5. Should see the SAME template (from database)"
echo ""
echo "================================================"
