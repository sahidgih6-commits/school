#!/bin/bash
# Force Update VPS - Clear cache and reload everything

echo "🔄 Force updating VPS..."
echo ""

cd /var/www/school || cd /var/www/saro

echo "1️⃣  Pulling latest code from GitHub..."
git fetch --all
git reset --hard origin/main
echo "✅ Code updated"
echo ""

echo "2️⃣  Clearing Python cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
echo "✅ Python cache cleared"
echo ""

echo "3️⃣  Restarting service with clean state..."
sudo systemctl stop saro
sleep 2
sudo systemctl start saro
sleep 2
echo "✅ Service restarted"
echo ""

echo "4️⃣  Checking service status..."
sudo systemctl status saro --no-pager -l
echo ""

echo "🎉 Done! Now clear your browser cache:"
echo "   - Press Ctrl+Shift+R (Windows/Linux)"
echo "   - Press Cmd+Shift+R (Mac)"
echo "   - Or press F12 > Right-click refresh > Empty Cache and Hard Reload"
