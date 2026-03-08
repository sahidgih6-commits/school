#!/bin/bash
# Test student dashboard on VPS

echo "=== TESTING STUDENT DASHBOARD ON VPS ==="
echo ""

cd /var/www/school
source venv/bin/activate

echo "1. Checking published exams..."
python3 << 'PYTHON'
from app import create_app
from models import OnlineExam

app = create_app()
with app.app_context():
    published_exams = OnlineExam.query.filter_by(is_published=True, is_active=True).all()
    print(f"Published & Active exams: {len(published_exams)}")
    for exam in published_exams:
        print(f"  - {exam.title} (ID: {exam.id}, Questions: {exam.questions.count()})")
PYTHON

echo ""
echo "2. Testing API endpoint as student..."
curl -s http://localhost:8001/api/online-exams | python3 -m json.tool | head -50

echo ""
echo "3. Checking if service is running..."
systemctl status saro.service --no-pager | grep -A 5 "Active:"

echo ""
echo "4. Checking recent logs..."
journalctl -u saro.service -n 20 --no-pager

echo ""
echo "=== TEST COMPLETE ==="
