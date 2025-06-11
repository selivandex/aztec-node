#!/bin/bash

# Script to install Zabbix monitoring on Aztec nodes
# Usage: ./run_05_install_zabbix.sh [inventory_name] [zabbix_server_ip]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(dirname "$SCRIPT_DIR")/common"

# Default values
DEFAULT_INVENTORY="hosts"
DEFAULT_ZABBIX_SERVER="YOUR_ZABBIX_SERVER_IP"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

show_usage() {
    cat << EOF
🔧 Zabbix Monitoring Installation Script for Aztec Nodes

USAGE:
    $0 [inventory_name] [zabbix_server_ip]

PARAMETERS:
    inventory_name    - Name of inventory file (default: hosts)
    zabbix_server_ip  - IP address of your Zabbix server (required)

EXAMPLES:
    # Install on default inventory with Zabbix server at 192.168.1.100
    $0 hosts 192.168.1.100
    
    # Install on specific inventory
    $0 hosts_production 10.0.0.50
    
    # Using environment variable
    ZABBIX_SERVER=192.168.1.100 $0 hosts

REQUIREMENTS:
    - Ansible installed
    - SSH key configured: $COMMON_DIR/ssh/id_rsa
    - Inventory file: $COMMON_DIR/inventory/[inventory_name]
    - Servers should be accessible via SSH

WHAT THIS SCRIPT DOES:
    ✅ Installs Zabbix Agent 2 on all servers
    ✅ Configures Aztec-specific monitoring
    ✅ Creates UserParameters for RPC checks
    ✅ Sets up systemd service monitoring
    ✅ Tests connectivity and functionality

EOF
}

# Parse command line arguments
INVENTORY_NAME="${1:-$DEFAULT_INVENTORY}"
ZABBIX_SERVER="${2:-$ZABBIX_SERVER}"

if [[ "$1" =~ ^(-h|--help|help)$ ]]; then
    show_usage
    exit 0
fi

# Validate Zabbix server IP
if [[ -z "$ZABBIX_SERVER" || "$ZABBIX_SERVER" == "YOUR_ZABBIX_SERVER_IP" ]]; then
    error "Zabbix server IP is required!"
    echo ""
    warning "Please provide Zabbix server IP as second argument or set ZABBIX_SERVER environment variable"
    echo "Example: $0 hosts 192.168.1.100"
    echo ""
    show_usage
    exit 1
fi

# Validate IP address format
if ! [[ $ZABBIX_SERVER =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "Invalid IP address format: $ZABBIX_SERVER"
    exit 1
fi

# Set paths
INVENTORY_PATH="$COMMON_DIR/inventory/$INVENTORY_NAME"
SSH_KEY="$COMMON_DIR/ssh/id_rsa"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/zabbix_install_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Logging function
log_and_echo() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check if Ansible is installed
    if ! command -v ansible >/dev/null 2>&1; then
        error "Ansible is not installed"
        echo "Please install Ansible first:"
        echo "  Ubuntu/Debian: sudo apt install ansible"
        echo "  RHEL/CentOS: sudo yum install ansible"
        exit 1
    fi
    
    # Check if ansible-playbook is available
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        error "ansible-playbook is not available"
        exit 1
    fi
    
    success "All dependencies found"
}

# Check SSH key
check_ssh_key() {
    log "Checking SSH key..."
    
    if [[ ! -f "$SSH_KEY" ]]; then
        error "SSH key not found: $SSH_KEY"
        echo "Please run the preparation script first:"
        echo "  ./run_01_prepare.sh $INVENTORY_NAME"
        exit 1
    fi
    
    chmod 600 "$SSH_KEY"
    success "SSH key found and permissions set"
}

# Check inventory
check_inventory() {
    log "Checking inventory file..."
    
    if [[ ! -f "$INVENTORY_PATH" ]]; then
        error "Inventory file not found: $INVENTORY_PATH"
        echo "Available inventories:"
        ls -la "$COMMON_DIR/inventory/" 2>/dev/null || echo "  No inventory files found"
        echo ""
        echo "To create inventory, run:"
        echo "  cd ../../ && ./generate_hosts.sh your_servers.csv"
        exit 1
    fi
    
    # Count servers
    SERVER_COUNT=$(grep -E '^\s*[a-zA-Z0-9]' "$INVENTORY_PATH" | grep -v '^\[' | wc -l)
    if [[ $SERVER_COUNT -eq 0 ]]; then
        error "No servers found in inventory: $INVENTORY_PATH"
        exit 1
    fi
    
    success "Inventory file found with $SERVER_COUNT servers"
}

# Test connectivity (disabled by default for faster execution)
# test_connectivity() {
#     log "Testing SSH connectivity to servers..."
#     
#     export ANSIBLE_HOST_KEY_CHECKING=False
#     export ANSIBLE_SSH_RETRIES=2
#     export ANSIBLE_TIMEOUT=10
#     
#     if ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" -m ping --one-line; then
#         success "All servers are reachable"
#     else
#         warning "Some servers may not be reachable"
#         echo ""
#         read -p "Continue anyway? (y/N): " -n 1 -r
#         echo
#         if [[ ! $REPLY =~ ^[Yy]$ ]]; then
#             error "Installation cancelled"
#             exit 1
#         fi
#     fi
# }

# Main installation function
install_zabbix_monitoring() {
    log "Starting Zabbix monitoring installation..."
    log "Zabbix server: $ZABBIX_SERVER"
    log "Inventory: $INVENTORY_NAME ($SERVER_COUNT servers)"
    log "This process may take 10-20 minutes depending on server count and network speed"
    
    # Set environment variables
    export ANSIBLE_PRIVATE_KEY_FILE="$SSH_KEY"
    export ANSIBLE_CONFIG="$COMMON_DIR/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=30"
    export ANSIBLE_TIMEOUT=60

    # Build ansible command
    local ansible_cmd="ansible-playbook 05_install_zabbix_monitoring.yml"
    ansible_cmd="$ansible_cmd -i $INVENTORY_PATH"
    ansible_cmd="$ansible_cmd --private-key=$SSH_KEY"
    ansible_cmd="$ansible_cmd --extra-vars zabbix_server_ip=$ZABBIX_SERVER"
    ansible_cmd="$ansible_cmd --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30'"
    
    # Add verbose flag if VERBOSE env var is set
    if [[ "${VERBOSE:-}" = "1" ]]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    log "Running Ansible playbook..."
    log "Command: $ansible_cmd"
    
    # Execute with logging
    if eval "$ansible_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        success "=== Zabbix monitoring installation completed successfully! ==="
    else
        error "=== Zabbix monitoring installation failed! ==="
        echo "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Post-installation verification
verify_installation() {
    log "Verifying Zabbix installation..."
    
    # Check if Zabbix agents are running
    log "Checking Zabbix agent status on all servers..."
    ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
        -m shell -a "systemctl is-active zabbix-agent2" --one-line 2>/dev/null || warning "Some agents may not be running"
    
    # Test UserParameters
    log "Testing UserParameters on a sample server..."
    ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
        -m shell -a "zabbix_agent2 -t aztec.service.status" --one-line 2>/dev/null || warning "UserParameter test failed on some servers"
    
    success "Installation verification completed"
}

# Show summary and next steps
show_summary() {
    log "=== Installation Summary ==="
    
    echo ""
    success "🎉 Zabbix monitoring installation completed!"
    echo ""
    
    info "📊 Configuration Summary:"
    echo "  • Zabbix Server: $ZABBIX_SERVER"
    echo "  • Servers monitored: $SERVER_COUNT"
    echo "  • Inventory: $INVENTORY_NAME"
    echo "  • Agent version: 6.4"
    echo ""
    
    info "📋 Next Steps:"
    echo "  1. 🖥️  Import Zabbix template:"
    echo "     - Open Zabbix Web UI"
    echo "     - Go to Configuration → Templates"
    echo "     - Import: aztec_zabbix_template.xml"
    echo ""
    echo "  2. 🔗 Add hosts to Zabbix:"
    echo "     - Go to Configuration → Hosts"
    echo "     - Add each server IP with 'Template Aztec Node Monitoring'"
    echo "     - Or use auto-registration with HostMetadata: aztec-node"
    echo ""
    echo "  3. ✅ Verify monitoring:"
    echo "     - Check Latest Data for Aztec metrics"
    echo "     - Verify triggers are working"
    echo "     - Test alerts"
    echo ""
    
    info "🔧 Useful Commands:"
    echo "  • Check agent status: systemctl status zabbix-agent2"
    echo "  • View agent logs: tail -f /var/log/zabbix/zabbix_agent2.log"
    echo "  • Test UserParameters: zabbix_agent2 -t aztec.service.status"
    echo "  • Manual check: /usr/local/bin/aztec_monitor.sh service_status"
    echo ""
    
    info "📄 Log file: $LOG_FILE"
    echo ""
    
    warning "⚠️  Don't forget to:"
    echo "  • Configure firewall rules for port 10050 if needed"
    echo "  • Set up alerts and notifications in Zabbix"
    echo "  • Test monitoring during maintenance windows"
}

# Main execution
main() {
    log "=== Zabbix Monitoring Installation for Aztec Nodes ==="
    echo ""
    
    # Validate arguments and environment
    check_dependencies
    check_ssh_key  
    check_inventory
    
    # Show configuration
    info "Configuration:"
    echo "  Zabbix Server: $ZABBIX_SERVER"
    echo "  Inventory: $INVENTORY_NAME ($SERVER_COUNT servers)"
    echo "  SSH Key: $SSH_KEY"
    echo "  Log File: $LOG_FILE"
    echo ""
    
    # Confirm installation
    warning "This will install Zabbix Agent 2 on $SERVER_COUNT servers"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user"
        exit 0
    fi
    
    # Execute installation
    install_zabbix_monitoring
    verify_installation
    show_summary
    
    success "=== All done! Happy monitoring! 🚀 ==="
}

# Trap for cleanup
cleanup() {
    if [[ $? -ne 0 ]]; then
        error "Script failed. Check log file: $LOG_FILE"
        echo ""
        error "Common issues:"
        echo "  • SSH connectivity problems"
        echo "  • Zabbix repository download failures"
        echo "  • Permission issues"
        echo "  • Network connectivity to Zabbix server"
    fi
}

trap cleanup EXIT

# Run main function
main "$@" 
