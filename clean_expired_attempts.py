#!/usr/bin/env python3
"""
Clean up expired exam attempts
Run this on VPS to fix "Time has expired" errors
"""
import sqlite3
from datetime import datetime

# VPS database path
DB_PATH = '/var/www/school/smartgardenhub.db'

def clean_expired_attempts():
    """Auto-submit all expired attempts"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Check what columns exist
    cursor.execute("PRAGMA table_info(online_exam_attempts)")
    columns = [row[1] for row in cursor.fetchall()]
    print(f"Available columns: {columns}")
    
    # Find expired attempts
    cursor.execute("""
        SELECT a.id, a.exam_id, a.student_id, a.started_at, e.duration
        FROM online_exam_attempts a
        JOIN online_exams e ON a.exam_id = e.id
        WHERE a.is_submitted = 0
    """)
    
    expired = []
    now = datetime.utcnow()
    
    for row in cursor.fetchall():
        attempt_id, exam_id, student_id, started_at, duration = row
        started = datetime.fromisoformat(started_at.replace('Z', '+00:00').replace('+00:00', ''))
        elapsed = (now - started).total_seconds()
        time_limit = duration * 60
        
        if elapsed >= time_limit:
            expired.append(attempt_id)
    
    if expired:
        print(f"Found {len(expired)} expired attempts to auto-submit")
        
        # Auto-submit them - just mark as submitted
        for attempt_id in expired:
            cursor.execute("""
                UPDATE online_exam_attempts 
                SET is_submitted = 1,
                    submitted_at = ?
                WHERE id = ?
            """, (now, attempt_id))
            print(f"  ✅ Auto-submitted attempt {attempt_id}")
        
        conn.commit()
        print(f"\n✅ Cleaned {len(expired)} expired attempts")
    else:
        print("✅ No expired attempts found")
    
    conn.close()

if __name__ == '__main__':
    clean_expired_attempts()
