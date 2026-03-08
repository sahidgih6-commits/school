#!/bin/bash
# Fix systemd service file and restart

echo "🔧 Fixing systemd service..."

# Stop the service first
sudo systemctl stop saro 2>/dev/null || true

# Reload systemd daemon to clear any locks
sudo systemctl daemon-reload

# Recreate the service file with correct configuration
sudo tee /etc/systemd/system/saro.service > /dev/null << 'EOF'
[Unit]
Description=Saro Student Management System
After=network.target

[Service]
Type=notify
User=root
WorkingDirectory=/var/www/school
Environment="PATH=/var/www/school/venv/bin"
Environment="FLASK_ENV=production"
Environment="PORT=8001"
ExecStart=/var/www/school/venv/bin/gunicorn --config gunicorn.conf.py wsgi:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file recreated"

# Reload systemd daemon again
sudo systemctl daemon-reload

# Enable the service
sudo systemctl enable saro

# Start the service
sudo systemctl start saro

# Wait a moment
sleep 2

# Check status
sudo systemctl status saro --no-pager -l

echo ""
echo "🎉 Service should be running now!"
echo ""
echo "To check logs: sudo journalctl -u saro -f"
