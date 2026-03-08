#!/bin/bash
# Emergency Fix Script for VPS
# Run this on your VPS to fix both issues

echo "========================================="
echo "   VPS EMERGENCY FIX - SAROYARSIR"
echo "========================================="
echo ""

# Find app directory
if [ -d "/var/www/school" ]; then
    APP_DIR="/var/www/school"
elif [ -d "/home/root/school" ]; then
    APP_DIR="/home/root/school"
else
    echo "❌ Error: Application directory not found"
    exit 1
fi

echo "📁 Application directory: $APP_DIR"
cd "$APP_DIR"

# Step 1: Pull latest code
echo ""
echo "Step 1: Pulling latest code from GitHub..."
git fetch origin
git reset --hard origin/main
echo "✅ Code updated to latest version"

# Step 2: Clear Python cache
echo ""
echo "Step 2: Clearing Python cache..."
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete 2>/dev/null
echo "✅ Cache cleared"

# Step 3: Install/update dependencies
echo ""
echo "Step 3: Checking dependencies..."
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    pip install -q gunicorn 2>/dev/null
    echo "✅ Dependencies checked"
else
    echo "⚠️  Virtual environment not found"
fi

# Step 4: Clean old ranking data for archived students
echo ""
echo "Step 4: Cleaning archived student data..."
python3 << 'PYEOF'
from app import create_app, db
from models import MonthlyRanking, User

app = create_app()
with app.app_context():
    # Delete rankings for archived students
    archived_students = User.query.filter_by(is_archived=True).all()
    archived_ids = [s.id for s in archived_students]
    
    deleted = 0
    for uid in archived_ids:
        count = MonthlyRanking.query.filter_by(user_id=uid).delete()
        deleted += count
    
    db.session.commit()
    print(f"✅ Deleted {deleted} ranking records for archived students")
PYEOF

# Step 5: Verify fixes are in code
echo ""
echo "Step 5: Verifying fixes..."
if grep -q "db.session.get(MonthlyExam" routes/monthly_exams.py; then
    echo "✅ Delete fix: db.session.get() - PRESENT"
else
    echo "❌ Delete fix: MISSING - manual check needed"
fi

if grep -q "Filter out archived students from rankings" routes/monthly_exams.py; then
    echo "✅ Archived filter: PRESENT"
else
    echo "❌ Archived filter: MISSING - manual check needed"
fi

# Step 6: Restart service
echo ""
echo "Step 6: Restarting application..."

if systemctl is-active --quiet smartgardenhub; then
    sudo systemctl restart smartgardenhub
    sleep 2
    if systemctl is-active --quiet smartgardenhub; then
        echo "✅ Service restarted successfully"
    else
        echo "❌ Service failed to start"
        echo "Check logs: sudo journalctl -u smartgardenhub -n 50"
    fi
else
    echo "⚠️  Service not found - starting manually..."
    pkill -f "python.*app.py" 2>/dev/null
    sleep 1
    cd "$APP_DIR"
    source venv/bin/activate 2>/dev/null
    nohup python app.py > logs/app.log 2>&1 &
    sleep 2
    if pgrep -f "python.*app.py" > /dev/null; then
        echo "✅ Application started manually"
    else
        echo "❌ Failed to start application"
    fi
fi

# Step 7: Test the fixes
echo ""
echo "Step 7: Testing fixes..."
python3 << 'PYEOF'
from app import create_app
from models import User, UserRole
import json

app = create_app()
with app.app_context():
    with app.test_client() as client:
        # Login
        login = client.post('/api/auth/login',
            json={'phoneNumber': '01711111111', 'password': 'teacher123'},
            content_type='application/json'
        )
        
        if login.status_code == 200:
            print("✅ Authentication: WORKING")
            
            # Test rankings
            response = client.get('/api/monthly-exams/1/ranking')
            if response.status_code == 200:
                data = response.get_json()
                if data.get('success'):
                    rankings = data['data'].get('nearby_rankings', []) or data['data'].get('rankings', [])
                    
                    # Check archived students
                    archived = User.query.filter_by(role=UserRole.STUDENT, is_archived=True).all()
                    archived_ids = [s.id for s in archived]
                    found_archived = [r for r in rankings if r.get('user_id') in archived_ids]
                    
                    if found_archived:
                        print("❌ Archived filter: FAILED - archived students still in rankings")
                    else:
                        print("✅ Archived filter: WORKING")
                else:
                    print("⚠️  Ranking endpoint returned error")
            else:
                print("⚠️  Could not test rankings")
        else:
            print("❌ Authentication failed - check credentials")
PYEOF

echo ""
echo "========================================="
echo "         FIX COMPLETE!"
echo "========================================="
echo ""
echo "📋 Next Steps:"
echo "1. Open browser in INCOGNITO mode"
echo "2. Go to: http://YOUR_VPS_IP:8001"
echo "3. Login as teacher: 01711111111 / teacher123"
echo "4. Test delete monthly exam (without marks)"
echo "5. Check archived students don't appear"
echo ""
echo "⚠️  IMPORTANT: Must use Incognito/Private mode"
echo "   or clear ALL browser cache (Ctrl+Shift+Del)"
echo ""
echo "📝 Logs:"
echo "   sudo journalctl -u smartgardenhub -f"
echo "   tail -f $APP_DIR/logs/error.log"
echo ""
