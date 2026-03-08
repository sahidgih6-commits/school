#!/bin/bash
# Diagnose and fix saro service issues

echo "🔍 Diagnosing Saro Service Issues..."
echo "===================================="

# Check if we're in the right directory
cd /var/www/school || exit 1

# Show recent error logs
echo ""
echo "📋 Recent Error Logs:"
echo "--------------------"
sudo journalctl -u saro -n 50 --no-pager

# Check if virtual environment exists
echo ""
echo "🔍 Checking Virtual Environment..."
if [ -d "venv" ]; then
    echo "✅ venv directory exists"
    
    # Check if gunicorn is installed
    if [ -f "venv/bin/gunicorn" ]; then
        echo "✅ gunicorn is installed"
    else
        echo "❌ gunicorn not found, installing..."
        source venv/bin/activate
        pip install gunicorn
    fi
else
    echo "❌ venv directory not found"
    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Check if wsgi.py exists
echo ""
echo "🔍 Checking Application Files..."
if [ -f "wsgi.py" ]; then
    echo "✅ wsgi.py exists"
    echo "Contents:"
    cat wsgi.py
else
    echo "❌ wsgi.py not found"
fi

# Try to run the app manually to see errors
echo ""
echo "🧪 Testing Application Startup..."
echo "Running: source venv/bin/activate && python wsgi.py"
cd /var/www/school
source venv/bin/activate
timeout 5 python wsgi.py 2>&1 || true

echo ""
echo "===================================="
echo "🔧 Attempting to fix and restart..."

# Stop the service
sudo systemctl stop saro

# Kill any existing gunicorn processes
sudo pkill -9 gunicorn 2>/dev/null || true

# Check port 8001 or 5000
echo ""
echo "🔍 Checking ports..."
if netstat -tuln | grep -E ':(8001|5000)'; then
    echo "⚠️  Port is in use, killing process..."
    sudo fuser -k 8001/tcp 2>/dev/null || true
    sudo fuser -k 5000/tcp 2>/dev/null || true
fi

# Wait a moment
sleep 2

# Start service again
sudo systemctl start saro

# Wait and check status
sleep 3
sudo systemctl status saro --no-pager -l

echo ""
echo "===================================="
echo "If still failing, check the error logs above"
echo "Common issues:"
echo "  1. Missing dependencies: pip install -r requirements.txt"
echo "  2. Database not initialized: python init_db.py"
echo "  3. Port already in use: change port in service file"
echo "  4. Python version mismatch: check venv python version"
