#!/bin/bash
# VPS Deployment - Quick Reference Card
# Save this on your VPS for easy access

cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║           SAROYARSIR VPS DEPLOYMENT QUICK REFERENCE            ║
╚════════════════════════════════════════════════════════════════╝

📍 LOCATION: /var/www/school

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎬 FIRST TIME SETUP (Run once)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

wget https://raw.githubusercontent.com/sa5613675-jpg/school/main/setup_vps_first_time.sh
sudo chmod +x setup_vps_first_time.sh
sudo ./setup_vps_first_time.sh
cd /var/www/school
sudo ./deploy_sqlite_production.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 REGULAR DEPLOYMENT (Most common - after pushing to GitHub)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cd /var/www/school

# Step 1: Check before deploying (optional but recommended)
./check_before_deploy.sh

# Step 2: Deploy
sudo ./quick_deploy.sh

# That's it! ✅

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 TYPICAL WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ON YOUR LOCAL MACHINE:
1. Make code changes
2. git add .
3. git commit -m "Your message"
4. git push origin main

ON VPS:
1. cd /var/www/school
2. sudo ./quick_deploy.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 SERVICE MANAGEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo systemctl start saro.service      # Start
sudo systemctl stop saro.service       # Stop
sudo systemctl restart saro.service    # Restart
sudo systemctl status saro.service     # Status
sudo journalctl -u saro.service -f     # Live logs

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💾 DATABASE OPERATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo python3 optimize_sqlite.py        # Optimize DB
sudo ./backup_daily.sh                 # Manual backup
sqlite3 smartgardenhub.db              # Access DB
du -h smartgardenhub.db                # Check size

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🆘 TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Service won't start
sudo journalctl -u saro.service -n 50

# Git pull fails
git status
git stash
git pull origin main

# Reset to GitHub version (discard local changes)
git fetch origin
git reset --hard origin/main
sudo systemctl restart saro.service

# Check if app is responding
curl http://localhost:8001

# Fix permissions
sudo chown -R www-data:www-data /var/www/school
sudo chmod 664 smartgardenhub.db

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 MONITORING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

tail -f /var/log/saro_access.log       # Access logs
tail -f /var/log/saro_error.log        # Error logs
./health_check.sh                      # Health check
./check_before_deploy.sh               # Pre-deploy check

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 IMPORTANT PATHS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

App:        /var/www/school/
Database:   /var/www/school/smartgardenhub.db
Backups:    /var/www/school/backups/
Logs:       /var/log/saro_*.log
Service:    /etc/systemd/system/saro.service
Nginx:      /etc/nginx/sites-available/school

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 HELPFUL TIPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Always check status before deploying: ./check_before_deploy.sh
• Use quick_deploy.sh for regular updates (faster)
• Use deploy_sqlite_production.sh for major updates
• Backups run automatically at 2 AM daily
• Keep last commit message handy for rollback if needed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For detailed guide: cat SQLITE_PRODUCTION_GUIDE.md

EOF
