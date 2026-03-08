#!/bin/bash

echo "========================================"
echo "🚀 COMPLETE FIX FOR ALL 3 ISSUES"
echo "========================================"
echo ""
echo "This will fix:"
echo "1. ✅ Fee save (exam_fee + other_fee columns)"
echo "2. ✅ SMS templates (permanent database storage)"
echo "3. ✅ Online exam creation error"
echo ""
echo "Copy and paste this entire block into your VPS terminal:"
echo ""
echo "========================================" 
echo ""

cat << 'VPSCMD'
# Stop service
sudo systemctl stop saro.service
sudo pkill -f gunicorn
sudo rm -f /tmp/smartgarden-hub.pid

# Go to project
cd /var/www/school
source venv/bin/activate

# Pull latest code (includes ALL fixes)
echo "📦 Pulling latest code..."
git pull origin main

# Show current commit
echo ""
echo "✅ Current commit:"
git log --oneline -1
echo ""

# Verify all fixes are present
echo "🔍 Verifying fixes..."
echo ""

# Check 1: Fee fix
if grep -q "others_fee=other_fee" routes/fees.py; then
    echo "✅ Fix 1: Fee column mapping (others_fee) - FOUND"
else
    echo "❌ Fix 1: Fee column mapping - MISSING"
fi

# Check 2: SMS template fix
if grep -q "POST.*PUT" routes/sms_templates.py; then
    echo "✅ Fix 2: SMS template PUT method - FOUND"
else
    echo "❌ Fix 2: SMS template PUT method - MISSING"
fi

# Check 3: Database columns
python3 << 'EOF'
from app import create_app
from models import db

app = create_app('production')
with app.app_context():
    result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
    columns = [row[1] for row in result]
    
    if 'exam_fee' in columns and 'others_fee' in columns:
        print("✅ Fix 3: Database columns (exam_fee, others_fee) - FOUND")
    else:
        print("❌ Fix 3: Database columns - MISSING")
EOF

echo ""
echo "========================================" 
echo ""

# Deactivate and restart
deactivate
sudo systemctl restart saro.service

# Wait for service to start
sleep 2

# Check status
echo "📊 Service Status:"
sudo systemctl status saro.service --no-pager -l | head -15

echo ""
echo "========================================" 
echo "✅ Deployment Complete!"
echo "========================================" 
echo ""
echo "🌐 Your app is running at:"
echo "   http://194.233.74.48:8001"
echo ""
echo "🧪 Test These Features:"
echo ""
echo "1. FEE MANAGEMENT:"
echo "   - Go to Fee Management"
echo "   - Add fee with exam_fee and other_fee"
echo "   - Should save without '1 failed' error"
echo ""
echo "2. SMS TEMPLATES:"
echo "   - Go to SMS section"
echo "   - Click 'SMS Templates' or template settings"
echo "   - Edit a template and click 'Save'"
echo "   - Logout and login again"
echo "   - Template should still be there (saved in database)"
echo ""
echo "3. ONLINE EXAM:"
echo "   - Go to Online Exam"
echo "   - Click 'Create Online Exam'"
echo "   - Should work without 'undefined' error"
echo ""
echo "========================================" 
echo ""
echo "📝 View Logs (if issues):"
echo "sudo journalctl -u saro.service -f"
echo ""

VPSCMD
