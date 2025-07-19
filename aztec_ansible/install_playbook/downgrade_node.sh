#!/bin/bash

# Script to downgrade Aztec nodes to version 0.87.9
# Usage: ./downgrade_node.sh [hosts_file]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$SCRIPT_DIR/../common"
DEFAULT_INVENTORY_FILE="$COMMON_DIR/inventory/hosts"
PLAYBOOK_FILE="$SCRIPT_DIR/downgrade_node.yml"

# Use provided hosts file or default
if [ -n "$1" ]; then
    INVENTORY_FILE="$1"
    echo "Using provided hosts file: $INVENTORY_FILE"
else
    INVENTORY_FILE="$DEFAULT_INVENTORY_FILE"
    echo "Using default hosts file: $INVENTORY_FILE"
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file not found at $INVENTORY_FILE"
    exit 1
fi

# Check if playbook file exists
if [ ! -f "$PLAYBOOK_FILE" ]; then
    echo "Error: Playbook file not found at $PLAYBOOK_FILE"
    exit 1
fi

echo "Starting Aztec node downgrade to version 0.87.9..."

# Run the ansible playbook
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE"

echo "Downgrade process completed." 
