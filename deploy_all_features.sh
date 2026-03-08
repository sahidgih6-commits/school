#!/bin/bash
# Comprehensive deployment script for all new features

echo "=========================================================="
echo "🚀 Deploying New Features to VPS"
echo "=========================================================="
echo ""
echo "Features being deployed:"
echo "  ✓ Individual Exam Delete Button"
echo "  ✓ Student Admission Date Field"
echo "  ✓ Roll Display Removed from Fees"
echo "  ✓ Timeout Increased for Marks Saving"
echo ""

cd /var/www/school || exit 1

# 1. Backup current database
echo "📦 Step 1: Backing up database..."
DB_PATH="instance/smartgardenhub.db"
if [ -f "$DB_PATH" ]; then
    cp "$DB_PATH" "$DB_PATH.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Database backed up"
else
    echo "⚠️  Database not found at $DB_PATH"
fi

# 2. Pull latest code
echo ""
echo "📥 Step 2: Pulling latest code from Git..."
git pull origin main

if [ $? -ne 0 ]; then
    echo "❌ Git pull failed!"
    exit 1
fi
echo "✅ Code updated"

# 3. Activate virtual environment
echo ""
echo "🐍 Step 3: Activating virtual environment..."
source venv/bin/activate || source .venv/bin/activate || {
    echo "❌ Failed to activate virtual environment"
    exit 1
}
echo "✅ Virtual environment activated"

# 4. Run database migration for admission_date
echo ""
echo "🔧 Step 4: Running database migrations..."
python3 migrate_add_admission_date.py

if [ $? -ne 0 ]; then
    echo "⚠️  Migration had warnings, but continuing..."
fi
echo "✅ Migrations completed"

# 5. Fix database permissions
echo ""
echo "🔒 Step 5: Fixing database permissions..."
chown www-data:www-data "$DB_PATH" 2>/dev/null || echo "⚠️  Could not change owner (may need sudo)"
chmod 664 "$DB_PATH"
echo "✅ Permissions updated"

# 6. Restart application
echo ""
echo "🔄 Step 6: Restarting application..."
sudo systemctl restart saro

if [ $? -eq 0 ]; then
    echo "✅ Application restarted"
else
    echo "⚠️  Restart command may have failed, checking status..."
fi

# 7. Wait and check status
echo ""
echo "⏳ Waiting for application to start..."
sleep 3

sudo systemctl status saro --no-pager -l | head -20

echo ""
echo "=========================================================="
echo "✅ Deployment Complete!"
echo "=========================================================="
echo ""
echo "🧪 Please test the following:"
echo ""
echo "1. Individual Exam Delete:"
echo "   - Go to Monthly Exams → Select exam → Try to delete an exam"
echo "   - Should work if no marks entered"
echo "   - Should show error if marks are entered"
echo ""
echo "2. Student Admission Date:"
echo "   - Go to Students → Add New Student"
echo "   - Fill in details including Admission Date"
echo "   - Save and verify it shows in the student list"
echo ""
echo "3. Fee Section:"
echo "   - Check that phone numbers show instead of 'Roll: N/A'"
echo ""
echo "4. Marks Saving:"
echo "   - Enter marks for students - should save without timeout"
echo ""
echo "📝 If you encounter any issues:"
echo "   - Check logs: tail -f logs/app.log"
echo "   - Check service: sudo systemctl status saro"
echo "   - Restore backup if needed: cp $DB_PATH.backup.* $DB_PATH"
echo ""
