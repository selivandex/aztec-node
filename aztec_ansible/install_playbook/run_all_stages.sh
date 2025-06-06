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
LOGS_DIR="../logs"
LOG_FILE="${LOGS_DIR}/complete_install_$(date +%Y%m%d_%H%M%S).log"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting complete Aztec installation process"
log "Log file: $LOG_FILE"

# Main function
main() {
    log "=== Complete Aztec Installation Script ==="
    
    # Check arguments
    if [ "$#" -ne 1 ]; then
        error "Usage: $0 <inventory_name>"
        error "Example: $0 hosts_alex"
        echo ""
        echo "This script will run all installation stages:"
        echo "  1. Server preparation and Docker installation"
        echo "  2. Aztec installation"
        echo ""
        echo "Make sure to generate inventory first:"
        echo "  cd ../../ && ./generate_hosts.sh wallets_alex.csv"
        echo ""
        echo "If you encounter Docker sources conflicts, run first:"
        echo "  ./run_00_fix_docker_sources.sh"
        exit 1
    fi
    
    local INVENTORY_NAME="$1"
    
    log "Starting complete installation process for inventory: $INVENTORY_NAME"
    echo ""
    
    # Stage 1: Preparation and Docker Installation
    log "=== STAGE 1/2: Server Preparation and Docker Installation ==="
    if ! ./run_01_prepare.sh "$INVENTORY_NAME"; then
        error "Stage 1 failed! Stopping installation."
        exit 1
    fi
    success "Stage 1 completed successfully!"
    echo ""
    
    # Stage 2: Aztec Installation
    log "=== STAGE 2/2: Aztec Installation ==="
    if ! ./run_03_install_aztec.sh "$INVENTORY_NAME"; then
        error "Stage 2 failed! Stopping installation."
        exit 1
    fi
    success "Stage 2 completed successfully!"
    echo ""
    
    # Final summary
    success "=== ALL STAGES COMPLETED SUCCESSFULLY! ==="
    log "Complete installation finished at $(date)"
    log "Full log available at: $LOG_FILE"
    echo ""
    echo "Installation Summary:"
    echo "✅ Server preparation - completed"
    echo "✅ Docker installation - completed"
    echo "✅ Aztec installation - completed"
    echo ""
    echo "Next steps:"
    echo "1. Check service status: cd ../get_proof_playbook && ./run_get_proof.sh $INVENTORY_NAME"
    echo "2. Monitor logs on servers: /var/log/aztec_*.log"
    echo "3. View local logs: ls ../logs/"
    echo ""
}

# Trap for cleanup
cleanup() {
    if [ $? -ne 0 ]; then
        error "Installation failed at stage. Check log file: $LOG_FILE"
        echo ""
        echo "You can resume from failed stage by running individual scripts:"
        echo "  ./run_00_fix_docker_sources.sh     # Fix Docker sources conflicts (if needed)"
        echo "  ./run_01_prepare.sh <inventory>     # Server preparation and Docker installation"
        echo "  ./run_03_install_aztec.sh <inventory> # Aztec installation"
        echo ""
        echo "All logs are available in: ../logs/"
    fi
}

trap cleanup EXIT

# Run main function
main "$@" 
