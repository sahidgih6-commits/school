#!/usr/bin/env python3
"""
Add exam_fee and others_fee columns to users table for student-level fees
These are per-student fees, not per-month fees
"""
import sys
import os
from pathlib import Path
from sqlalchemy import create_engine, text, inspect, Numeric

# Use the same database as the app (SQLite for production)
# Check if running on VPS (production) or local (development)
if os.path.exists('/var/www/school'):
    # VPS Production - use production SQLite path
    DATABASE_URI = 'sqlite:////var/www/school/smartgardenhub.db'
    print("🚀 Running on VPS (Production)")
else:
    # Local Development
    base_dir = Path(__file__).parent
    DATABASE_URI = f"sqlite:///{base_dir}/smartgardenhub.db"
    print("💻 Running on Local (Development)")

def add_student_fee_columns():
    """Add exam_fee and others_fee columns to users table"""
    print("Adding student-level fee columns to users table...")
    print(f"Database URI: {DATABASE_URI}")
    
    # Create engine
    engine = create_engine(DATABASE_URI)
    inspector = inspect(engine)
    
    # Check if columns already exist
    columns = [col['name'] for col in inspector.get_columns('users')]
    print(f"Current users table columns: {columns}")
    
    with engine.begin() as conn:
        # Add exam_fee if not exists
        if 'exam_fee' not in columns:
            print("Adding exam_fee column to users table...")
            conn.execute(text("""
                ALTER TABLE users 
                ADD COLUMN exam_fee NUMERIC(10, 2) DEFAULT 0.00
            """))
            print("✅ Added exam_fee column")
        else:
            print("⚠️  exam_fee column already exists")
        
        # Add others_fee if not exists
        if 'others_fee' not in columns:
            print("Adding others_fee column to users table...")
            conn.execute(text("""
                ALTER TABLE users 
                ADD COLUMN others_fee NUMERIC(10, 2) DEFAULT 0.00
            """))
            print("✅ Added others_fee column")
        else:
            print("⚠️  others_fee column already exists")
    
    # Verify columns were added
    print("\nVerifying columns...")
    inspector = inspect(engine)  # Re-create inspector
    columns_after = [col['name'] for col in inspector.get_columns('users')]
    
    if 'exam_fee' in columns_after and 'others_fee' in columns_after:
        print("✅ Both columns successfully added to users table")
        print(f"   exam_fee and others_fee are now student-level fields")
        return True
    else:
        print("❌ Failed to add columns")
        print(f"   Columns after: {columns_after}")
        return False

if __name__ == '__main__':
    try:
        success = add_student_fee_columns()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
