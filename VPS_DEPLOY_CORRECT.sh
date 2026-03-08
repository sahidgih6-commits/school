#!/bin/bash

echo "========================================"
echo "🔧 CORRECT VPS Deployment Script"
echo "========================================"
echo ""

cat << 'VPSCMD'
# 1. Stop service
echo "🛑 Stopping service..."
sudo systemctl stop saro.service

# 2. Kill ALL gunicorn processes (including stale ones)
echo "🔪 Killing all gunicorn processes..."
sudo pkill -9 -f gunicorn

# 3. Wait a moment for processes to die
sleep 2

# 4. Remove stale PID file
echo "🗑️  Removing PID file..."
sudo rm -f /tmp/smartgarden-hub.pid

# 5. Verify no gunicorn is running
if pgrep -f gunicorn > /dev/null; then
    echo "⚠️  Warning: gunicorn still running, force killing..."
    sudo killall -9 gunicorn 2>/dev/null || true
else
    echo "✅ All gunicorn processes stopped"
fi

# 6. Go to project and update code
echo ""
echo "📦 Updating code..."
cd /var/www/school
source venv/bin/activate

git pull origin main

echo ""
echo "✅ Current commit:"
git log --oneline -1

# 7. Verify fixes
echo ""
echo "🔍 Verifying fixes..."

# Check Fee fix
if grep -q "others_fee=other_fee" routes/fees.py; then
    echo "✅ Fee fix (others_fee mapping) - FOUND"
else
    echo "❌ Fee fix - MISSING"
fi

# Check SMS template fix
if grep -q "methods=\['POST', 'PUT'\]" routes/sms_templates.py; then
    echo "✅ SMS fix (PUT method) - FOUND"
else
    echo "❌ SMS fix - MISSING"
fi

# Check database columns
python3 << 'EOF'
from app import create_app
from models import db

app = create_app('production')
with app.app_context():
    result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
    columns = [row[1] for row in result]
    
    if 'exam_fee' in columns and 'others_fee' in columns:
        print("✅ Database columns (exam_fee, others_fee) - EXIST")
    else:
        print("❌ Database columns - MISSING")
        print(f"   Found columns: {columns}")
EOF

deactivate

# 8. Start service fresh
echo ""
echo "🚀 Starting service..."
sudo systemctl start saro.service

# 9. Wait for service to start
sleep 3

# 10. Check status
echo ""
echo "📊 Service Status:"
sudo systemctl status saro.service --no-pager -l | head -20

echo ""
echo "========================================" 
echo "✅ Deployment Complete!"
echo "========================================" 
echo ""
echo "🌐 App URL: http://194.233.74.48:8001"
echo ""
echo "🧪 Test Now:"
echo "  1. Fee Management - Add exam_fee + other_fee"
echo "  2. SMS Templates - Edit and save (should persist)"
echo "  3. Online Exam - Create exam (no 'undefined' error)"
echo ""
echo "📝 View logs: sudo journalctl -u saro.service -f"
echo ""

VPSCMD
