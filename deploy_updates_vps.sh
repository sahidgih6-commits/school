#!/bin/bash
#
# Deployment Guide for VPS Updates
# Run this step by step or as a complete script
#

echo "=========================================="
echo "DEPLOYMENT: Pull Latest Updates from GitHub"
echo "=========================================="

# Step 1: Navigate to project directory
cd /var/www/school

# Step 2: Backup current database (safety first!)
echo "📦 Creating backup before update..."
mkdir -p db_backups
cp smartgardenhub.db db_backups/smartgardenhub_backup_before_update_$(date +%Y%m%d_%H%M%S).db
echo "✅ Backup created"

# Step 3: Stash any local changes (if any)
echo "📝 Checking for local changes..."
git stash
echo "✅ Local changes stashed"

# Step 4: Pull latest code from GitHub
echo "⬇️  Pulling latest code from GitHub..."
git pull origin main
echo "✅ Code updated"

# Step 5: Activate virtual environment
echo "🐍 Activating virtual environment..."
source venv/bin/activate

# Step 6: Install new dependencies (requests for Telegram backup)
echo "📦 Installing dependencies..."
pip install requests
echo "✅ Dependencies installed"

# Step 7: Run database migrations
echo "🔄 Running database migrations..."

# Migration 1: Remove JF/TF columns (if not already done)
if [ -f "migrate_remove_jf_tf.py" ]; then
    echo "Running JF/TF removal migration..."
    python3 migrate_remove_jf_tf.py
fi

# Migration 2: Update holiday to leave
if [ -f "migrate_holiday_to_leave.py" ]; then
    echo "Running holiday->leave migration..."
    python3 migrate_holiday_to_leave.py
fi

echo "✅ Migrations completed"

# Step 8: Set permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /var/www/school
chmod -R 755 /var/www/school
chmod +x telegram_backup.py
chmod +x telegram_backup_cron.sh
echo "✅ Permissions set"

# Step 9: Restart application
echo "🔄 Restarting application..."
systemctl restart school

# Wait a moment
sleep 3

# Step 10: Check status
echo "📊 Checking application status..."
systemctl status school --no-pager

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETED!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Test the application in browser"
echo "2. Setup Telegram backup (see below)"
echo ""
