#!/usr/bin/env python3
"""
Migration Script: Update Attendance Status from 'holiday' to 'leave'
This script updates all existing attendance records with status 'holiday' to 'leave'
"""

import os
import sqlite3
from pathlib import Path

def migrate_holiday_to_leave():
    """Update all attendance records from holiday to leave status"""
    # Determine database path
    db_path = os.environ.get('DATABASE_PATH', '/var/www/school/smartgardenhub.db')
    
    # Fallback to local if production doesn't exist
    if not os.path.exists(db_path):
        db_path = Path(__file__).parent / 'smartgardenhub.db'
    
    print("=" * 60)
    print("ATTENDANCE STATUS MIGRATION: holiday -> leave")
    print("=" * 60)
    print(f"\n✅ Using database: {db_path}\n")
    
    try:
        # Connect to database
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # Count existing holiday records
        cursor.execute("SELECT COUNT(*) FROM attendance WHERE status = 'holiday'")
        holiday_count = cursor.fetchone()[0]
        
        print(f"Found {holiday_count} attendance records with 'holiday' status")
        
        if holiday_count == 0:
            print("\n✅ No records to migrate. Database is already up to date!")
            conn.close()
            return
        
        # Auto-confirm in production, ask in development
        if os.environ.get('FLASK_ENV') == 'production':
            confirm = 'yes'
            print(f"\n🔄 Auto-confirming in production mode")
        else:
            confirm = input(f"\nUpdate {holiday_count} records from 'holiday' to 'leave'? (yes/no): ")
        
        if confirm.lower() != 'yes':
            print("\n❌ Migration cancelled by user")
            conn.close()
            return
        
        # Update the records
        cursor.execute("UPDATE attendance SET status = 'leave' WHERE status = 'holiday'")
        updated_count = cursor.rowcount
        
        conn.commit()
        
        print(f"\n✅ Successfully updated {updated_count} attendance records!")
        
        # Verify the update
        cursor.execute("SELECT COUNT(*) FROM attendance WHERE status = 'holiday'")
        remaining_holiday = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM attendance WHERE status = 'leave'")
        new_leave_count = cursor.fetchone()[0]
        
        print(f"\nVerification:")
        print(f"  - Remaining 'holiday' records: {remaining_holiday}")
        print(f"  - Total 'leave' records: {new_leave_count}")
        
        if remaining_holiday == 0:
            print("\n✅ Migration completed successfully!")
        else:
            print(f"\n⚠️  Warning: {remaining_holiday} 'holiday' records still exist")
        
        conn.close()
        
    except Exception as e:
        print(f"\n❌ Error during migration: {str(e)}")
        raise

if __name__ == '__main__':
    migrate_holiday_to_leave()
