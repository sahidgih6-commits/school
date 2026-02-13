#!/usr/bin/env python3
"""
Standalone migration to remove UNIQUE constraint from phoneNumber
This script works directly with SQLite without needing Flask dependencies
"""

import sqlite3
import sys
import os
from datetime import datetime

def fix_phone_constraint(db_path):
    """Remove UNIQUE constraint from phoneNumber column"""
    
    print("🔧 Fixing phoneNumber UNIQUE constraint...")
    print("=" * 70)
    print(f"Database: {db_path}")
    print()
    
    if not os.path.exists(db_path):
        print(f"❌ ERROR: Database not found at {db_path}")
        sys.exit(1)
    
    # Connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # 1. Check current schema
        cursor.execute("""
            SELECT sql FROM sqlite_master 
            WHERE type='table' AND name='users'
        """)
        result = cursor.fetchone()
        
        if not result:
            print("❌ ERROR: users table not found in database")
            conn.close()
            sys.exit(1)
        
        current_schema = result[0]
        print("📋 Current users table schema:")
        print("-" * 70)
        print(current_schema)
        print("-" * 70)
        print()
        
        # 2. Check if UNIQUE constraint exists on phoneNumber
        # In SQLite, UNIQUE constraints appear in the table definition
        cursor.execute("PRAGMA table_info(users)")
        columns = cursor.fetchall()
        
        cursor.execute("PRAGMA index_list(users)")
        indexes = cursor.fetchall()
        
        print("📊 Checking for UNIQUE constraint on phoneNumber...")
        has_unique_constraint = False
        
        # Check indexes for unique constraint
        for idx in indexes:
            idx_name = idx[1]
            is_unique = idx[2]
            
            if is_unique:
                cursor.execute(f"PRAGMA index_info({idx_name})")
                idx_cols = cursor.fetchall()
                for col_info in idx_cols:
                    cursor.execute("PRAGMA table_info(users)")
                    all_cols = cursor.fetchall()
                    col_name = all_cols[col_info[1]][1]
                    
                    if col_name == 'phoneNumber':
                        print(f"⚠️  Found UNIQUE index: {idx_name}")
                        has_unique_constraint = True
        
        if not has_unique_constraint:
            print("✅ No UNIQUE constraint found on phoneNumber - already fixed!")
            conn.close()
            return
        
        print()
        print("🔄 Recreating table without UNIQUE constraint...")
        print()
        
        # 3. Begin transaction
        cursor.execute("BEGIN TRANSACTION")
        
        # 4. Create new table without UNIQUE constraint
        # Match production schema exactly
        cursor.execute("""
            CREATE TABLE users_new (
                id INTEGER NOT NULL PRIMARY KEY,
                phoneNumber VARCHAR(20) NOT NULL,
                first_name VARCHAR(100) NOT NULL,
                last_name VARCHAR(100) NOT NULL,
                email VARCHAR(255),
                password_hash VARCHAR(255),
                role VARCHAR(10) NOT NULL,
                profile_image TEXT,
                date_of_birth DATE,
                address TEXT,
                guardian_name VARCHAR(200),
                guardian_phone VARCHAR(20),
                emergency_contact VARCHAR(20),
                sms_count INTEGER,
                is_active BOOLEAN,
                last_login DATETIME,
                created_at DATETIME NOT NULL,
                updated_at DATETIME,
                is_archived BOOLEAN DEFAULT 0 NOT NULL,
                archived_at DATETIME NULL,
                archived_by INTEGER NULL,
                archive_reason TEXT NULL,
                mother_name VARCHAR(200),
                admission_date TEXT,
                exam_fee NUMERIC(10, 2) DEFAULT 0.00,
                others_fee NUMERIC(10, 2) DEFAULT 0.00,
                UNIQUE (email)
            )
        """)
        print("  ✅ Created new table structure")
        
        # 5. Copy all data
        cursor.execute("""
            INSERT INTO users_new 
            SELECT * FROM users
        """)
        row_count = cursor.rowcount
        print(f"  ✅ Copied {row_count} users to new table")
        
        # 6. Drop old table
        cursor.execute("DROP TABLE users")
        print("  ✅ Dropped old table")
        
        # 7. Rename new table
        cursor.execute("ALTER TABLE users_new RENAME TO users")
        print("  ✅ Renamed new table to 'users'")
        
        # 8. Create index on phoneNumber for performance (non-unique)
        cursor.execute("""
            CREATE INDEX ix_users_phoneNumber 
            ON users(phoneNumber)
        """)
        print("  ✅ Created non-unique index on phoneNumber")
        
        # 9. Commit transaction
        conn.commit()
        print()
        print("=" * 70)
        print("✅ SUCCESS! Migration completed successfully")
        print()
        print("📝 Summary:")
        print("  • Removed UNIQUE constraint from phoneNumber column")
        print("  • Multiple students can now share the same phone number")
        print(f"  • Migrated {row_count} user records")
        print()
        print("👨‍👩‍👧‍👦 You can now add siblings with the same guardian phone number!")
        print()
        
    except Exception as e:
        print(f"❌ ERROR during migration: {e}")
        import traceback
        traceback.print_exc()
        conn.rollback()
        conn.close()
        sys.exit(1)
    
    finally:
        conn.close()

if __name__ == '__main__':
    # Default to production database path
    db_path = '/var/www/saroyarsir/smartgardenhub.db'
    
    # Allow override from command line
    if len(sys.argv) > 1:
        db_path = sys.argv[1]
    
    print()
    print("═" * 70)
    print("  phoneNumber UNIQUE Constraint Removal Migration")
    print("═" * 70)
    print()
    
    fix_phone_constraint(db_path)
