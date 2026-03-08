#!/bin/bash
# Force fix student dashboard on VPS

echo "🔧 Forcing student dashboard fix..."

cd /var/www/school
git pull

# Kill any running processes
echo "🛑 Killing old processes..."
pkill -f gunicorn || true
sleep 2

# Remove PID file if exists
rm -f /var/www/school/saro.pid

# Restart service
echo "🔄 Restarting service..."
systemctl restart saro.service

# Wait and check status
sleep 3
echo "📊 Service status:"
systemctl status saro.service --no-pager | head -15

echo ""
echo "✅ Done! Now:"
echo "1. Close ALL browser tabs"
echo "2. Open NEW Incognito window (Ctrl+Shift+N)"
echo "3. Go to your site"
echo "4. Login as student"
echo "5. Click 'Online Exam' - should see exam list"
echo "6. Click 'Online Resources' - should see PDF documents"
