#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Change to script directory
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
COMMON_DIR="../common"
LOGS_DIR="../logs"

# Parse command line arguments
INVENTORY_NAME="hosts"
if [ "$#" -ge 1 ]; then
    INVENTORY_NAME="$1"
fi

INVENTORY_PATH="${COMMON_DIR}/inventory/${INVENTORY_NAME}"
LOG_FILE="${LOGS_DIR}/fix_testnet_and_update_${INVENTORY_NAME}_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting combined testnet fix and Aztec update process"
log "Using inventory: $INVENTORY_NAME"
log "Log file: $LOG_FILE"

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing_deps+=("ansible")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
        error "Please install them before running this script"
        exit 1
    fi
    
    success "All dependencies found"
}

# Check SSH key
check_ssh_key() {
    log "Checking SSH key..."
    
    local ssh_key_path="${COMMON_DIR}/ssh/id_rsa"
    
    if [ ! -f "$ssh_key_path" ]; then
        error "SSH key not found at: $(realpath "$ssh_key_path" 2>/dev/null || echo "$ssh_key_path")"
        error "Please place your SSH private key there and set permissions to 600"
        echo ""
        error "To fix this:"
        error "1. Copy your SSH key: cp /path/to/your/key $(realpath "$ssh_key_path" 2>/dev/null || echo "$ssh_key_path")"
        error "2. Set permissions: chmod 600 $(realpath "$ssh_key_path" 2>/dev/null || echo "$ssh_key_path")"
        return 1
    fi
    
    local perms=$(stat -c "%a" "$ssh_key_path" 2>/dev/null || stat -f "%A" "$ssh_key_path" 2>/dev/null)
    if [ "$perms" != "600" ] && [ "$perms" != "400" ]; then
        warning "SSH key permissions are $perms, should be 600 or 400"
        warning "Attempting to fix permissions..."
        chmod 600 "$ssh_key_path"
    fi
    
    success "SSH key found at: $(realpath "$ssh_key_path" 2>/dev/null || echo "$ssh_key_path")"
    success "SSH key permissions: $(stat -c "%a" "$ssh_key_path" 2>/dev/null || stat -f "%A" "$ssh_key_path" 2>/dev/null)"
}

# Check inventory
check_inventory() {
    log "Checking inventory: $INVENTORY_NAME"
    
    if [ ! -f "$INVENTORY_PATH" ]; then
        error "Inventory file not found: $INVENTORY_PATH"
        echo ""
        error "Available inventory files:"
        ls -la "${COMMON_DIR}/inventory/" 2>/dev/null || echo "No inventory directory found"
        echo ""
        error "Please generate the inventory file first using generate_hosts.sh"
        error "Example: cd ../../ && ./generate_hosts.sh wallets_alex.csv"
        exit 1
    fi
    
    local server_count=$(grep -c "ansible_host" "$INVENTORY_PATH" || echo 0)
    if [ "$server_count" -eq 0 ]; then
        error "No servers found in inventory: $INVENTORY_NAME"
        exit 1
    fi
    
    log "Found $server_count servers in inventory: $INVENTORY_NAME"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [inventory_name]"
    echo ""
    echo "This script performs both operations on each server sequentially:"
    echo "1. Fixes testnet parameter (alpha-testnet -> testnet) in start_aztec_node.sh"
    echo "2. Updates Aztec to the latest version using aztec-up latest"
    echo ""
    echo "Operations are performed server by server, not task by task across all servers."
    echo "Make sure to generate the inventory file first using generate_hosts.sh"
    echo ""
    echo "Examples:"
    echo "  $0                    # Use default 'hosts' inventory"
    echo "  $0 hosts_alex         # Use 'hosts_alex' inventory"
    echo "  $0 hosts_stepa        # Use 'hosts_stepa' inventory"
    echo ""
    echo "Available inventory files:"
    ls -1 "${COMMON_DIR}/inventory/" 2>/dev/null | grep -v "^\\." || echo "No inventory files found"
    echo ""
    echo "To generate inventory:"
    echo "  cd ../../ && ./generate_hosts.sh wallets_alex.csv"
}

# Run combined operations
run_combined_operations() {
    log "=== Starting combined testnet fix and Aztec update ==="
    log "Processing servers one by one with both operations..."
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    local ansible_cmd="ansible-playbook fix_testnet_and_update.yml -i $INVENTORY_PATH"
    
    # Add verbose flag if VERBOSE env var is set
    if [ "${VERBOSE:-}" = "1" ]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    # Add serial execution to process one server at a time
    ansible_cmd="$ansible_cmd --forks=1"
    
    log "Running: $ansible_cmd"
    
    if eval "$ansible_cmd"; then
        success "=== Combined operations completed successfully! ==="
    else
        error "=== Combined operations failed! ==="
        error "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Main function
main() {
    log "=== Combined Testnet Fix and Aztec Update Script ==="
    
    # Show help if requested
    if [ "$#" -ge 1 ] && [[ "$1" =~ ^(-h|--help|help)$ ]]; then
        show_usage
        exit 0
    fi
    
    # Run checks
    check_dependencies
    check_ssh_key
    check_inventory
    
    # Run combined operations
    run_combined_operations
    
    # Final success message
    echo ""
    success "=== All tasks completed successfully! ==="
    log "Both operations completed on all servers:"
    log "1. Fixed testnet parameter (alpha-testnet -> testnet) in start_aztec_node.sh"
    log "2. Updated Aztec to latest version"
    log "Full log available at: $LOG_FILE"
}

# Trap for cleanup
cleanup() {
    if [ $? -ne 0 ]; then
        error "Script failed. Check log file: $LOG_FILE"
    fi
}

trap cleanup EXIT

# Run main function
main "$@"
