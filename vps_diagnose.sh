#!/bin/bash
# Quick VPS Diagnostic Script

echo "=============================================="
echo "🔍 VPS System Diagnostic"
echo "=============================================="

# 1. Find database file
echo ""
echo "📁 Searching for database files..."
find /var/www/school -name "*.db" 2>/dev/null | head -10

# 2. Check virtual environment
echo ""
echo "🐍 Checking for virtual environments..."
ls -la /var/www/school/ | grep -E "venv|env|.venv"

# 3. Check Python packages
echo ""
echo "📦 Checking if SQLAlchemy is installed..."
python3 -c "import sqlalchemy; print('✅ SQLAlchemy installed')" 2>&1 || echo "❌ SQLAlchemy NOT installed"

# 4. Find running services
echo ""
echo "🔧 Checking for running services..."
systemctl list-units --type=service --state=running | grep -E "saro|gunicorn|flask" || echo "No matching services found"

# 5. Check running Python/Gunicorn processes
echo ""
echo "🔄 Checking for Python/Gunicorn processes..."
ps aux | grep -E "python|gunicorn" | grep -v grep | head -5

# 6. Check current directory structure
echo ""
echo "📂 Current directory structure:"
ls -la /var/www/school/ | head -20

echo ""
echo "=============================================="
echo "✅ Diagnostic complete"
echo "=============================================="
