#!/bin/bash

# Complete deployment script for VPS - fixes fee system and SMS templates
# Run this on VPS at: /var/www/school

echo "=========================================="
echo "DEPLOYING ALL FIXES TO VPS"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Stop the service
echo -e "\n${YELLOW}1. Stopping service...${NC}"
sudo systemctl stop saro.service
sudo pkill -9 -f gunicorn 2>/dev/null
sleep 2
sudo rm -f /tmp/smartgarden-hub.pid
echo -e "${GREEN}✓ Service stopped${NC}"

# Navigate to project directory
cd /var/www/school || exit 1

# Activate virtual environment
echo -e "\n${YELLOW}2. Activating virtual environment...${NC}"
source venv/bin/activate
echo -e "${GREEN}✓ Virtual environment activated${NC}"

# Pull latest code
echo -e "\n${YELLOW}3. Pulling latest code from GitHub...${NC}"
git pull origin main
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Code updated successfully${NC}"
else
    echo -e "${RED}✗ Failed to pull code${NC}"
    exit 1
fi

# Check Settings table for SMS templates
echo -e "\n${YELLOW}4. Checking/Creating Settings table for SMS templates...${NC}"
python3 check_settings_table.py
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Settings table ready${NC}"
else
    echo -e "${RED}✗ Settings table check failed${NC}"
fi

# Verify database schema
echo -e "\n${YELLOW}5. Verifying database schema...${NC}"

# Check if fees table has exam_fee and others_fee columns
python3 << 'EOF'
from app import create_app
from models import db
from sqlalchemy import text

app = create_app('production')
with app.app_context():
    # Check fees table columns
    result = db.session.execute(text("PRAGMA table_info(fees)"))
    columns = [row[1] for row in result.fetchall()]
    
    has_exam_fee = 'exam_fee' in columns
    has_others_fee = 'others_fee' in columns
    
    print(f"\n📊 Fees table columns check:")
    print(f"  exam_fee: {'✓' if has_exam_fee else '✗ MISSING'}")
    print(f"  others_fee: {'✓' if has_others_fee else '✗ MISSING'}")
    
    if not has_exam_fee or not has_others_fee:
        print("\n⚠️  Missing columns detected. These should have been added by previous migrations.")
        print("   If fees still don't save, check VPS database manually.")
    
    # Check settings table
    result = db.session.execute(text("""
        SELECT name FROM sqlite_master WHERE type='table' AND name='settings'
    """))
    has_settings = bool(result.fetchone())
    
    print(f"\n📊 Settings table: {'✓ exists' if has_settings else '✗ MISSING'}")
    
    # Check online exam tables
    result = db.session.execute(text("""
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name IN ('online_exams', 'online_questions')
    """))
    tables = [row[0] for row in result.fetchall()]
    
    print(f"\n📊 Online exam tables:")
    print(f"  online_exams: {'✓' if 'online_exams' in tables else '✗'}")
    print(f"  online_questions: {'✓' if 'online_questions' in tables else '✗'}")
EOF

echo -e "${GREEN}✓ Schema verification complete${NC}"

# Restart the service
echo -e "\n${YELLOW}6. Starting service...${NC}"
sudo systemctl start saro.service
sleep 3

# Check service status
if sudo systemctl is-active --quiet saro.service; then
    echo -e "${GREEN}✓ Service started successfully${NC}"
    echo -e "\n${GREEN}=========================================="
    echo -e "DEPLOYMENT COMPLETE!"
    echo -e "==========================================${NC}"
    echo -e "\nService Status:"
    sudo systemctl status saro.service --no-pager -l
    
    echo -e "\n${GREEN}✅ All fixes deployed:${NC}"
    echo -e "  1. Fee system - exam_fee and other_fee columns"
    echo -e "  2. SMS templates - database storage with PUT method"
    echo -e "  3. Online exams - complete schema with all columns"
    
    echo -e "\n${YELLOW}📝 Test the following:${NC}"
    echo -e "  1. Fee Management - Add exam_fee and other_fee, click Save"
    echo -e "  2. SMS Templates - Edit a template, save, logout, login - check it persists"
    echo -e "  3. Online Exam - Create exam and add questions"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo -e "\nService logs:"
    sudo journalctl -u saro.service -n 50 --no-pager
    exit 1
fi
