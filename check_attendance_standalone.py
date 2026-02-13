#!/usr/bin/env python3
"""
Standalone script to check attendance days count (no Flask dependencies)
"""
import sqlite3
from datetime import datetime, timedelta
import sys

# Database path
DB_PATH = '/var/www/saroyarsir/smartgardenhub.db'

def main():
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print("=" * 70)
        print("ATTENDANCE DAYS COUNT VERIFICATION")
        print("=" * 70)
        print()
        
        # Get February 2026 exams
        cursor.execute("""
            SELECT id, title, batch_id, month, year
            FROM monthly_exams
            WHERE month = 2 AND year = 2026
            ORDER BY id DESC
        """)
        
        exams = cursor.fetchall()
        
        if not exams:
            print("❌ No monthly exams found for February 2026")
            print()
            print("Checking recent exams...")
            cursor.execute("""
                SELECT id, title, batch_id, month, year
                FROM monthly_exams
                ORDER BY year DESC, month DESC
                LIMIT 5
            """)
            recent = cursor.fetchall()
            for ex in recent:
                print(f"  - {ex[1]} ({ex[3]}/{ex[4]})")
        else:
            for exam in exams:
                exam_id, title, batch_id, month, year = exam
                
                # Get batch name
                cursor.execute("SELECT name FROM batches WHERE id = ?", (batch_id,))
                batch_result = cursor.fetchone()
                batch_name = batch_result[0] if batch_result else 'N/A'
                
                print(f"📋 Exam: {title}")
                print(f"   Batch: {batch_name} (ID: {batch_id})")
                print(f"   Month/Year: {month}/{year}")
                print()
                
                # Calculate month boundaries
                month_start = f"{year}-{month:02d}-01"
                if month == 12:
                    month_end = f"{year}-12-31"
                else:
                    next_month = datetime(year, month + 1, 1)
                    month_end = (next_month - timedelta(days=1)).strftime('%Y-%m-%d')
                
                print(f"   Month Range: {month_start} to {month_end}")
                print()
                
                # Count unique attendance days (NEW LOGIC)
                cursor.execute("""
                    SELECT COUNT(DISTINCT date)
                    FROM attendance
                    WHERE batch_id = ?
                      AND date >= ?
                      AND date <= ?
                """, (batch_id, month_start, month_end))
                
                unique_days = cursor.fetchone()[0]
                
                print(f"   ✅ ACTUAL Attendance Days Recorded in DB: {unique_days}")
                
                # Show the actual dates
                if unique_days > 0:
                    cursor.execute("""
                        SELECT DISTINCT date
                        FROM attendance
                        WHERE batch_id = ?
                          AND date >= ?
                          AND date <= ?
                        ORDER BY date
                    """, (batch_id, month_start, month_end))
                    
                    dates = cursor.fetchall()
                    
                    print(f"   📅 Dates where attendance was taken:")
                    for date_tuple in dates:
                        date_str = date_tuple[0]
                        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
                        weekday = date_obj.strftime('%A')
                        print(f"      - {date_str} ({weekday})")
                
                # Old logic for comparison (weekdays only)
                total_weekdays = 0
                current_date = datetime.strptime(month_start, '%Y-%m-%d')
                end_date_obj = datetime.strptime(month_end, '%Y-%m-%d')
                
                while current_date <= end_date_obj:
                    if current_date.weekday() < 5:  # Monday to Friday
                        total_weekdays += 1
                    current_date += timedelta(days=1)
                
                print()
                print(f"   ❌ OLD Logic (All Mon-Fri in Feb 2026): {total_weekdays}")
                print()
                
                if unique_days == total_weekdays:
                    print(f"   💡 You have taken attendance on ALL weekdays!")
                    print(f"      The number {unique_days} is correct.")
                else:
                    print(f"   💡 If you see '{unique_days}' in the UI → Fix is working! ✅")
                    print(f"      If you see '{total_weekdays}' in the UI → Old code still running ❌")
                
                print()
                print("=" * 70)
                print()
        
        conn.close()
        
    except sqlite3.Error as e:
        print(f"❌ Database error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
