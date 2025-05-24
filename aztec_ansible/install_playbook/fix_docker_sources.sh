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
LOG_FILE="${LOGS_DIR}/fix_docker_sources_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting Docker sources cleanup process"
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

# Create cleanup script
create_cleanup_script() {
    log "Creating Docker sources cleanup script..."
    
    cat > "${COMMON_DIR}/docker_sources_cleanup.sh" << 'EOF'
#!/bin/bash

set -euo pipefail

echo "Starting Docker sources cleanup..."

# Backup current sources
echo "Creating backup of current sources..."
cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S) || true

# Remove Docker entries from main sources.list
echo "Cleaning /etc/apt/sources.list..."
if [ -f /etc/apt/sources.list ]; then
    sed -i '/docker\.com/d' /etc/apt/sources.list
    sed -i '/Docker/d' /etc/apt/sources.list
fi

# Remove all docker-related files from sources.list.d
echo "Cleaning /etc/apt/sources.list.d/..."
if [ -d /etc/apt/sources.list.d ]; then
    rm -f /etc/apt/sources.list.d/*docker*
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/sources.list.d/docker.list.save
    rm -f /etc/apt/sources.list.d/docker-ce.list
fi

# Remove Docker GPG keys
echo "Removing Docker GPG keys..."
rm -f /usr/share/keyrings/docker-archive-keyring.gpg
rm -f /usr/share/keyrings/docker.gpg
rm -f /etc/apt/trusted.gpg.d/docker.gpg

# Clean apt cache
echo "Cleaning apt cache..."
apt-get clean
rm -rf /var/lib/apt/lists/*

# Update package lists
echo "Updating package lists..."
apt-get update

echo "Docker sources cleanup completed successfully!"
EOF

    chmod +x "${COMMON_DIR}/docker_sources_cleanup.sh"
    success "Cleanup script created"
}

# Main function
main() {
    log "=== Docker Sources Cleanup Script ==="
    
    # Run checks
    check_dependencies
    check_ssh_key
    check_inventory
    
    # Create cleanup script
    create_cleanup_script
    
    # Run cleanup on all servers
    log "Starting Docker sources cleanup on all servers..."
    log "This process may take a few minutes depending on server count"
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    log "Using SSH key: ${ANSIBLE_PRIVATE_KEY_FILE}"
    
    # Copy cleanup script to all servers
    log "Copying cleanup script to all servers..."
    if ansible all -i "${COMMON_DIR}/inventory/hosts" -m copy -a "src=${COMMON_DIR}/docker_sources_cleanup.sh dest=/root/docker_sources_cleanup.sh mode=0755"; then
        success "Cleanup script copied to all servers"
    else
        error "Failed to copy cleanup script to some servers"
        exit 1
    fi
    
    # Execute cleanup script on all servers
    log "Executing cleanup script on all servers..."
    if ansible all -i "${COMMON_DIR}/inventory/hosts" -m shell -a "/root/docker_sources_cleanup.sh" --become; then
        success "Cleanup executed on all servers"
    else
        error "Cleanup failed on some servers"
        exit 1
    fi
    
    # Remove cleanup script from servers
    log "Removing cleanup script from servers..."
    ansible all -i "${COMMON_DIR}/inventory/hosts" -m file -a "path=/root/docker_sources_cleanup.sh state=absent" --become || warning "Could not remove cleanup script from some servers"
    
    # Remove local cleanup script
    rm -f "${COMMON_DIR}/docker_sources_cleanup.sh"
    
    success "=== Docker sources cleanup completed successfully! ==="
    log "You can now run run_02_install_docker.sh to install Docker cleanly"
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
