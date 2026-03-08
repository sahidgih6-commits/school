#!/bin/bash
# Quick database copy from madrasha to school

echo "🔄 Quick Database Copy"
echo "====================="

SOURCE_DB="/var/www/madrasha/instance/saro.db"
DEST_DB="/var/www/school/instance/smartgardenhub.db"
BACKUP_DIR="/var/www/school/backups"

# Create backups and instance directory
mkdir -p "$BACKUP_DIR"
mkdir -p "/var/www/school/instance"

# Backup current database if exists
if [ -f "$DEST_DB" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp "$DEST_DB" "$BACKUP_DIR/saro_backup_$TIMESTAMP.db"
    echo "✅ Current database backed up"
fi

# Check if source exists
if [ -f "$SOURCE_DB" ]; then
    echo "📋 Found source database: $SOURCE_DB"
    
    # Stop service
    echo "⏸️  Stopping service..."
    sudo systemctl stop saro
    
    # Copy database
    echo "📦 Copying database..."
    cp "$SOURCE_DB" "$DEST_DB"
    
    # Set permissions
    chown root:root "$DEST_DB"
    chmod 644 "$DEST_DB"
    
    echo "✅ Database copied successfully"
    
    # Initialize SMS balance
    echo "🔧 Setting up SMS balance..."
    cd /var/www/school
    source venv/bin/activate
    echo "y" | python3 init_sms_balance.py
    
    # Start service
    echo "▶️  Starting service..."
    sudo systemctl start saro
    sleep 3
    
    # Check status
    sudo systemctl status saro --no-pager -l | head -20
    
    echo ""
    echo "====================="
    echo "✅ Database restored!"
    echo "🌐 Check: https://gsteaching.com"
    echo ""
    echo "Your data should now be visible:"
    echo "- Students"
    echo "- Batches"
    echo "- Attendance records"
    echo "- Exam results"
    echo "- Fee records"
else
    echo "❌ Source database not found: $SOURCE_DB"
    echo ""
    echo "📝 Available databases:"
    find /var/www -name "saro.db" -o -name "*.db" 2>/dev/null
    echo ""
    echo "To copy manually:"
    echo "sudo cp /path/to/old/saro.db $DEST_DB"
    echo "bash update_database_name.sh"
    echo "sudo systemctl restart saro"
fi
