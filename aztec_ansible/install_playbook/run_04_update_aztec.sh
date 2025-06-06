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
LOG_FILE="${LOGS_DIR}/aztec_update_${INVENTORY_NAME}_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting Aztec update process"
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
        return 1
    fi
    
    success "SSH key found at: $(realpath "$ssh_key_path" 2>/dev/null || echo "$ssh_key_path")"
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
        error "Please create the inventory file first or use run_01_prepare.sh"
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
    echo "Examples:"
    echo "  $0              # Use default 'hosts' inventory"
    echo "  $0 hosts_1      # Use 'hosts_1' inventory"
    echo "  $0 hosts_2      # Use 'hosts_2' inventory"
    echo ""
    echo "Available inventory files:"
    ls -1 "${COMMON_DIR}/inventory/" 2>/dev/null | grep -v "^\\." || echo "No inventory files found"
}

# Main function
main() {
    log "=== Aztec Update Script ==="
    
    # Show help if requested
    if [ "$#" -ge 1 ] && [[ "$1" =~ ^(-h|--help|help)$ ]]; then
        show_usage
        exit 0
    fi
    
    # Show confirmation dialog
    echo ""
    warning "This will update Aztec to the latest version on ALL servers in inventory: $INVENTORY_NAME"
    warning "The aztec-node service will be temporarily stopped during the update."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Update cancelled by user"
        exit 0
    fi
    
    # Run checks
    check_dependencies
    check_ssh_key
    check_inventory
    
    # Run Ansible playbook
    log "Starting Aztec update on all servers from inventory: $INVENTORY_NAME"
    log "This process may take 20-30 minutes depending on server count and network speed"
    warning "Do not interrupt this process as it may leave services in inconsistent state"
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    local ansible_cmd="ansible-playbook 04_update_aztec.yml -i $INVENTORY_PATH --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10'"
    
    # Add verbose flag if VERBOSE env var is set
    if [ "${VERBOSE:-}" = "1" ]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    log "Using SSH key: ${ANSIBLE_PRIVATE_KEY_FILE}"
    log "Using inventory: $INVENTORY_PATH"
    log "Running: $ansible_cmd"
    
    if eval "$ansible_cmd"; then
        success "=== Aztec update completed successfully! ==="
        log "All servers in inventory '$INVENTORY_NAME' have been updated to the latest Aztec version"
        log "Full log available at: $LOG_FILE"
        
        # Show service status
        echo ""
        log "Checking Aztec service status on all servers..."
        if ansible all -i "$INVENTORY_PATH" -m shell -a "systemctl is-active aztec-node.service" --one-line; then
            success "All services are running!"
        else
            warning "Some services may need manual attention"
        fi
        
        echo ""
        success "Update completed successfully!"
        log "You can check individual server logs at /var/log/aztec_updates.log on each server"
    else
        error "=== Aztec update failed! ==="
        error "Some servers may be in inconsistent state"
        error "Check the log file for details: $LOG_FILE"
        echo ""
        error "You may need to manually check and restart services on failed servers:"
        error "  sudo systemctl status aztec-node.service"
        error "  sudo systemctl restart aztec-node.service"
        exit 1
    fi
}

# Trap for cleanup
cleanup() {
    if [ $? -ne 0 ]; then
        error "Update script failed. Check log file: $LOG_FILE"
        error ""
        error "If some servers are in inconsistent state, you can:"
        error "1. Check service status: sudo systemctl status aztec-node.service"
        error "2. Restart service: sudo systemctl restart aztec-node.service"
        error "3. Check logs: sudo journalctl -u aztec-node.service -f"
    fi
}

trap cleanup EXIT

# Run main function
main "$@" 
