#!/bin/bash
# Smart Application Startup Script

echo "🚀 Starting Application..."

# Kill any existing processes
echo "Stopping existing processes..."
pkill -f "python3.*app.py" 2>/dev/null
pkill -f "gunicorn.*app:app" 2>/dev/null
sleep 2

# Check if systemd service exists
if systemctl list-units --type=service --all | grep -q "school\|gunicorn"; then
    echo "✅ Found systemd service. Using systemctl..."
    sudo systemctl restart school 2>/dev/null || sudo systemctl restart gunicorn 2>/dev/null
    sleep 2
    sudo systemctl status school 2>/dev/null || sudo systemctl status gunicorn 2>/dev/null
else
    echo "⚠️  No systemd service found. Starting manually..."
    
    # Set production environment
    export FLASK_ENV=production
    export PORT=8000
    
    # Start with python3
    if command -v python3 &> /dev/null; then
        echo "✅ Starting with python3..."
        nohup python3 app.py > logs/app.log 2>&1 &
        echo "✅ Application started. PID: $!"
        echo "📝 Logs: tail -f logs/app.log"
    else
        echo "❌ python3 not found!"
        exit 1
    fi
fi

echo ""
echo "🔍 Checking if app is running..."
sleep 3

if pgrep -f "python3.*app.py\|gunicorn" > /dev/null; then
    echo "✅ Application is running!"
    echo ""
    echo "Process info:"
    ps aux | grep -E "python3.*app.py|gunicorn.*app:app" | grep -v grep
else
    echo "❌ Application may not be running. Check logs:"
    echo "   tail -f logs/app.log"
fi
