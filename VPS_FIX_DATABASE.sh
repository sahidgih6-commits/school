#!/bin/bash

echo "================================"
echo "🔧 Fix VPS Database & PID Issues"
echo "================================"
echo ""

cat << 'VPSCMD'
# 1. Stop service completely
sudo systemctl stop saro.service

# 2. Kill any stale gunicorn processes
sudo pkill -f gunicorn
sudo rm -f /tmp/smartgarden-hub.pid

# 3. Go to project directory
cd /var/www/school
source venv/bin/activate

# 4. Update database schema (add others_fee column if missing)
python3 << 'EOF'
from app import create_app
from models import db
import sqlite3

app = create_app('production')

with app.app_context():
    # Check if others_fee column exists
    try:
        result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
        columns = [row[1] for row in result]
        
        if 'others_fee' not in columns:
            print("❌ Column 'others_fee' not found. Adding it...")
            db.session.execute(db.text(
                "ALTER TABLE fees ADD COLUMN others_fee DECIMAL(10, 2) DEFAULT 0.00"
            ))
            db.session.commit()
            print("✅ Column 'others_fee' added successfully!")
        else:
            print("✅ Column 'others_fee' already exists.")
        
        # Check exam_fee column
        if 'exam_fee' not in columns:
            print("❌ Column 'exam_fee' not found. Adding it...")
            db.session.execute(db.text(
                "ALTER TABLE fees ADD COLUMN exam_fee DECIMAL(10, 2) DEFAULT 0.00"
            ))
            db.session.commit()
            print("✅ Column 'exam_fee' added successfully!")
        else:
            print("✅ Column 'exam_fee' already exists.")
            
        print("\n📊 Current fee table columns:")
        for col in columns:
            print(f"  - {col}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        db.session.rollback()
EOF

# 5. Deactivate venv
deactivate

# 6. Start service fresh
sudo systemctl start saro.service

# 7. Check status
sudo systemctl status saro.service

# 8. View logs
sudo journalctl -u saro.service -n 30 --no-pager

VPSCMD

echo ""
echo "================================"
echo "✅ This Script Will:"
echo "================================"
echo "1. Stop service and kill stale processes"
echo "2. Remove PID file"
echo "3. Add missing database columns:"
echo "   - exam_fee (if missing)"
echo "   - others_fee (if missing)"
echo "4. Restart service cleanly"
echo ""
echo "================================"
