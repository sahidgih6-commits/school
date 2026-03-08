"""
Database Migration: Remove JF/TF Columns from Fee Table
For SQLite Production Database
"""
import sqlite3
import os
from pathlib import Path

def migrate_fee_table():
    """Remove jf_amount and tf_amount columns from fees table"""
    
    # Paths for both development and production databases
    dev_db_path = Path(__file__).parent / "smartgardenhub.db"
    prod_db_path = Path("/var/www/school/smartgardenhub.db")
    
    # Determine which database to use
    if prod_db_path.exists():
        db_path = prod_db_path
        print(f"✅ Using PRODUCTION database: {db_path}")
    elif dev_db_path.exists():
        db_path = dev_db_path
        print(f"✅ Using DEVELOPMENT database: {db_path}")
    else:
        print("❌ No database found!")
        return False
    
    # Create backup
    backup_path = str(db_path) + ".backup_before_jf_tf_removal"
    print(f"📦 Creating backup: {backup_path}")
    
    import shutil
    shutil.copy2(db_path, backup_path)
    print("✅ Backup created successfully")
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if jf_amount and tf_amount columns exist
        cursor.execute("PRAGMA table_info(fees)")
        columns = cursor.fetchall()
        column_names = [col[1] for col in columns]
        
        print(f"\n📊 Current columns in fees table: {column_names}")
        
        has_jf = 'jf_amount' in column_names
        has_tf = 'tf_amount' in column_names
        
        if not has_jf and not has_tf:
            print("✅ jf_amount and tf_amount columns don't exist. No migration needed.")
            conn.close()
            return True
        
        print(f"\n🔧 Starting migration...")
        print(f"   - jf_amount exists: {has_jf}")
        print(f"   - tf_amount exists: {has_tf}")
        
        # SQLite doesn't support DROP COLUMN directly
        # We need to create a new table and copy data
        
        print("\n📝 Step 1: Creating new fees table without jf_amount and tf_amount")
        cursor.execute("""
            CREATE TABLE fees_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                batch_id INTEGER NOT NULL,
                amount NUMERIC(10, 2) NOT NULL,
                exam_fee NUMERIC(10, 2) DEFAULT 0.00,
                others_fee NUMERIC(10, 2) DEFAULT 0.00,
                due_date DATE NOT NULL,
                paid_date DATE,
                status TEXT DEFAULT 'pending',
                payment_method VARCHAR(50),
                transaction_id VARCHAR(255),
                late_fee NUMERIC(10, 2) DEFAULT 0.00,
                discount NUMERIC(10, 2) DEFAULT 0.00,
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id),
                FOREIGN KEY (batch_id) REFERENCES batches(id)
            )
        """)
        
        print("✅ New table created")
        
        print("\n📝 Step 2: Copying data from old table to new table")
        cursor.execute("""
            INSERT INTO fees_new 
            (id, user_id, batch_id, amount, exam_fee, others_fee, due_date, paid_date, 
             status, payment_method, transaction_id, late_fee, discount, notes, created_at, updated_at)
            SELECT 
                id, user_id, batch_id, amount, exam_fee, others_fee, due_date, paid_date,
                status, payment_method, transaction_id, late_fee, discount, notes, created_at, updated_at
            FROM fees
        """)
        
        rows_copied = cursor.rowcount
        print(f"✅ Copied {rows_copied} rows")
        
        print("\n📝 Step 3: Dropping old fees table")
        cursor.execute("DROP TABLE fees")
        print("✅ Old table dropped")
        
        print("\n📝 Step 4: Renaming new table to fees")
        cursor.execute("ALTER TABLE fees_new RENAME TO fees")
        print("✅ Table renamed")
        
        # Commit the changes
        conn.commit()
        print("\n✅ Migration completed successfully!")
        print(f"   - Database: {db_path}")
        print(f"   - Rows migrated: {rows_copied}")
        print(f"   - Backup location: {backup_path}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"\n❌ Migration failed: {str(e)}")
        print(f"   - Database has been backed up to: {backup_path}")
        print(f"   - You can restore it if needed")
        if 'conn' in locals():
            conn.rollback()
            conn.close()
        return False


if __name__ == "__main__":
    print("=" * 60)
    print("DATABASE MIGRATION: Remove JF/TF Columns from Fees Table")
    print("=" * 60)
    print()
    
    success = migrate_fee_table()
    
    print()
    print("=" * 60)
    if success:
        print("✅ MIGRATION COMPLETED SUCCESSFULLY")
    else:
        print("❌ MIGRATION FAILED - Check errors above")
    print("=" * 60)
