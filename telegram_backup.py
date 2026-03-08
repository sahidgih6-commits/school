#!/usr/bin/env python3
"""
Automated Database Backup to Telegram
Backs up SQLite database and sends to Telegram channel/chat
Runs daily at 2 AM via cron job
"""

import os
import shutil
import sqlite3
from datetime import datetime
from pathlib import Path
import requests
import gzip

# ==============================================================================
# CONFIGURATION - Update these values
# ==============================================================================

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN', 'YOUR_BOT_TOKEN_HERE')
TELEGRAM_CHAT_ID = os.environ.get('TELEGRAM_CHAT_ID', 'YOUR_CHAT_ID_HERE')

# Database Configuration
DB_PATH = os.environ.get('DATABASE_PATH', '/var/www/school/smartgardenhub.db')
BACKUP_DIR = os.environ.get('BACKUP_DIR', '/var/www/school/backups')

# Backup Settings
KEEP_BACKUPS_DAYS = 7  # Keep local backups for 7 days
COMPRESS_BACKUP = True  # Compress backup files with gzip

# ==============================================================================
# BACKUP FUNCTIONS
# ==============================================================================

def ensure_backup_directory():
    """Create backup directory if it doesn't exist"""
    backup_dir = Path(BACKUP_DIR)
    backup_dir.mkdir(parents=True, exist_ok=True)
    return backup_dir

def create_backup():
    """Create a backup of the SQLite database"""
    try:
        # Ensure backup directory exists
        backup_dir = ensure_backup_directory()
        
        # Generate backup filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_filename = f'backup_{timestamp}.db'
        backup_path = backup_dir / backup_filename
        
        print(f"📦 Creating backup: {backup_filename}")
        
        # Check if database exists
        if not os.path.exists(DB_PATH):
            print(f"❌ Database not found at: {DB_PATH}")
            return None
        
        # Create backup using SQLite backup API (safer than file copy)
        source_conn = sqlite3.connect(DB_PATH)
        backup_conn = sqlite3.connect(str(backup_path))
        
        with backup_conn:
            source_conn.backup(backup_conn)
        
        source_conn.close()
        backup_conn.close()
        
        print(f"✅ Backup created: {backup_path}")
        
        # Compress if enabled
        if COMPRESS_BACKUP:
            compressed_path = compress_backup(backup_path)
            return compressed_path
        
        return backup_path
        
    except Exception as e:
        print(f"❌ Backup creation failed: {str(e)}")
        return None

def compress_backup(backup_path):
    """Compress backup file with gzip"""
    try:
        compressed_path = Path(str(backup_path) + '.gz')
        
        print(f"🗜️  Compressing backup...")
        
        with open(backup_path, 'rb') as f_in:
            with gzip.open(compressed_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        
        # Remove uncompressed file
        os.remove(backup_path)
        
        # Get file sizes
        original_size = os.path.getsize(backup_path) if os.path.exists(backup_path) else 0
        compressed_size = os.path.getsize(compressed_path)
        
        print(f"✅ Compressed: {compressed_size / (1024*1024):.2f} MB")
        
        return compressed_path
        
    except Exception as e:
        print(f"⚠️  Compression failed: {str(e)}")
        return backup_path

def get_database_stats():
    """Get database statistics"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Get table counts
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        stats = {}
        for (table_name,) in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            stats[table_name] = count
        
        conn.close()
        return stats
        
    except Exception as e:
        print(f"⚠️  Could not get database stats: {str(e)}")
        return {}

def cleanup_old_backups():
    """Remove backups older than KEEP_BACKUPS_DAYS"""
    try:
        backup_dir = Path(BACKUP_DIR)
        if not backup_dir.exists():
            return
        
        cutoff_time = datetime.now().timestamp() - (KEEP_BACKUPS_DAYS * 24 * 60 * 60)
        removed_count = 0
        
        for backup_file in backup_dir.glob('backup_*.db*'):
            if backup_file.stat().st_mtime < cutoff_time:
                backup_file.unlink()
                removed_count += 1
                print(f"🗑️  Removed old backup: {backup_file.name}")
        
        if removed_count > 0:
            print(f"✅ Cleaned up {removed_count} old backup(s)")
        
    except Exception as e:
        print(f"⚠️  Cleanup failed: {str(e)}")

# ==============================================================================
# TELEGRAM FUNCTIONS
# ==============================================================================

def send_to_telegram(backup_path):
    """Send backup file to Telegram"""
    try:
        if TELEGRAM_BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE' or TELEGRAM_CHAT_ID == 'YOUR_CHAT_ID_HERE':
            print("⚠️  Telegram not configured. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID")
            return False
        
        # Get file info
        file_size = os.path.getsize(backup_path)
        file_size_mb = file_size / (1024 * 1024)
        
        # Telegram file size limit is 50MB for bots
        if file_size_mb > 50:
            print(f"❌ File too large for Telegram: {file_size_mb:.2f} MB (max 50 MB)")
            return False
        
        # Get database stats
        stats = get_database_stats()
        
        # Create caption
        caption = f"""
🔄 **Database Backup**
📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
💾 Size: {file_size_mb:.2f} MB
📊 Database: smartgardenhub.db

**Records:**
"""
        
        for table, count in stats.items():
            caption += f"\n• {table}: {count:,}"
        
        caption += f"\n\n✅ Backup completed successfully"
        
        print(f"📤 Sending to Telegram ({file_size_mb:.2f} MB)...")
        
        # Send document to Telegram
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendDocument"
        
        with open(backup_path, 'rb') as file:
            files = {'document': file}
            data = {
                'chat_id': TELEGRAM_CHAT_ID,
                'caption': caption,
                'parse_mode': 'Markdown'
            }
            
            response = requests.post(url, files=files, data=data, timeout=300)
        
        if response.status_code == 200:
            print("✅ Backup sent to Telegram successfully!")
            return True
        else:
            print(f"❌ Telegram send failed: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Telegram send error: {str(e)}")
        return False

def send_telegram_message(message):
    """Send a text message to Telegram"""
    try:
        if TELEGRAM_BOT_TOKEN == 'YOUR_BOT_TOKEN_HERE' or TELEGRAM_CHAT_ID == 'YOUR_CHAT_ID_HERE':
            return False
        
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        data = {
            'chat_id': TELEGRAM_CHAT_ID,
            'text': message,
            'parse_mode': 'Markdown'
        }
        
        response = requests.post(url, data=data, timeout=30)
        return response.status_code == 200
        
    except Exception as e:
        print(f"⚠️  Could not send message: {str(e)}")
        return False

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

def main():
    """Main backup execution"""
    print("=" * 70)
    print("🔄 AUTOMATED DATABASE BACKUP TO TELEGRAM")
    print("=" * 70)
    print(f"⏰ Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📁 Database: {DB_PATH}")
    print(f"💾 Backup directory: {BACKUP_DIR}")
    print()
    
    try:
        # Create backup
        backup_path = create_backup()
        
        if backup_path:
            # Send to Telegram
            success = send_to_telegram(backup_path)
            
            if success:
                print("\n✅ Backup completed and sent to Telegram successfully!")
            else:
                print("\n⚠️  Backup created but Telegram send failed")
                send_telegram_message(f"⚠️ Backup created but send failed at {datetime.now().strftime('%Y-%m-%d %H:%M')}")
            
            # Cleanup old backups
            cleanup_old_backups()
        else:
            print("\n❌ Backup creation failed")
            send_telegram_message(f"❌ Database backup FAILED at {datetime.now().strftime('%Y-%m-%d %H:%M')}")
        
    except Exception as e:
        error_msg = f"❌ Backup process error: {str(e)}"
        print(f"\n{error_msg}")
        send_telegram_message(error_msg)
    
    print()
    print(f"⏰ Finished at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

if __name__ == '__main__':
    main()
