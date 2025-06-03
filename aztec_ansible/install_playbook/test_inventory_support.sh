#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

echo "=== Testing Multiple Inventory Support ==="
echo ""

log "Testing help functionality..."

# Test help for each script
scripts=("run_00_fix_docker_sources.sh" "run_02_install_docker.sh" "run_03_install_aztec.sh" "run_04_update_aztec.sh")

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        log "Testing help for $script"
        if ./"$script" --help &>/dev/null; then
            success "$script supports help flag"
        else
            error "$script does not support help flag"
        fi
    else
        error "$script not found"
    fi
done

echo ""
log "Checking available inventory files..."

if [ -d "../common/inventory" ]; then
    inventory_files=$(ls -1 ../common/inventory/ 2>/dev/null | grep -v "^\\." || echo "")
    if [ -n "$inventory_files" ]; then
        success "Available inventory files:"
        echo "$inventory_files" | sed 's/^/  - /'
    else
        warning "No inventory files found"
    fi
else
    error "Inventory directory not found"
fi

echo ""
log "Testing inventory parameter parsing..."

# Test if scripts accept inventory parameter without actually running them
for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        log "Testing $script with test_inventory parameter..."
        # This should show usage/error since test_inventory doesn't exist
        if ./"$script" test_inventory 2>&1 | grep -q "not found"; then
            success "$script correctly handles missing inventory file"
        else
            warning "$script may not handle missing inventory correctly"
        fi
    fi
done

echo ""
success "Multiple inventory support test completed!"
echo ""
echo "Usage examples:"
echo "  ./run_04_update_aztec.sh              # Use default 'hosts'"
echo "  ./run_04_update_aztec.sh hosts_1      # Use 'hosts_1'"
echo "  ./run_04_update_aztec.sh --help       # Show help" 
