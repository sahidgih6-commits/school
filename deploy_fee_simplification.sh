#!/bin/bash
# Complete Deployment Script for Fee System Simplification

set -e  # Exit on error

echo "=========================================="
echo "Fee System Simplification Deployment"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check if database exists
echo -e "${BLUE}Step 1: Checking database...${NC}"
if [ -f "smartgardenhub.db" ] || [ -f "/var/www/school/smartgardenhub.db" ]; then
    echo -e "${GREEN}✓ Database found${NC}"
    
    # Run migration
    echo ""
    echo -e "${BLUE}Step 2: Running database migration...${NC}"
    python migrate_remove_jf_tf.py
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Migration completed successfully${NC}"
    else
        echo -e "${RED}✗ Migration failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ No database found. Will be created on first run.${NC}"
fi

# Step 3: Update dashboard template
echo ""
echo -e "${BLUE}Step 3: Checking dashboard template...${NC}"

TEMPLATE_FILE="templates/templates/dashboard_teacher.html"

if [ -f "$TEMPLATE_FILE" ]; then
    # Check if already using simplified version
    if grep -q "fee_management_simple.html" "$TEMPLATE_FILE"; then
        echo -e "${GREEN}✓ Already using simplified fee management UI${NC}"
    elif grep -q "fee_management_new.html" "$TEMPLATE_FILE"; then
        echo -e "${YELLOW}⚠ Found old fee management UI reference${NC}"
        echo -e "${YELLOW}  Manual action required: Update $TEMPLATE_FILE${NC}"
        echo -e "${YELLOW}  Change: fee_management_new.html → fee_management_simple.html${NC}"
    else
        echo -e "${YELLOW}⚠ Fee management partial not found in template${NC}"
    fi
else
    echo -e "${RED}✗ Template file not found: $TEMPLATE_FILE${NC}"
fi

# Step 4: Verify files
echo ""
echo -e "${BLUE}Step 4: Verifying required files...${NC}"

FILES=(
    "models.py"
    "routes/fees_new.py"
    "routes/fees_simple.py"
    "templates/templates/partials/fee_management_simple.html"
    "migrate_remove_jf_tf.py"
)

ALL_PRESENT=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file ${RED}(missing)${NC}"
        ALL_PRESENT=false
    fi
done

echo ""
if [ "$ALL_PRESENT" = true ]; then
    echo -e "${GREEN}✓ All required files present${NC}"
else
    echo -e "${RED}✗ Some files are missing${NC}"
    exit 1
fi

# Step 5: Test fee routes
echo ""
echo -e "${BLUE}Step 5: Testing fee routes...${NC}"
echo "  Starting test server temporarily..."

# Check if server is already running
if lsof -Pi :8001 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Server already running on port 8001${NC}"
    
    # Test the endpoint
    echo "  Testing /api/fees/test endpoint..."
    RESPONSE=$(curl -s http://localhost:8001/api/fees/test || echo "failed")
    
    if echo "$RESPONSE" | grep -q "success"; then
        echo -e "${GREEN}✓ Fee routes are working${NC}"
    else
        echo -e "${YELLOW}⚠ Could not verify fee routes (server may not be ready)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Server not running. Start it to test fee routes.${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}Deployment Summary${NC}"
echo "=========================================="
echo ""
echo "Completed steps:"
echo "  ✓ Database migration (if database existed)"
echo "  ✓ File verification"
echo ""
echo "Manual steps required:"
echo ""
echo "1. Update templates/templates/dashboard_teacher.html"
echo "   Change:"
echo "   {% include 'partials/fee_management_new.html' %}"
echo "   to:"
echo "   {% include 'partials/fee_management_simple.html' %}"
echo ""
echo "2. Restart your application:"
echo "   For development: Ctrl+C and restart Flask"
echo "   For production: sudo systemctl restart school"
echo ""
echo "3. Test the new fee management:"
echo "   - Login as teacher"
echo "   - Go to Fee Management tab"
echo "   - Verify 12 month columns (no JF/TF split)"
echo ""
echo "For more details, see: FEE_SYSTEM_SIMPLIFICATION.md"
echo "=========================================="
