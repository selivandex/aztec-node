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
LOG_FILE="${LOGS_DIR}/proof_collection_$(date +%Y%m%d_%H%M%S).log"
RESULTS_FILE="$(pwd)/proof_results.csv"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting Aztec proof collection process"
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

# Check inventory exists
check_inventory() {
    log "Checking inventory file..."
    
    if [ ! -f "${COMMON_DIR}/inventory/hosts" ]; then
        error "Inventory file not found: ${COMMON_DIR}/inventory/hosts"
        echo ""
        error "It looks like servers have not been prepared yet."
        error "Please run the preparation stage first:"
        echo ""
        error "  cd ../install_playbook"
        error "  ./run_01_prepare.sh path/to/your/servers.csv"
        echo ""
        error "Or if you have a CSV file with servers, you can create inventory manually:"
        error "  cd ${COMMON_DIR}"
        error "  python3 csv_to_inventory.py path/to/your/servers.csv"
        exit 1
    fi
    
    # Count servers
    local server_count=$(grep -c "ansible_host" "${COMMON_DIR}/inventory/hosts" || echo 0)
    if [ "$server_count" -eq 0 ]; then
        error "No servers found in inventory file"
        error "The inventory file exists but appears to be empty or invalid"
        exit 1
    fi
    
    success "Found inventory file with $server_count servers"
    
    # Show first few servers for confirmation
    log "Servers in inventory:"
    grep "ansible_host" "${COMMON_DIR}/inventory/hosts" | head -3 | while read line; do
        local hostname=$(echo "$line" | awk '{print $1}')
        local ip=$(echo "$line" | grep -o 'ansible_host=[^ ]*' | cut -d'=' -f2)
        log "  - $hostname ($ip)"
    done
    
    if [ "$server_count" -gt 3 ]; then
        log "  ... and $((server_count - 3)) more servers"
    fi
}

# Test connectivity to servers
test_connectivity() {
    # Only run connectivity test in verbose mode
    if [ "${VERBOSE:-}" = "1" ]; then
        log "Testing connectivity to servers (verbose mode)..."
        
        if ! ansible all -i "${COMMON_DIR}/inventory/hosts" -m ping --one-line &>/dev/null; then
            warning "Some servers may not be reachable"
            log "Running connectivity test with details..."
            ansible all -i "${COMMON_DIR}/inventory/hosts" -m ping --one-line || true
        else
            success "All servers are reachable"
        fi
    else
        log "Skipping connectivity test (Ansible will handle connections)"
    fi
}

# Backup previous results
backup_previous_results() {
    if [ -f "$RESULTS_FILE" ]; then
        local backup_file="${RESULTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$RESULTS_FILE" "$backup_file"
        log "Previous results backed up to: $backup_file"
    fi
}

# Analyze results
analyze_results() {
    if [ ! -f "$RESULTS_FILE" ]; then
        error "Results file not found: $RESULTS_FILE"
        return 1
    fi
    
    log "Analyzing results..."
    
    local total_lines=$(wc -l < "$RESULTS_FILE")
    local total_servers=$((total_lines - 1))  # Subtract header
    
    if [ "$total_servers" -eq 0 ]; then
        warning "No results collected"
        return 1
    fi
    
    local successful=$(grep -c ",SUCCESS," "$RESULTS_FILE" || echo 0)
    local errors=$(grep -c ",ERROR\|FAILED," "$RESULTS_FILE" || echo 0)
    local success_rate=$((successful * 100 / total_servers))
    
    echo ""
    echo "======================================"
    echo "       PROOF COLLECTION SUMMARY      "
    echo "======================================"
    echo "Total servers processed: $total_servers"
    echo "Successful collections:  $successful"
    echo "Failed collections:      $errors"
    echo "Success rate:           $success_rate%"
    echo "Results file:           $RESULTS_FILE"
    echo "Log file:               $LOG_FILE"
    echo "======================================"
    echo ""
    
    if [ "$successful" -gt 0 ]; then
        echo "Sample successful results:"
        grep ",SUCCESS," "$RESULTS_FILE" | head -3 | while IFS=',' read -r ip address block proof status timestamp; do
            echo "  $ip -> Block: $block, Proof: ${proof:0:20}..."
        done
        echo ""
    fi
    
    if [ "$errors" -gt 0 ]; then
        echo "Failed servers:"
        grep ",ERROR\|FAILED," "$RESULTS_FILE" | while IFS=',' read -r ip address block proof status timestamp; do
            echo "  $ip -> $status"
        done
        echo ""
    fi
    
    # Create summary file
    local summary_file="${LOGS_DIR}/proof_summary_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "Aztec Proof Collection Summary"
        echo "Generated: $(date)"
        echo "Total servers: $total_servers"
        echo "Successful: $successful"
        echo "Failed: $errors"
        echo "Success rate: $success_rate%"
        echo ""
        echo "Results file: $RESULTS_FILE"
        echo "Log file: $LOG_FILE"
    } > "$summary_file"
    
    log "Summary saved to: $summary_file"
}

# Main function
main() {
    log "=== Aztec Proof Collection Script ==="
    
    # Check if help is requested
    if [ "$#" -eq 1 ] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Collect Aztec proofs from all servers in the inventory."
        echo "No arguments required - uses existing inventory file."
        echo ""
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  VERBOSE=1      Enable verbose Ansible output"
        echo "  TIMEOUT=300    Set proof collection timeout (seconds)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Collect proofs from all servers"
        echo "  VERBOSE=1 $0          # Collect with verbose output"
        echo "  TIMEOUT=600 $0        # Collect with 10-minute timeout"
        echo ""
        echo "Prerequisites:"
        echo "  1. Servers must be prepared (run ../install_playbook/run_01_prepare.sh first)"
        echo "  2. SSH key must be available at ../common/ssh/id_rsa"
        echo "  3. Inventory file must exist at ../common/inventory/hosts"
        exit 0
    fi
    
    # Check for unexpected arguments
    if [ "$#" -gt 0 ]; then
        error "This script no longer requires a CSV file argument."
        error "It uses the existing inventory file from server preparation."
        echo ""
        error "Usage: $0"
        echo ""
        error "If you need to add servers, please:"
        error "1. Update your CSV file with server information"
        error "2. Run: cd ../install_playbook && ./run_01_prepare.sh path/to/servers.csv"
        error "3. Then run this script again: $0"
        exit 1
    fi
    
    # Run checks
    check_dependencies
    check_ssh_key
    check_inventory
    
    # Test connectivity (only in verbose mode - Ansible handles connections automatically)
    test_connectivity
    
    # Backup previous results
    backup_previous_results
    
    # Run Ansible playbook
    log "Starting proof collection..."
    log "This process may take several minutes depending on server count and response times"
    
    # Set SSH key path
    export ANSIBLE_PRIVATE_KEY_FILE="${COMMON_DIR}/ssh/id_rsa"
    export ANSIBLE_CONFIG="${COMMON_DIR}/ansible.cfg"
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10"

    local ansible_cmd="ansible-playbook get_proof.yml -i ${COMMON_DIR}/inventory/hosts"
    
    # Add verbose flag if VERBOSE env var is set
    if [ "${VERBOSE:-}" = "1" ]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    # Set timeout if specified
    if [ "${TIMEOUT:-}" != "" ]; then
        ansible_cmd="$ansible_cmd -e proof_timeout=${TIMEOUT}"
    fi

    log "Using SSH key: ${ANSIBLE_PRIVATE_KEY_FILE}"
    log "Running: $ansible_cmd"
    
    if eval "$ansible_cmd"; then
        success "Proof collection completed!"
        analyze_results
    else
        error "Proof collection failed!"
        error "Check the log file for details: $LOG_FILE"
        
        # Try to analyze partial results
        if [ -f "$RESULTS_FILE" ]; then
            warning "Analyzing partial results..."
            analyze_results
        fi
        
        exit 1
    fi
}

# Trap for cleanup
cleanup() {
    if [ $? -ne 0 ]; then
        error "Script failed. Check log file: $LOG_FILE"
        if [ -f "$RESULTS_FILE" ]; then
            warning "Partial results may be available in: $RESULTS_FILE"
        fi
    fi
}

trap cleanup EXIT

# Run main function
main "$@" 
