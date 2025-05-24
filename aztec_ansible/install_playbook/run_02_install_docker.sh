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
LOG_FILE="${LOGS_DIR}/docker_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting Docker installation process"
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
    log "Checking inventory..."
    
    if [ ! -f "${COMMON_DIR}/inventory/hosts" ]; then
        error "Inventory file not found. Please run run_01_prepare.sh first."
        exit 1
    fi
    
    local server_count=$(grep -c "ansible_host" "${COMMON_DIR}/inventory/hosts" || echo 0)
    if [ "$server_count" -eq 0 ]; then
        error "No servers found in inventory"
        exit 1
    fi
    
    log "Found $server_count servers in inventory"
}

# Main function
main() {
    log "=== Docker Installation Script ==="
    
    # Run checks
    check_dependencies
    check_ssh_key
    check_inventory
    
    # Run Ansible playbook
    log "Starting Docker installation..."
    log "This process may take 10-15 minutes depending on server count and network speed"
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    local ansible_cmd="ansible-playbook 02_install_docker.yml -i ${COMMON_DIR}/inventory/hosts"
    
    # Add verbose flag if VERBOSE env var is set
    if [ "${VERBOSE:-}" = "1" ]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    # Add force reinstall flag if FORCE env var is set
    if [ "${FORCE:-}" = "1" ]; then
        ansible_cmd="$ansible_cmd -e force_reinstall=true"
    fi
    
    log "Using SSH key: ${ANSIBLE_PRIVATE_KEY_FILE}"
    log "Running: $ansible_cmd"
    
    if eval "$ansible_cmd"; then
        success "=== Docker installation completed successfully! ==="
        log "Next step: run_03_install_aztec.sh"
        log "Full log available at: $LOG_FILE"
        
        # Show Docker status
        echo ""
        log "Testing Docker installation on all servers..."
        if ansible all -i "${COMMON_DIR}/inventory/hosts" -m shell -a "docker --version" --one-line; then
            success "Docker is working on all servers!"
        else
            warning "Some servers may have Docker issues"
        fi
    else
        error "=== Docker installation failed! ==="
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
