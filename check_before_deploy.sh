#!/bin/bash
#
# Pre-deployment check script
# Verifies GitHub connection and repository status before deployment
#
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_DIR="/var/www/school"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Pre-Deployment Checks${NC}"
echo -e "${BLUE}================================================${NC}"

# Check if directory exists
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}❌ Application directory not found: $APP_DIR${NC}"
    exit 1
fi

cd $APP_DIR

echo ""
echo -e "${GREEN}=== Git Repository Status ===${NC}"

# Check if it's a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Not a git repository${NC}"
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Check remote URL
REMOTE_URL=$(git config --get remote.origin.url)
echo "Remote URL: $REMOTE_URL"

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  Uncommitted local changes detected:${NC}"
    git status --short
    echo ""
    echo -e "${YELLOW}These will be stashed during deployment${NC}"
else
    echo -e "${GREEN}✅ Working directory clean${NC}"
fi

echo ""
echo -e "${GREEN}=== GitHub Connectivity ===${NC}"

# Test GitHub connection
if git ls-remote origin HEAD &>/dev/null; then
    echo -e "${GREEN}✅ GitHub connection successful${NC}"
else
    echo -e "${RED}❌ Cannot connect to GitHub${NC}"
    echo "Troubleshooting:"
    echo "  1. Check internet connection"
    echo "  2. Verify SSH key: ssh -T git@github.com"
    echo "  3. Check repository access permissions"
    exit 1
fi

# Fetch latest info
git fetch origin &>/dev/null

# Check if local is behind remote
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
BASE=$(git merge-base @ @{u} 2>/dev/null || echo "")

if [ -z "$REMOTE" ]; then
    echo -e "${YELLOW}⚠️  No upstream branch configured${NC}"
elif [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "${GREEN}✅ Up to date with GitHub${NC}"
elif [ "$LOCAL" = "$BASE" ]; then
    COMMITS_BEHIND=$(git rev-list --count HEAD..@{u})
    echo -e "${BLUE}📥 Behind by $COMMITS_BEHIND commit(s)${NC}"
    echo ""
    echo "New commits on GitHub:"
    git log --oneline HEAD..@{u} | head -5
elif [ "$REMOTE" = "$BASE" ]; then
    COMMITS_AHEAD=$(git rev-list --count @{u}..HEAD)
    echo -e "${YELLOW}⚠️  Ahead by $COMMITS_AHEAD commit(s) (unpushed local commits)${NC}"
else
    echo -e "${YELLOW}⚠️  Branches have diverged${NC}"
fi

echo ""
echo -e "${GREEN}=== Current State ===${NC}"
echo "Last local commit:"
git log -1 --oneline

echo ""
echo "Last GitHub commit:"
git log -1 --oneline origin/$CURRENT_BRANCH

echo ""
echo -e "${GREEN}=== Service Status ===${NC}"
if systemctl is-active --quiet saro.service; then
    echo -e "${GREEN}✅ Service is running${NC}"
else
    echo -e "${RED}❌ Service is not running${NC}"
fi

echo ""
echo -e "${GREEN}=== Database Status ===${NC}"
DB_FILE="$APP_DIR/smartgardenhub.db"
if [ -f "$DB_FILE" ]; then
    DB_SIZE=$(du -h "$DB_FILE" | cut -f1)
    echo "Database size: $DB_SIZE"
    echo -e "${GREEN}✅ Database exists${NC}"
else
    echo -e "${YELLOW}⚠️  Database not found (fresh installation)${NC}"
fi

echo ""
echo -e "${GREEN}=== Backup Status ===${NC}"
BACKUP_DIR="$APP_DIR/backups"
if [ -d "$BACKUP_DIR" ]; then
    BACKUP_COUNT=$(find $BACKUP_DIR -name "*.db" | wc -l)
    if [ $BACKUP_COUNT -gt 0 ]; then
        LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.db 2>/dev/null | head -1)
        BACKUP_AGE=$(stat -c %y "$LATEST_BACKUP" 2>/dev/null | cut -d' ' -f1)
        echo "Latest backup: $BACKUP_AGE"
        echo "Total backups: $BACKUP_COUNT"
    else
        echo -e "${YELLOW}⚠️  No backups found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Backup directory not found${NC}"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ Pre-deployment checks complete${NC}"
echo ""
echo "Ready to deploy? Run:"
echo "  sudo ./quick_deploy.sh          (quick update)"
echo "  sudo ./deploy_sqlite_production.sh  (full deployment)"
echo -e "${BLUE}================================================${NC}"
