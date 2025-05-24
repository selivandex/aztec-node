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
LOG_FILE="${LOGS_DIR}/aztec_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting Aztec installation process"
log "Log file: $LOG_FILE"

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing_deps+=("ansible")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
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

# Pre-populate SSH host keys
pre_populate_ssh_keys() {
    log "Setting up SSH to avoid interactive prompts..."
    
    # Create SSH directory if it doesn't exist
    mkdir -p ~/.ssh
    
    # Create empty known_hosts to avoid warnings
    touch ~/.ssh/known_hosts
    chmod 600 ~/.ssh/known_hosts
    
    success "SSH setup completed"
}

# Check Docker installation
check_docker() {
    log "Checking Docker installation on servers..."
    
    if ! ansible all -i "${COMMON_DIR}/inventory/hosts" -m shell -a "docker --version" --one-line &>/dev/null; then
        warning "Docker may not be installed on all servers"
        log "You may need to run run_02_install_docker.sh first"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "Docker is available on all servers"
    fi
}

# Main function
main() {
    log "=== Aztec Installation Script ==="
    
    # Run checks
    check_dependencies
    check_ssh_key
    check_inventory
    pre_populate_ssh_keys
    check_docker
    
    # Download Install.sh if needed
    if [ ! -f "${COMMON_DIR}/Install.sh" ]; then
        warning "Install.sh not found. Downloading from repository..."
        if ! curl -sf --retry 3 --retry-delay 5 \
            "https://raw.githubusercontent.com/selivandex/aztec-node/refs/heads/master/Install.sh" \
            -o "${COMMON_DIR}/Install.sh"; then
            error "Failed to download Install.sh"
            exit 1
        fi
        chmod +x "${COMMON_DIR}/Install.sh"
        success "Install.sh downloaded successfully"
    fi
    
    # Run Ansible playbook
    log "Starting Aztec installation..."
    log "This may take 30+ minutes depending on server count and network speed"
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    local ansible_cmd="ansible-playbook 03_install_aztec.yml -i ${COMMON_DIR}/inventory/hosts --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10'"
    
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
        success "=== Aztec installation completed successfully! ==="
        log "Check individual server logs at /var/log/aztec_install.log on each server"
        log "Full log available at: $LOG_FILE"
        
        # Show service status
        echo ""
        log "Checking Aztec service status on all servers..."
        if ansible all -i "${COMMON_DIR}/inventory/hosts" -m shell -a "systemctl is-active aztec-node.service || echo 'Service not found'" --one-line; then
            log "Service status check completed"
        fi
        
        echo ""
        success "Installation complete! You can now use get_proof playbook to collect proof data."
    else
        error "=== Aztec installation failed! ==="
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
