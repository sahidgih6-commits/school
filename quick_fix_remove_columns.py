#!/usr/bin/env python3
"""
Quick Fix: Drop jf_amount and tf_amount columns from fees table
Run this on VPS to fix the database schema
"""

import sqlite3
import os
from pathlib import Path

# Database path
DB_PATH = os.environ.get('DATABASE_PATH', '/var/www/school/smartgardenhub.db')

# Fallback to local if production doesn't exist
if not os.path.exists(DB_PATH):
    DB_PATH = Path(__file__).parent / 'smartgardenhub.db'

print("=" * 60)
print("QUICK FIX: Remove jf_amount and tf_amount columns")
print("=" * 60)
print(f"\n📁 Database: {DB_PATH}\n")

try:
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    
    # Check current columns
    cursor.execute("PRAGMA table_info(fees)")
    columns = cursor.fetchall()
    column_names = [col[1] for col in columns]
    
    print(f"Current columns: {column_names}\n")
    
    has_jf = 'jf_amount' in column_names
    has_tf = 'tf_amount' in column_names
    
    if not has_jf and not has_tf:
        print("✅ Columns already removed! No action needed.")
        conn.close()
        exit(0)
    
    print(f"Found columns to remove:")
    if has_jf:
        print(f"  - jf_amount")
    if has_tf:
        print(f"  - tf_amount")
    
    print(f"\n🔧 Recreating table without jf_amount and tf_amount...\n")
    
    # Create new table without jf_amount and tf_amount
    cursor.execute("""
        CREATE TABLE fees_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            batch_id INTEGER NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            exam_fee DECIMAL(10, 2) DEFAULT 0.00,
            others_fee DECIMAL(10, 2) DEFAULT 0.00,
            due_date DATE NOT NULL,
            paid_date DATE,
            status VARCHAR(20) DEFAULT 'pending',
            payment_method VARCHAR(50),
            transaction_id VARCHAR(255),
            late_fee DECIMAL(10, 2) DEFAULT 0.00,
            discount DECIMAL(10, 2) DEFAULT 0.00,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (batch_id) REFERENCES batches (id)
        )
    """)
    print("✅ Step 1: New table created")
    
    # Copy data from old table to new table
    cursor.execute("""
        INSERT INTO fees_new (
            id, user_id, batch_id, amount, exam_fee, others_fee,
            due_date, paid_date, status, payment_method, transaction_id,
            late_fee, discount, notes, created_at, updated_at
        )
        SELECT 
            id, user_id, batch_id, amount, exam_fee, others_fee,
            due_date, paid_date, status, payment_method, transaction_id,
            late_fee, discount, notes, created_at, updated_at
        FROM fees
    """)
    
    rows_copied = cursor.rowcount
    print(f"✅ Step 2: Copied {rows_copied} rows")
    
    # Drop old table
    cursor.execute("DROP TABLE fees")
    print("✅ Step 3: Dropped old table")
    
    # Rename new table to fees
    cursor.execute("ALTER TABLE fees_new RENAME TO fees")
    print("✅ Step 4: Renamed new table to 'fees'")
    
    # Commit changes
    conn.commit()
    
    # Verify
    cursor.execute("PRAGMA table_info(fees)")
    new_columns = cursor.fetchall()
    new_column_names = [col[1] for col in new_columns]
    
    print(f"\n✅ SUCCESS!")
    print(f"New columns: {new_column_names}")
    print(f"Rows migrated: {rows_copied}")
    
    conn.close()
    
    print("\n" + "=" * 60)
    print("✅ DATABASE FIXED - Restart your application now!")
    print("=" * 60)
    
except Exception as e:
    print(f"\n❌ Error: {str(e)}")
    conn.rollback()
    conn.close()
    raise
