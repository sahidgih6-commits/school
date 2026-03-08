#!/bin/bash
#
# Force Deploy Attendance Calculation Fix
# This script ensures the fix is pulled AND the application is fully restarted
#

set -e

echo "════════════════════════════════════════════════════════════════"
echo "  Force Deploy Attendance Calculation Fix"
echo "════════════════════════════════════════════════════════════════"
echo ""

VPS_USER="root"
VPS_HOST="103.145.51.132"
VPS_DIR="/var/www/school"

echo "Step 1: Updating Code on VPS..."
ssh ${VPS_USER}@${VPS_HOST} "cd ${VPS_DIR} && git reset --hard origin/main && git pull origin main"
echo "  ✅ Code updated (Forced sync with main)"
echo ""

echo "Step 2: Restarting Application Process..."
# We use pkill to ENSURE the old python process dies, as systemctl reload might fail if process is rogue
# Then we start it properly via systemd or manual fallback
ssh ${VPS_USER}@${VPS_HOST} "
    echo '  • Killing old python processes...'
    pkill -f 'python.*app.py' || true
    
    echo '  • Restarting service...'
    systemctl restart school || {
        echo '  ⚠️ systemctl failed, starting manually...'
        cd ${VPS_DIR}
        nohup python3 app.py > logs/app.log 2>&1 &
    }
"
echo "  ✅ Application restarted"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "  ✅ Deployment Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Please refresh your browser and check the 'Comprehensive Monthly Results' again."
echo "If data is still wrong, check the 'logs/app.log' file on VPS."
