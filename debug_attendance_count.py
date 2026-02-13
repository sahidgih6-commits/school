from app import create_app, db
from models import Batch, MonthlyExam, Attendance

app = create_app('development')

with app.app_context():
    print("Searching for Feb 2026 Exams...")
    exams = MonthlyExam.query.filter_by(month=2, year=2026).all()
    for ex in exams:
        print(f"Exam: {ex.title} (ID: {ex.id}) - Batch: {ex.batch.name} (ID: {ex.batch_id})")
        
        # Count attendance days
        unique_days = db.session.query(Attendance.date).filter(
            Attendance.batch_id == ex.batch_id,
            Attendance.date >= '2026-02-01',
            Attendance.date <= '2026-02-28'
        ).distinct().count()
        
        print(f"  -> Unique Attendance Days in DB: {unique_days}")
        
        # Check weekdays count (old logic)
        total_weekdays = 0
        import datetime
        d = datetime.date(2026, 2, 1)
        while d.month == 2:
            if d.weekday() < 5:
                total_weekdays += 1
            d += datetime.timedelta(days=1)
        print(f"  -> Weekdays in Feb 2026 (Old Logic): {total_weekdays}")
