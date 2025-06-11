#!/bin/bash

# Wrapper script to add Aztec hosts to Zabbix using Ansible
# Usage: ZABBIX_SERVER=http://zabbix ZABBIX_USER=admin ZABBIX_PASSWORD=pass ./run_06_add_host_to_zabbix.sh [inventory_file] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_INVENTORY="../common/inventory/hosts"
PLAYBOOK_PATH="./add_hosts_to_zabbix.yml"
SCRIPT_PATH="./add_aztec_hosts_to_zabbix.sh"

# Function to display usage
show_usage() {
    cat << EOF
${GREEN}=== Aztec Zabbix Host Addition Script ===${NC}

${YELLOW}Usage:${NC}
    ZABBIX_SERVER=<url> ZABBIX_USER=<user> ZABBIX_PASSWORD=<pass> $0 [inventory_file] [options]

${YELLOW}Environment Variables (Required):${NC}
    ZABBIX_SERVER     - Zabbix server URL (e.g., http://your-zabbix-server/zabbix)
    ZABBIX_USER       - Zabbix username (e.g., Admin)
    ZABBIX_PASSWORD   - Zabbix password

${YELLOW}Arguments:${NC}
    inventory_file    - Path to Ansible inventory file (default: ${DEFAULT_INVENTORY})

${YELLOW}Options:${NC}
    -h, --help        - Show this help message
    -v, --verbose     - Enable verbose output
    -s, --script-path - Path to add_aztec_hosts_to_zabbix.sh script (default: ${SCRIPT_PATH})
    --check           - Run Ansible in check mode (dry run)
    --tags            - Run only tasks with specified tags
    --skip-tags       - Skip tasks with specified tags

${YELLOW}Examples:${NC}
    # Basic usage with environment variables
    ZABBIX_SERVER=http://zabbix.example.com/zabbix \\
    ZABBIX_USER=Admin \\
    ZABBIX_PASSWORD=secret123 \\
    $0

    # Using custom inventory file
    ZABBIX_SERVER=http://zabbix.example.com/zabbix \\
    ZABBIX_USER=Admin \\
    ZABBIX_PASSWORD=secret123 \\
    $0 /path/to/custom/inventory

    # Verbose mode with custom script path
    ZABBIX_SERVER=http://zabbix.example.com/zabbix \\
    ZABBIX_USER=Admin \\
    ZABBIX_PASSWORD=secret123 \\
    $0 --verbose --script-path ./custom_add_hosts.sh

    # Dry run (check mode)
    ZABBIX_SERVER=http://zabbix.example.com/zabbix \\
    ZABBIX_USER=Admin \\
    ZABBIX_PASSWORD=secret123 \\
    $0 --check

EOF
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check if ansible-playbook is installed
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}ERROR: ansible-playbook is not installed${NC}"
        echo "Please install Ansible: https://docs.ansible.com/ansible/latest/installation_guide/index.html"
        exit 1
    fi
    
    # Check if required environment variables are set
    if [[ -z "$ZABBIX_SERVER" ]]; then
        echo -e "${RED}ERROR: ZABBIX_SERVER environment variable is not set${NC}"
        show_usage
        exit 1
    fi
    
    if [[ -z "$ZABBIX_USER" ]]; then
        echo -e "${RED}ERROR: ZABBIX_USER environment variable is not set${NC}"
        show_usage
        exit 1
    fi
    
    if [[ -z "$ZABBIX_PASSWORD" ]]; then
        echo -e "${RED}ERROR: ZABBIX_PASSWORD environment variable is not set${NC}"
        show_usage
        exit 1
    fi
    
    # Check if playbook exists
    if [[ ! -f "$PLAYBOOK_PATH" ]]; then
        echo -e "${RED}ERROR: Playbook not found: $PLAYBOOK_PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Parse command line arguments
INVENTORY_FILE=""
ANSIBLE_ARGS=""
VERBOSE=""
SCRIPT_PATH_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -s|--script-path)
            SCRIPT_PATH_OVERRIDE="$2"
            shift 2
            ;;
        --check)
            ANSIBLE_ARGS="$ANSIBLE_ARGS --check"
            shift
            ;;
        --tags)
            ANSIBLE_ARGS="$ANSIBLE_ARGS --tags $2"
            shift 2
            ;;
        --skip-tags)
            ANSIBLE_ARGS="$ANSIBLE_ARGS --skip-tags $2"
            shift 2
            ;;
        -*)
            echo -e "${RED}ERROR: Unknown option $1${NC}"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$INVENTORY_FILE" ]]; then
                INVENTORY_FILE="$1"
            else
                echo -e "${RED}ERROR: Multiple positional arguments provided${NC}"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default inventory if not provided
if [[ -z "$INVENTORY_FILE" ]]; then
    INVENTORY_FILE="$DEFAULT_INVENTORY"
fi

# Override script path if provided
if [[ -n "$SCRIPT_PATH_OVERRIDE" ]]; then
    SCRIPT_PATH="$SCRIPT_PATH_OVERRIDE"
fi

# Main execution
main() {
    echo -e "${GREEN}=== Starting Aztec Zabbix Host Addition ===${NC}"
    
    check_prerequisites
    
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  Zabbix Server: ${ZABBIX_SERVER}"
    echo -e "  Zabbix User: ${ZABBIX_USER}"
    echo -e "  Inventory File: ${INVENTORY_FILE}"
    echo -e "  Script Path: ${SCRIPT_PATH}"
    echo -e "  Playbook: ${PLAYBOOK_PATH}"
    
    if [[ -n "$ANSIBLE_ARGS" ]]; then
        echo -e "  Ansible Args: ${ANSIBLE_ARGS}"
    fi
    
    echo ""
    
    # Export environment variables for ansible
    export ZABBIX_SERVER
    export ZABBIX_USER
    export ZABBIX_PASSWORD
    
    # Build ansible-playbook command
    ANSIBLE_CMD="ansible-playbook $VERBOSE $ANSIBLE_ARGS"
    ANSIBLE_CMD="$ANSIBLE_CMD -e inventory_file_path=$INVENTORY_FILE"
    ANSIBLE_CMD="$ANSIBLE_CMD -e script_file_path=$SCRIPT_PATH"
    ANSIBLE_CMD="$ANSIBLE_CMD $PLAYBOOK_PATH"
    
    echo -e "${BLUE}Running Ansible playbook...${NC}"
    echo -e "${YELLOW}Command: $ANSIBLE_CMD${NC}"
    echo ""
    
    # Execute ansible-playbook
    if eval "$ANSIBLE_CMD"; then
        echo ""
        echo -e "${GREEN}=== Aztec hosts successfully added to Zabbix! ===${NC}"
    else
        echo ""
        echo -e "${RED}=== Failed to add Aztec hosts to Zabbix ===${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 
