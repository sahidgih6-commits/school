#!/bin/bash

echo "================================"
echo "🔍 SAFE Database Update (No Data Loss)"
echo "================================"
echo ""

cat << 'VPSCMD'
# 1. Stop service
sudo systemctl stop saro.service
sudo pkill -f gunicorn
sudo rm -f /tmp/smartgarden-hub.pid

# 2. Go to project
cd /var/www/school
source venv/bin/activate

# 3. Check database and add columns SAFELY (NO DATA DELETION)
python3 << 'EOF'
from app import create_app
from models import db

app = create_app('production')

with app.app_context():
    print("🔍 Checking database structure...")
    print("")
    
    try:
        # Check current columns
        result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
        columns = [row[1] for row in result]
        
        print("📊 Current columns in 'fees' table:")
        for i, col in enumerate(columns, 1):
            print(f"  {i}. {col}")
        print("")
        
        # Check if columns need to be added
        needs_update = False
        
        if 'exam_fee' not in columns:
            print("⚠️  Column 'exam_fee' is MISSING")
            needs_update = True
        else:
            print("✅ Column 'exam_fee' EXISTS")
            
        if 'others_fee' not in columns:
            print("⚠️  Column 'others_fee' is MISSING")
            needs_update = True
        else:
            print("✅ Column 'others_fee' EXISTS")
        
        print("")
        
        if needs_update:
            print("🔧 SAFE UPDATE ACTIONS:")
            print("  - Will ADD missing columns")
            print("  - Will NOT delete any data")
            print("  - Will NOT drop any tables")
            print("  - All existing records will remain intact")
            print("")
            
            # Count existing records before update
            count_result = db.session.execute(db.text("SELECT COUNT(*) FROM fees")).fetchone()
            record_count = count_result[0] if count_result else 0
            print(f"📝 Current fee records: {record_count}")
            print("")
            
            # Add missing columns
            if 'exam_fee' not in columns:
                print("➕ Adding 'exam_fee' column...")
                db.session.execute(db.text(
                    "ALTER TABLE fees ADD COLUMN exam_fee DECIMAL(10, 2) DEFAULT 0.00"
                ))
                db.session.commit()
                print("✅ Column 'exam_fee' added (default value: 0.00)")
            
            if 'others_fee' not in columns:
                print("➕ Adding 'others_fee' column...")
                db.session.execute(db.text(
                    "ALTER TABLE fees ADD COLUMN others_fee DECIMAL(10, 2) DEFAULT 0.00"
                ))
                db.session.commit()
                print("✅ Column 'others_fee' added (default value: 0.00)")
            
            # Verify records are still there
            count_after = db.session.execute(db.text("SELECT COUNT(*) FROM fees")).fetchone()
            records_after = count_after[0] if count_after else 0
            print("")
            print(f"✅ Fee records after update: {records_after}")
            
            if record_count == records_after:
                print("✅ ALL DATA PRESERVED - No records lost!")
            else:
                print("⚠️  Warning: Record count changed")
            
        else:
            print("✅ Database is already up to date!")
            print("✅ No changes needed")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        db.session.rollback()
EOF

# 4. Restart service
deactivate
sudo systemctl start saro.service
sudo systemctl status saro.service

VPSCMD

echo ""
echo "================================"
echo "🛡️ SAFETY GUARANTEES:"
echo "================================"
echo "✅ Your database file is NEVER deleted"
echo "✅ Existing tables are NEVER dropped"
echo "✅ All student/fee/exam data is preserved"
echo "✅ Only adds new columns with default values"
echo "✅ Shows before/after record count"
echo ""
echo "================================"
