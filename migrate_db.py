#!/usr/bin/env python3
"""
Database Migration Script for SQLite Production
Safely migrates database schema with backups
"""
import os
import sys
import sqlite3
import shutil
from datetime import datetime

# Add app directory to path
sys.path.insert(0, '/var/www/school')

DB_PATH = '/var/www/school/smartgardenhub.db'
BACKUP_DIR = '/var/www/school/backups/migrations'

def backup_database():
    """Create backup before migration"""
    print("📦 Creating backup before migration...")
    os.makedirs(BACKUP_DIR, exist_ok=True)
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = f"{BACKUP_DIR}/pre_migration_{timestamp}.db"
    
    shutil.copy2(DB_PATH, backup_path)
    print(f"✅ Backup created: {backup_path}")
    return backup_path

def run_migration():
    """Run database migration"""
    print("🔧 Running database migration...")
    
    try:
        from app import app, db
        
        with app.app_context():
            # Create all tables (will skip existing ones)
            db.create_all()
            print("✅ Database schema updated")
            
            # Verify tables
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tables = cursor.fetchall()
            print(f"📊 Total tables: {len(tables)}")
            conn.close()
            
            return True
            
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

def main():
    print("=" * 60)
    print("SQLite Database Migration")
    print("=" * 60)
    
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found: {DB_PATH}")
        return 1
    
    # Backup
    backup_path = backup_database()
    
    # Run migration
    success = run_migration()
    
    if success:
        print("\n✅ Migration completed successfully")
        return 0
    else:
        print(f"\n❌ Migration failed - restore from: {backup_path}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
