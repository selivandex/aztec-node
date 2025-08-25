#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/aztec_ansible"
COMMON_DIR="${ANSIBLE_DIR}/common"
INVENTORY_DIR="${COMMON_DIR}/inventory"

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
        error "Please install them before running this script"
        exit 1
    fi
    
    success "All dependencies found"
}

# Extract name from CSV filename
get_hosts_name() {
    local csv_file="$1"
    local filename=$(basename "$csv_file" .csv)
    
    # Remove common prefixes if present
    filename=$(echo "$filename" | sed 's/^wallets_//' | sed 's/^servers_//')
    
    echo "hosts_${filename}"
}

# Create Python script for CSV to hosts conversion
create_csv_converter() {
    local converter_script="$1"
    
    cat > "$converter_script" << 'EOF'
#!/usr/bin/env python3

import csv
import os
import sys
import base64
from typing import Dict, List, Optional

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def log(message: str) -> None:
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

def error(message: str) -> None:
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}", file=sys.stderr)

def success(message: str) -> None:
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")

def parse_csv_row(row: Dict[str, str], row_num: int) -> Optional[Dict[str, str]]:
    """Parse a CSV row with flexible field mapping."""
    # Normalize keys
    normalized_row = {}
    for key, value in row.items():
        normalized_key = key.strip().upper()
        normalized_row[normalized_key] = value.strip() if value else ''
    
    # Extract IP address with fallbacks
    ip = (normalized_row.get('IP') or 
          normalized_row.get('IP_ADDRESS') or 
          normalized_row.get('SERVER_IP') or 
          normalized_row.get('HOST') or
          normalized_row.get('ANSIBLE_HOST', ''))
    
    # Extract ethereum address with fallbacks
    address = (normalized_row.get('ADDRESS') or 
               normalized_row.get('ETH_ADDRESS') or 
               normalized_row.get('ETHEREUM_ADDRESS') or 
               normalized_row.get('WALLET_ADDRESS', ''))
    
    # Extract private key with fallbacks
    private_key = (normalized_row.get('PRIVATE_KEY') or 
                   normalized_row.get('PRIVATEKEY') or
                   normalized_row.get('PRIV_KEY') or 
                   normalized_row.get('KEY', ''))
    
    # Basic validation
    if not ip:
        error(f"Row {row_num}: IP address is missing (columns checked: IP, IP_ADDRESS, SERVER_IP, HOST, ANSIBLE_HOST)")
        return None
    
    if not address:
        error(f"Row {row_num}: Ethereum address is missing (columns checked: ADDRESS, ETH_ADDRESS, ETHEREUM_ADDRESS, WALLET_ADDRESS)")
        return None
        
    if not private_key:
        error(f"Row {row_num}: Private key is missing (columns checked: PRIVATE_KEY, PRIVATEKEY, PRIV_KEY, KEY)")
        return None
    
    return {
        'ip': ip,
        'address': address,
        'private_key': private_key
    }

def create_hosts_file(servers: List[Dict[str, str]], hosts_path: str, server_prefix: str, start_index: int) -> None:
    """Create Ansible hosts file."""
    try:
        with open(hosts_path, 'w') as hosts_file:
            hosts_file.write("[aztec_nodes]\n")
            
            for i, server in enumerate(servers, start_index):
                # Encode hex values to base64 to avoid Ansible auto-conversion
                eth_address_b64 = base64.b64encode(server['address'].encode()).decode()
                private_key_b64 = base64.b64encode(server['private_key'].encode()).decode()
                
                hosts_file.write(
                    f"{server_prefix}{i} ansible_host={server['ip']} "
                    f"ansible_ssh_user=ubuntu "
                    f"server_ip={server['ip']} "
                    f"eth_address_b64={eth_address_b64} "
                    f"validator_private_key_b64={private_key_b64}\n"
                )
                
        success(f"Hosts file created with {len(servers)} servers")
        
    except IOError as e:
        error(f"Failed to create hosts file: {e}")
        raise

def main() -> int:
    """Main function."""
    if len(sys.argv) < 3 or len(sys.argv) > 5:
        error("Usage: python3 converter.py <csv_file> <hosts_file> [server_prefix] [start_index]")
        return 1
    
    csv_file = sys.argv[1]
    hosts_file = sys.argv[2]
    server_prefix = sys.argv[3] if len(sys.argv) >= 4 else "node"
    start_index_str = sys.argv[4] if len(sys.argv) >= 5 else "1"
    
    # Validate and parse start index
    if not start_index_str.isdigit() or start_index_str.startswith('0'):
        error("Start index must be a positive integer")
        return 1
    start_index = int(start_index_str)
    
    if not os.path.exists(csv_file):
        error(f"CSV file does not exist: {csv_file}")
        return 1
    
    log(f"Processing CSV file: {csv_file}")
    
    try:
        servers = []
        with open(csv_file, 'r', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile, delimiter=",")
            
            if not reader.fieldnames:
                error("CSV file appears to be empty or invalid")
                return 1
            
            log(f"Found columns: {', '.join(reader.fieldnames)}")
            
            row_count = 0
            for row_num, row in enumerate(reader, 2):
                row_count += 1
                parsed_row = parse_csv_row(row, row_num)
                if parsed_row:
                    servers.append(parsed_row)
            
            log(f"Processed {row_count} rows from CSV")
        
        if not servers:
            error("No valid servers found in CSV file")
            return 1
        
        log(f"Found {len(servers)} valid servers")
        create_hosts_file(servers, hosts_file, server_prefix, start_index)
        
        success(f"Hosts file created: {hosts_file}")
        return 0
        
    except Exception as e:
        error(f"Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

    chmod +x "$converter_script"
}

# Main function
main() {
    log "=== Generate Hosts Script ==="
    
    # Check arguments
    if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
        error "Usage: $0 <path_to_csv> [server_prefix] [start_index]"
        error "Example: $0 wallets_alex.csv"
        error "Example: $0 wallets_alex.csv validator"
        error "Example: $0 wallets_alex.csv validator 5"
        error "Example: $0 servers_stepa.csv aztec 10"
        exit 1
    fi
    
    local CSV_FILE="$1"
    local SERVER_PREFIX="${2:-node}"
    local START_INDEX="${3:-1}"
    
    # Validate start index (must be positive integer)
    if ! [[ "$START_INDEX" =~ ^[1-9][0-9]*$ ]]; then
        error "Start index must be a positive integer"
        exit 1
    fi
    
    # Convert to absolute path if relative
    if [[ "$CSV_FILE" != /* ]]; then
        CSV_FILE="$(pwd)/$CSV_FILE"
    fi
    
    # Validate CSV file exists
    if [ ! -f "$CSV_FILE" ]; then
        error "CSV file does not exist: $CSV_FILE"
        exit 1
    fi
    
    # Check if ansible directory exists
    if [ ! -d "$ANSIBLE_DIR" ]; then
        error "Ansible directory not found: $ANSIBLE_DIR"
        error "Make sure you're running this script from the correct directory"
        exit 1
    fi
    
    # Run checks
    check_dependencies
    
    # Create inventory directory if it doesn't exist
    mkdir -p "$INVENTORY_DIR"
    
    # Generate hosts filename
    local HOSTS_NAME=$(get_hosts_name "$CSV_FILE")
    local HOSTS_FILE="${INVENTORY_DIR}/${HOSTS_NAME}"
    
    log "CSV file: $CSV_FILE"
    log "Hosts file will be: $HOSTS_FILE"
    log "Server prefix: $SERVER_PREFIX"
    log "Start index: $START_INDEX"
    
    # Create temporary converter script
    local TEMP_CONVERTER=$(mktemp)
    create_csv_converter "$TEMP_CONVERTER"
    
    # Generate hosts file
    log "Generating hosts file..."
    if python3 "$TEMP_CONVERTER" "$CSV_FILE" "$HOSTS_FILE" "$SERVER_PREFIX" "$START_INDEX"; then
        success "=== Hosts file generated successfully! ==="
        log "Generated: $HOSTS_FILE"
        
        # Show sample of created hosts file
        if [ -f "$HOSTS_FILE" ]; then
            echo ""
            log "Sample entries from generated hosts file:"
            head -5 "$HOSTS_FILE" | while IFS= read -r line; do
                echo "  $line"
            done
        fi
        
        echo ""
        success "You can now use this hosts file with Ansible playbooks"
    else
        error "=== Hosts file generation failed! ==="
        exit 1
    fi
    
    # Cleanup
    rm -f "$TEMP_CONVERTER"
}

# Trap for cleanup
cleanup() {
    if [ $? -ne 0 ]; then
        error "Script failed"
    fi
}

trap cleanup EXIT

# Run main function
main "$@" 
