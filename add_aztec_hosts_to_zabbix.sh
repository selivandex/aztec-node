#!/bin/bash

# Script to add Aztec nodes to Zabbix Server via API
# Usage: ./add_aztec_hosts_to_zabbix.sh

set -e

# Configuration
ZABBIX_SERVER="http://your-zabbix-server/zabbix"  # Change this!
ZABBIX_USER="Admin"                               # Change this!
ZABBIX_PASSWORD="zabbix"                         # Change this!
TEMPLATE_NAME="Template Aztec Node Monitoring"
HOSTGROUP_NAME="Aztec Nodes"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to make Zabbix API calls
zabbix_api_call() {
    local method="$1"
    local params="$2"
    
    curl -s -X POST "${ZABBIX_SERVER}/api_jsonrpc.php" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"${method}\",
            \"params\": ${params},
            \"auth\": \"${AUTH_TOKEN}\",
            \"id\": 1
        }"
}

# Function to authenticate and get token
authenticate() {
    echo -e "${YELLOW}Authenticating with Zabbix Server...${NC}"
    
    local response=$(curl -s -X POST "${ZABBIX_SERVER}/api_jsonrpc.php" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"user.login\",
            \"params\": {
                \"username\": \"${ZABBIX_USER}\",
                \"password\": \"${ZABBIX_PASSWORD}\"
            },
            \"id\": 1
        }")
    
    AUTH_TOKEN=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['result'])" 2>/dev/null)
    
    if [ -z "$AUTH_TOKEN" ]; then
        echo -e "${RED}Authentication failed! Check your credentials.${NC}"
        echo "Response: $response"
        exit 1
    fi
    
    echo -e "${GREEN}Successfully authenticated!${NC}"
}

# Function to get template ID
get_template_id() {
    echo -e "${YELLOW}Getting template ID...${NC}"
    
    local response=$(zabbix_api_call "template.get" "{
        \"output\": [\"templateid\"],
        \"filter\": {
            \"host\": [\"${TEMPLATE_NAME}\"]
        }
    }")
    
    TEMPLATE_ID=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['result'][0]['templateid'])" 2>/dev/null)
    
    if [ -z "$TEMPLATE_ID" ]; then
        echo -e "${RED}Template '${TEMPLATE_NAME}' not found! Import it first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Template ID: ${TEMPLATE_ID}${NC}"
}

# Function to get or create hostgroup
get_hostgroup_id() {
    echo -e "${YELLOW}Getting hostgroup ID...${NC}"
    
    local response=$(zabbix_api_call "hostgroup.get" "{
        \"output\": [\"groupid\"],
        \"filter\": {
            \"name\": [\"${HOSTGROUP_NAME}\"]
        }
    }")
    
    HOSTGROUP_ID=$(echo "$response" | python3 -c "import sys, json; result = json.load(sys.stdin)['result']; print(result[0]['groupid'] if result else '')" 2>/dev/null)
    
    if [ -z "$HOSTGROUP_ID" ]; then
        echo -e "${YELLOW}Creating hostgroup '${HOSTGROUP_NAME}'...${NC}"
        
        local create_response=$(zabbix_api_call "hostgroup.create" "{
            \"name\": \"${HOSTGROUP_NAME}\"
        }")
        
        HOSTGROUP_ID=$(echo "$create_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['groupids'][0])" 2>/dev/null)
    fi
    
    echo -e "${GREEN}Hostgroup ID: ${HOSTGROUP_ID}${NC}"
}

# Function to add host to Zabbix
add_host() {
    local hostname="$1"
    local ip_address="$2"
    
    echo -e "${YELLOW}Adding host: ${hostname} (${ip_address})...${NC}"
    
    # Check if host already exists
    local existing=$(zabbix_api_call "host.get" "{
        \"output\": [\"hostid\"],
        \"filter\": {
            \"host\": [\"${hostname}\"]
        }
    }")
    
    local existing_id=$(echo "$existing" | python3 -c "import sys, json; result = json.load(sys.stdin)['result']; print(result[0]['hostid'] if result else '')" 2>/dev/null)
    
    if [ -n "$existing_id" ]; then
        echo -e "${YELLOW}Host ${hostname} already exists (ID: ${existing_id})${NC}"
        return
    fi
    
    # Create host
    local response=$(zabbix_api_call "host.create" "{
        \"host\": \"${hostname}\",
        \"name\": \"${hostname}\",
        \"interfaces\": [
            {
                \"type\": 1,
                \"main\": 1,
                \"useip\": 1,
                \"ip\": \"${ip_address}\",
                \"dns\": \"\",
                \"port\": \"10050\"
            }
        ],
        \"groups\": [
            {
                \"groupid\": \"${HOSTGROUP_ID}\"
            }
        ],
        \"templates\": [
            {
                \"templateid\": \"${TEMPLATE_ID}\"
            }
        ]
    }")
    
    local host_id=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['hostids'][0])" 2>/dev/null)
    
    if [ -n "$host_id" ]; then
        echo -e "${GREEN}✓ Host ${hostname} added successfully (ID: ${host_id})${NC}"
    else
        echo -e "${RED}✗ Failed to add host ${hostname}${NC}"
        echo "Response: $response"
    fi
}

# Function to read hosts from inventory file
read_hosts_from_inventory() {
    local inventory_file="$1"
    
    if [ ! -f "$inventory_file" ]; then
        echo -e "${RED}Inventory file not found: ${inventory_file}${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Reading hosts from inventory: ${inventory_file}${NC}"
    
    # Parse Ansible inventory format
    grep -E "^[0-9]" "$inventory_file" | while read line; do
        hostname=$(echo "$line" | awk '{print $1}')
        ip_address=$(echo "$line" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2)
        
        if [ -n "$hostname" ] && [ -n "$ip_address" ]; then
            add_host "$hostname" "$ip_address"
        fi
    done
}

# Main execution
main() {
    echo -e "${GREEN}=== Aztec Nodes Zabbix Auto-Add Script ===${NC}"
    
    # Check if inventory file is provided
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <inventory_file>"
        echo "Example: $0 aztec_ansible/common/inventory/hosts"
        exit 1
    fi
    
    local inventory_file="$1"
    
    # Validate dependencies
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}python3 is required but not installed${NC}"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl is required but not installed${NC}"
        exit 1
    fi
    
    # Check Zabbix server URL
    if [[ "$ZABBIX_SERVER" == *"your-zabbix-server"* ]]; then
        echo -e "${RED}Please configure ZABBIX_SERVER variable in the script!${NC}"
        exit 1
    fi
    
    # Execute steps
    authenticate
    get_template_id
    get_hostgroup_id
    read_hosts_from_inventory "$inventory_file"
    
    echo -e "${GREEN}=== Finished adding hosts to Zabbix ===${NC}"
}

# Run main function
main "$@" 
