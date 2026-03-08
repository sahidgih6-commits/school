#!/bin/bash

echo "================================"
echo "🔧 Fix VPS Service - Correct Commands"
echo "================================"
echo ""
echo "Service Name: saro.service"
echo "Virtual Environment: /var/www/school/venv"
echo ""

echo "Run these commands on your VPS:"
echo ""

echo "# 1. Stop the service"
echo "sudo systemctl stop saro.service"
echo ""

echo "# 2. Install gunicorn in the virtual environment"
echo "cd /var/www/school"
echo "source venv/bin/activate"
echo "pip install gunicorn"
echo ""

echo "# 3. Install all requirements"
echo "pip install -r requirements.txt"
echo ""

echo "# 4. Pull latest code (fee and SMS fixes)"
echo "git pull origin main"
echo ""

echo "# 5. Restart service"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl restart saro.service"
echo ""

echo "# 6. Check status"
echo "sudo systemctl status saro.service"
echo ""

echo "# 7. View logs"
echo "sudo journalctl -u saro.service -f"
echo ""

echo "================================"
echo "ONE-LINE FIX:"
echo "================================"
echo "sudo systemctl stop saro.service && cd /var/www/school && source venv/bin/activate && pip install gunicorn && pip install -r requirements.txt && git pull origin main && deactivate && sudo systemctl restart saro.service && sudo systemctl status saro.service"
echo ""
