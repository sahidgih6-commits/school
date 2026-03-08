#!/bin/bash
cd /var/www/school
export FLASK_ENV=production
export DATABASE_PATH=/var/www/school/smartgardenhub.db
/var/www/school/venv/bin/python3 backup_database.py >> logs/backup_cron.log 2>&1
