#!/usr/bin/env python3
"""
Check attendance days count on VPS for debugging
"""
from app import create_app
from models import db, MonthlyExam, Attendance
from datetime import datetime, timedelta

app = create_app('production')

with app.app_context():
    print("=" * 70)
    print("ATTENDANCE DAYS COUNT VERIFICATION")
    print("=" * 70)
    print()
    
    # Get February 2026 exams
    feb_exams = MonthlyExam.query.filter_by(month=2, year=2026).all()
    
    if not feb_exams:
        print("❌ No monthly exams found for February 2026")
        print()
        print("Checking all exams...")
        all_exams = MonthlyExam.query.order_by(MonthlyExam.year.desc(), MonthlyExam.month.desc()).limit(5).all()
        for ex in all_exams:
            print(f"  - {ex.title} ({ex.month}/{ex.year})")
    else:
        for exam in feb_exams:
            print(f"📋 Exam: {exam.title}")
            print(f"   Batch: {exam.batch.name if exam.batch else 'N/A'}")
            print(f"   Month/Year: {exam.month}/{exam.year}")
            print()
            
            # Calculate month boundaries
            month_start = datetime(exam.year, exam.month, 1).date()
            if exam.month == 12:
                month_end = datetime(exam.year + 1, 1, 1).date() - timedelta(days=1)
            else:
                month_end = datetime(exam.year, exam.month + 1, 1).date() - timedelta(days=1)
            
            print(f"   Month Range: {month_start} to {month_end}")
            print()
            
            # Count unique attendance days (NEW LOGIC)
            unique_days = db.session.query(Attendance.date).filter(
                Attendance.batch_id == exam.batch_id,
                Attendance.date >= month_start,
                Attendance.date <= month_end
            ).distinct().count()
            
            print(f"   ✅ ACTUAL Attendance Days Recorded: {unique_days}")
            
            # Show the actual dates
            if unique_days > 0:
                dates = db.session.query(Attendance.date).filter(
                    Attendance.batch_id == exam.batch_id,
                    Attendance.date >= month_start,
                    Attendance.date <= month_end
                ).distinct().order_by(Attendance.date).all()
                
                print(f"   📅 Dates where attendance was taken:")
                for date_tuple in dates:
                    date_obj = date_tuple[0]
                    weekday = date_obj.strftime('%A')
                    print(f"      - {date_obj} ({weekday})")
            
            # Old logic for comparison (weekdays only)
            total_weekdays = 0
            current_date = month_start
            while current_date <= month_end:
                if current_date.weekday() < 5:  # Monday to Friday
                    total_weekdays += 1
                current_date += timedelta(days=1)
            
            print()
            print(f"   ❌ OLD Logic (All Mon-Fri): {total_weekdays}")
            print()
            print(f"   💡 If you see '{unique_days}' in the UI, the fix is working!")
            print(f"      If you see '{total_weekdays}', the old code is still running.")
            print()
            print("=" * 70)
            print()
