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
LOG_FILE="${LOGS_DIR}/prepare_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting Aztec server preparation process"
log "Log file: $LOG_FILE"

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
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

# Main function
main() {
    log "=== Aztec Server Preparation Script ==="
    
    # Check arguments
    if [ "$#" -ne 1 ]; then
        error "Usage: $0 <path_to_csv>"
        error "Example: $0 ../common/sample_ds1.csv"
        exit 1
    fi
    
    local CSV_FILE="$1"
    
    # Convert to absolute path
    if [[ "$CSV_FILE" != /* ]]; then
        CSV_FILE="$(pwd)/$CSV_FILE"
    fi
    
    # Validate CSV file exists
    if [ ! -f "$CSV_FILE" ]; then
        error "CSV file does not exist: $CSV_FILE"
        exit 1
    fi
    
    # Run checks
    check_dependencies
    check_ssh_key
    
    # Make scripts executable
    log "Setting up permissions..."
    chmod +x "${COMMON_DIR}/csv_to_inventory.py"
    
    # Generate inventory
    log "Generating Ansible inventory..."
    cd "${COMMON_DIR}"
    if ! python3 csv_to_inventory.py "$CSV_FILE"; then
        error "Failed to generate inventory"
        exit 1
    fi
    cd "${SCRIPT_DIR}"
    
    # Check if inventory was created
    if [ ! -f "${COMMON_DIR}/inventory/hosts" ]; then
        error "Inventory file was not created"
        exit 1
    fi
    
    local server_count=$(grep -c "ansible_host" "${COMMON_DIR}/inventory/hosts" || echo 0)
    log "Found $server_count servers in inventory"
    
    # Run Ansible playbook
    log "Starting server preparation..."
    log "This process may take several minutes depending on server count"
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    local ansible_cmd="ansible-playbook 01_prepare.yml -i ${COMMON_DIR}/inventory/hosts --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10'"
    
    # Add verbose flag if VERBOSE env var is set
    if [ "${VERBOSE:-}" = "1" ]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    log "Using SSH key: ${ANSIBLE_PRIVATE_KEY_FILE}"
    log "Running: $ansible_cmd"
    
    if eval "$ansible_cmd"; then
        success "=== Server preparation completed successfully! ==="
        log "Next step: run_02_install_docker.sh"
        log "Full log available at: $LOG_FILE"
    else
        error "=== Server preparation failed! ==="
        error "Check the log file for details: $LOG_FILE"
        exit 1
    fi
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
