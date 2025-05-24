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
    NC = '\033[0m'  # No Color

def log(message: str) -> None:
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

def error(message: str) -> None:
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}", file=sys.stderr)

def success(message: str) -> None:
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")

def parse_csv_row(row: Dict[str, str], row_num: int) -> Optional[Dict[str, str]]:
    """Parse a CSV row."""
    # Normalize keys
    normalized_row = {}
    for key, value in row.items():
        normalized_key = key.strip().upper()
        normalized_row[normalized_key] = value.strip() if value else ''
    
    # Extract values with fallbacks for common variations
    ip = (normalized_row.get('IP') or 
          normalized_row.get('IP_ADDRESS') or 
          normalized_row.get('SERVER_IP') or 
          normalized_row.get('HOST', ''))
    
    address = (normalized_row.get('ADDRESS') or 
               normalized_row.get('ETH_ADDRESS') or 
               normalized_row.get('ETHEREUM_ADDRESS') or 
               normalized_row.get('WALLET_ADDRESS', ''))
    
    private_key = (normalized_row.get('PRIVATE_KEY') or 
                   normalized_row.get('PRIV_KEY') or 
                   normalized_row.get('KEY', ''))
    
    # Basic check for required fields
    if not ip:
        error(f"Row {row_num}: IP address is missing")
        return None
    
    return {
        'ip': ip,
        'address': address,
        'private_key': private_key
    }

def create_inventory_file(servers: List[Dict[str, str]], inventory_path: str) -> None:
    """Create Ansible inventory file."""
    try:
        with open(inventory_path, 'w') as inventory_file:
            inventory_file.write("[aztec_nodes]\n")
            
            for i, server in enumerate(servers, 1):
                # Encode hex values to base64 to avoid Ansible auto-conversion
                eth_address_b64 = base64.b64encode(server['address'].encode()).decode()
                private_key_b64 = base64.b64encode(server['private_key'].encode()).decode()
                
                inventory_file.write(
                    f"node{i} ansible_host={server['ip']} "
                    f"ansible_ssh_user=ubuntu "
                    f"server_ip={server['ip']} "
                    f"eth_address_b64={eth_address_b64} "
                    f"validator_private_key_b64={private_key_b64}\n"
                )
                
        success(f"Inventory file created with {len(servers)} servers")
        
    except IOError as e:
        error(f"Failed to create inventory file: {e}")
        raise

def create_vars_file(vars_path: str) -> None:
    """Create Ansible variables file."""
    try:
        with open(vars_path, 'w') as vars_file:
            vars_file.write("---\n")
            vars_file.write("# Ansible connection settings\n")
            vars_file.write("ansible_ssh_user: ubuntu\n")
            vars_file.write("ansible_python_interpreter: /usr/bin/python3\n")
            vars_file.write("ansible_ssh_common_args: '-o StrictHostKeyChecking=no'\n")
            vars_file.write("\n")
            vars_file.write("# Common L1 RPC settings for all servers\n")
            vars_file.write("l1_rpc_url: 'http://65.109.116.87:8545'\n")
            vars_file.write("l1_consensus_url: 'http://65.109.116.87:5052'\n")
            vars_file.write("\n")
            vars_file.write("# Timeouts and retries\n")
            vars_file.write("ansible_timeout: 300\n")
            vars_file.write("install_timeout: 1800\n")
            
        success("Variables file created")
        
    except IOError as e:
        error(f"Failed to create variables file: {e}")
        raise

def main() -> int:
    """Main function."""
    log("Starting CSV to Ansible inventory conversion")
    
    # Check arguments
    if len(sys.argv) != 2:
        error("Usage: python3 csv_to_inventory.py <path_to_csv>")
        error("Example: python3 csv_to_inventory.py servers.csv")
        return 1
    
    csv_file = sys.argv[1]
    
    # Check if CSV file exists
    if not os.path.exists(csv_file):
        error(f"CSV file does not exist: {csv_file}")
        return 1
    
    log(f"Processing CSV file: {csv_file}")
    
    try:
        # Create output directories
        os.makedirs('inventory', exist_ok=True)
        os.makedirs('vars', exist_ok=True)
        
        # Read CSV file
        servers = []
        with open(csv_file, 'r', encoding='utf-8') as csvfile:
            try:
                reader = csv.DictReader(csvfile, delimiter=",")
                
                # Check if file has data
                if not reader.fieldnames:
                    error("CSV file appears to be empty or invalid")
                    return 1
                
                log(f"Found columns: {', '.join(reader.fieldnames)}")
                
                # Process rows
                row_count = 0
                for row_num, row in enumerate(reader, 2):  # Start from 2 (after header)
                    row_count += 1
                    
                    parsed_row = parse_csv_row(row, row_num)
                    if parsed_row:
                        servers.append(parsed_row)
                
                log(f"Processed {row_count} rows from CSV")
                
            except csv.Error as e:
                error(f"CSV parsing error: {e}")
                return 1
        
        if not servers:
            error("No valid servers found in CSV file")
            return 1
        
        log(f"Found {len(servers)} valid servers")
        
        # Create output files
        inventory_path = 'inventory/hosts'
        vars_path = 'vars/server_vars.yml'
        
        create_inventory_file(servers, inventory_path)
        create_vars_file(vars_path)
        
        # Display summary
        print()
        success("=== Conversion completed successfully! ===")
        log(f"Inventory file: {inventory_path}")
        log(f"Variables file: {vars_path}")
        log(f"Total servers: {len(servers)}")
        
        # Show sample of created inventory
        print("\nSample inventory entries:")
        with open(inventory_path, 'r') as f:
            lines = f.readlines()
            for line in lines[:min(4, len(lines))]:  # Show first 3 servers + header
                print(f"  {line.strip()}")
        
        print("\nYou can now run the Ansible playbook!")
        
        return 0
        
    except Exception as e:
        error(f"Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 
