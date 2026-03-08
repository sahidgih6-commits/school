#!/bin/bash
# Deploy student-level fee fix to VPS

set -e

VPS_IP="194.233.74.48"
VPS_USER="root"
APP_DIR="/var/www/school"
SERVICE_NAME="saro.service"

echo "======================================"
echo "Deploying student-level fee fix to VPS"
echo "======================================"

# Step 1: Pull latest code
echo ""
echo "Step 1: Pulling latest code from GitHub..."
ssh ${VPS_USER}@${VPS_IP} "cd ${APP_DIR} && git pull origin main"

# Step 2: Run migration to add columns
echo ""
echo "Step 2: Running database migration..."
ssh ${VPS_USER}@${VPS_IP} "cd ${APP_DIR} && source venv/bin/activate && python3 add_student_extra_fees.py"

# Step 3: Restart service
echo ""
echo "Step 3: Restarting ${SERVICE_NAME}..."
ssh ${VPS_USER}@${VPS_IP} "systemctl restart ${SERVICE_NAME}"

# Step 4: Check status
echo ""
echo "Step 4: Checking service status..."
ssh ${VPS_USER}@${VPS_IP} "systemctl status ${SERVICE_NAME} --no-pager | head -20"

echo ""
echo "======================================"
echo "✅ Deployment complete!"
echo "======================================"
echo ""
echo "What changed:"
echo "  - exam_fee and others_fee are now STUDENT-LEVEL fields"
echo "  - Stored in 'users' table, NOT in 'fees' table"
echo "  - Saved separately via /api/fees/save-student-extra-fees"
echo "  - No longer saved 12 times (once per month)"
echo ""
echo "Test by:"
echo "  1. Hard refresh browser (Ctrl+Shift+R)"
echo "  2. Go to Fee Management"
echo "  3. Change exam_fee or other_fee for a student"
echo "  4. Click Save - should say 'Saved 1 fee(s)' not 12"
echo ""
