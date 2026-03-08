#!/bin/bash

echo "========================================"
echo "🔧 COMPLETE DATABASE FIX - All Missing Columns"
echo "========================================"
echo ""

cat << 'VPSCMD'
cd /var/www/school
source venv/bin/activate

python3 << 'EOF'
from app import create_app
from models import db

app = create_app('production')

with app.app_context():
    print("=" * 70)
    print("COMPLETE DATABASE MIGRATION")
    print("=" * 70)
    print()
    
    try:
        # ===== CHECK IF online_exams TABLE EXISTS =====
        print("1️⃣ Checking if online_exams table exists...")
        tables = db.session.execute(db.text(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='online_exams'"
        )).fetchall()
        
        if not tables:
            print("   ❌ Table 'online_exams' does NOT exist!")
            print("   🔧 Creating online_exams table from scratch...")
            
            # Create the table with ALL columns
            db.session.execute(db.text("""
                CREATE TABLE online_exams (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    class_name VARCHAR(100) NOT NULL,
                    book_name VARCHAR(255) NOT NULL,
                    chapter_name VARCHAR(255) NOT NULL,
                    duration INTEGER NOT NULL,
                    total_questions INTEGER NOT NULL,
                    pass_percentage FLOAT DEFAULT 40.0,
                    allow_retake BOOLEAN DEFAULT 1,
                    is_active BOOLEAN DEFAULT 1,
                    is_published BOOLEAN DEFAULT 0,
                    created_by INTEGER NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (created_by) REFERENCES users(id)
                )
            """))
            db.session.commit()
            print("   ✅ Table 'online_exams' created!")
        else:
            print("   ✅ Table 'online_exams' exists")
            
            # Check and add missing columns
            result = db.session.execute(db.text("PRAGMA table_info(online_exams)")).fetchall()
            existing_cols = [row[1] for row in result]
            
            # Required columns
            required_columns = {
                'description': 'TEXT',
                'duration': 'INTEGER NOT NULL DEFAULT 30',
                'total_questions': 'INTEGER NOT NULL DEFAULT 20',
                'pass_percentage': 'FLOAT DEFAULT 40.0',
                'allow_retake': 'BOOLEAN DEFAULT 1',
                'is_active': 'BOOLEAN DEFAULT 1',
                'is_published': 'BOOLEAN DEFAULT 0'
            }
            
            for col_name, col_type in required_columns.items():
                if col_name not in existing_cols:
                    print(f"   ➕ Adding column '{col_name}'...")
                    db.session.execute(db.text(
                        f"ALTER TABLE online_exams ADD COLUMN {col_name} {col_type}"
                    ))
                    db.session.commit()
                    print(f"   ✅ Column '{col_name}' added!")
        
        # ===== CHECK online_questions TABLE =====
        print()
        print("2️⃣ Checking online_questions table...")
        tables = db.session.execute(db.text(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='online_questions'"
        )).fetchall()
        
        if not tables:
            print("   🔧 Creating online_questions table...")
            db.session.execute(db.text("""
                CREATE TABLE online_questions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    exam_id INTEGER NOT NULL,
                    question_text TEXT NOT NULL,
                    option_a TEXT NOT NULL,
                    option_b TEXT NOT NULL,
                    option_c TEXT NOT NULL,
                    option_d TEXT NOT NULL,
                    correct_answer VARCHAR(1) NOT NULL,
                    explanation TEXT,
                    question_order INTEGER DEFAULT 0,
                    marks INTEGER DEFAULT 1,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (exam_id) REFERENCES online_exams(id) ON DELETE CASCADE
                )
            """))
            db.session.commit()
            print("   ✅ Table 'online_questions' created!")
        else:
            print("   ✅ Table 'online_questions' exists")
        
        # ===== CHECK online_exam_attempts TABLE =====
        print()
        print("3️⃣ Checking online_exam_attempts table...")
        tables = db.session.execute(db.text(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='online_exam_attempts'"
        )).fetchall()
        
        if not tables:
            print("   🔧 Creating online_exam_attempts table...")
            db.session.execute(db.text("""
                CREATE TABLE online_exam_attempts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    exam_id INTEGER NOT NULL,
                    student_id INTEGER NOT NULL,
                    score FLOAT DEFAULT 0,
                    total_marks INTEGER DEFAULT 0,
                    percentage FLOAT DEFAULT 0,
                    passed BOOLEAN DEFAULT 0,
                    started_at DATETIME,
                    submitted_at DATETIME,
                    time_taken INTEGER,
                    FOREIGN KEY (exam_id) REFERENCES online_exams(id) ON DELETE CASCADE,
                    FOREIGN KEY (student_id) REFERENCES users(id)
                )
            """))
            db.session.commit()
            print("   ✅ Table 'online_exam_attempts' created!")
        else:
            print("   ✅ Table 'online_exam_attempts' exists")
        
        # ===== CHECK online_student_answers TABLE =====
        print()
        print("4️⃣ Checking online_student_answers table...")
        tables = db.session.execute(db.text(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='online_student_answers'"
        )).fetchall()
        
        if not tables:
            print("   🔧 Creating online_student_answers table...")
            db.session.execute(db.text("""
                CREATE TABLE online_student_answers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    attempt_id INTEGER NOT NULL,
                    question_id INTEGER NOT NULL,
                    selected_answer VARCHAR(1),
                    is_correct BOOLEAN DEFAULT 0,
                    marks_obtained FLOAT DEFAULT 0,
                    FOREIGN KEY (attempt_id) REFERENCES online_exam_attempts(id) ON DELETE CASCADE,
                    FOREIGN KEY (question_id) REFERENCES online_questions(id) ON DELETE CASCADE
                )
            """))
            db.session.commit()
            print("   ✅ Table 'online_student_answers' created!")
        else:
            print("   ✅ Table 'online_student_answers' exists")
        
        # ===== CHECK FEES TABLE =====
        print()
        print("5️⃣ Checking fees table...")
        result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
        fee_cols = [row[1] for row in result]
        
        if 'exam_fee' not in fee_cols:
            print("   ➕ Adding 'exam_fee' column...")
            db.session.execute(db.text("ALTER TABLE fees ADD COLUMN exam_fee DECIMAL(10, 2) DEFAULT 0.00"))
            db.session.commit()
            print("   ✅ Column 'exam_fee' added!")
        else:
            print("   ✅ Column 'exam_fee' exists")
        
        if 'others_fee' not in fee_cols:
            print("   ➕ Adding 'others_fee' column...")
            db.session.execute(db.text("ALTER TABLE fees ADD COLUMN others_fee DECIMAL(10, 2) DEFAULT 0.00"))
            db.session.commit()
            print("   ✅ Column 'others_fee' added!")
        else:
            print("   ✅ Column 'others_fee' exists")
        
        # ===== FINAL VERIFICATION =====
        print()
        print("=" * 70)
        print("VERIFICATION")
        print("=" * 70)
        
        # Check all tables exist
        tables_to_check = ['online_exams', 'online_questions', 'online_exam_attempts', 'online_student_answers']
        for table in tables_to_check:
            exists = db.session.execute(db.text(
                f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table}'"
            )).fetchall()
            if exists:
                print(f"✅ Table '{table}' - EXISTS")
            else:
                print(f"❌ Table '{table}' - MISSING")
        
        # Check fee columns
        result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
        fee_cols = [row[1] for row in result]
        if 'exam_fee' in fee_cols and 'others_fee' in fee_cols:
            print("✅ Fee columns (exam_fee, others_fee) - EXIST")
        else:
            print("❌ Fee columns - MISSING")
        
        print()
        print("=" * 70)
        print("✅ DATABASE MIGRATION COMPLETE!")
        print("=" * 70)
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        db.session.rollback()
EOF

deactivate

echo ""
echo "Now restart the service:"
echo "sudo systemctl restart saro.service"
echo ""

VPSCMD
