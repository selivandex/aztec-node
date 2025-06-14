#!/bin/bash

# Script to add Aztec nodes to Zabbix Server via API
# Usage: ./add_aztec_hosts_to_zabbix.sh

# Note: Temporarily disabled set -e to prevent script termination on individual host failures
# set -e

# Configuration - can be overridden by environment variables
ZABBIX_SERVER="${ZABBIX_SERVER:-http://your-zabbix-server/zabbix}"
ZABBIX_API_TOKEN="${ZABBIX_API_TOKEN:-}"
# Legacy support for username/password authentication
ZABBIX_USER="${ZABBIX_USER:-Admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-zabbix}"
TEMPLATE_NAME="Template Aztec Node Monitoring"
HOSTGROUP_NAME="Aztec Nodes"
LINUX_HOSTGROUP_NAME="Linux servers"  # Second hostgroup for Linux monitoring
FORCE_RECREATE="${FORCE_RECREATE:-false}"  # New option to force recreate existing hosts

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
    if [ -n "$ZABBIX_API_TOKEN" ]; then
        echo -e "${YELLOW}Using API Token authentication...${NC}"
        AUTH_TOKEN="$ZABBIX_API_TOKEN"
        
        # Test the API token with a simple authenticated call
        echo -e "${YELLOW}Validating API Token...${NC}"
        local test_response=$(zabbix_api_call "hostgroup.get" "{\"output\": [\"groupid\"], \"limit\": 1}")
        local test_result=$(echo "$test_response" | python3 -c "import sys, json; data = json.load(sys.stdin); print('ok' if 'result' in data else 'error')" 2>/dev/null)
        
        if [ "$test_result" != "ok" ]; then
            echo -e "${RED}API Token validation failed! Check your token.${NC}"
            echo "Response: $test_response"
            return 1
        fi
        
        echo -e "${GREEN}API Token validated successfully!${NC}"
    else
        echo -e "${YELLOW}Using username/password authentication...${NC}"
        echo -e "${YELLOW}Note: Consider using API Token for better security${NC}"
        
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
            return 1
        fi
        
        echo -e "${GREEN}Successfully authenticated with username/password!${NC}"
    fi
    return 0
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
        return 1
    fi
    
    echo -e "${GREEN}Template ID: ${TEMPLATE_ID}${NC}"
    return 0
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
    return 0
}

# Function to get or create Linux hostgroup
get_linux_hostgroup_id() {
    echo -e "${YELLOW}Getting Linux hostgroup ID...${NC}"
    
    local response=$(zabbix_api_call "hostgroup.get" "{
        \"output\": [\"groupid\"],
        \"filter\": {
            \"name\": [\"${LINUX_HOSTGROUP_NAME}\"]
        }
    }")
    
    LINUX_HOSTGROUP_ID=$(echo "$response" | python3 -c "import sys, json; result = json.load(sys.stdin)['result']; print(result[0]['groupid'] if result else '')" 2>/dev/null)
    
    if [ -z "$LINUX_HOSTGROUP_ID" ]; then
        echo -e "${YELLOW}Creating Linux hostgroup '${LINUX_HOSTGROUP_NAME}'...${NC}"
        
        local create_response=$(zabbix_api_call "hostgroup.create" "{
            \"name\": \"${LINUX_HOSTGROUP_NAME}\"
        }")
        
        LINUX_HOSTGROUP_ID=$(echo "$create_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['groupids'][0])" 2>/dev/null)
    fi
    
    echo -e "${GREEN}Linux Hostgroup ID: ${LINUX_HOSTGROUP_ID}${NC}"
    return 0
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
        if [ "$FORCE_RECREATE" = "true" ]; then
            echo -e "${YELLOW}Host ${hostname} exists (ID: ${existing_id}), deleting for recreation...${NC}"
            local delete_response=$(zabbix_api_call "host.delete" "[\"${existing_id}\"]")
            echo -e "${YELLOW}Delete response: ${delete_response}${NC}"
            sleep 2  # Wait for deletion to complete
        else
            echo -e "${YELLOW}Host ${hostname} already exists (ID: ${existing_id}), updating IP and template...${NC}"
            
            # Update existing host with correct IP, groups and templates
            local update_response=$(zabbix_api_call "host.update" "{
                \"hostid\": \"${existing_id}\",
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
                    },
                    {
                        \"groupid\": \"${LINUX_HOSTGROUP_ID}\"
                    }
                ],
                $(if [ -n "$TEMPLATE_ID" ]; then
                    echo "\"templates\": [
                        {
                            \"templateid\": \"${TEMPLATE_ID}\"
                        }
                    ]"
                else
                    echo "\"templates\": []"
                fi)
            }")
            
            echo -e "${YELLOW}Update API Response: ${update_response}${NC}"
            
            # Check if update response contains error
            local update_error_msg=$(echo "$update_response" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('error', {}).get('data', ''))" 2>/dev/null)
            if [ -n "$update_error_msg" ]; then
                echo -e "${RED}✗ Update API Error: ${update_error_msg}${NC}"
                return 1
            fi
            
            local updated_hostid=$(echo "$update_response" | python3 -c "import sys, json; result = json.load(sys.stdin).get('result', {}); print(result.get('hostids', ['${existing_id}'])[0])" 2>/dev/null)
            
            if [ -n "$updated_hostid" ]; then
                if [ -n "$TEMPLATE_ID" ]; then
                    echo -e "${GREEN}✓ Host ${hostname} updated successfully with IP: ${ip_address} and template${NC}"
                else
                    echo -e "${GREEN}✓ Host ${hostname} updated successfully with IP: ${ip_address} (no template)${NC}"
                fi
                return 0
            else
                echo -e "${RED}✗ Failed to update host ${hostname}${NC}"
                return 1
            fi
        fi
    fi
    
    # Create host
    echo -e "${YELLOW}Creating host ${hostname}...${NC}"
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
            },
            {
                \"groupid\": \"${LINUX_HOSTGROUP_ID}\"
            }
        ],
        $(if [ -n "$TEMPLATE_ID" ]; then
            echo "\"templates\": [
                {
                    \"templateid\": \"${TEMPLATE_ID}\"
                }
            ]"
        else
            echo "\"templates\": []"
        fi)
    }")
    
    echo -e "${YELLOW}API Response: ${response}${NC}"
    
    # Check if response contains error
    local error_msg=$(echo "$response" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('error', {}).get('data', ''))" 2>/dev/null)
    if [ -n "$error_msg" ]; then
        echo -e "${RED}✗ API Error: ${error_msg}${NC}"
        return 1
    fi
    
    local host_id=$(echo "$response" | python3 -c "import sys, json; result = json.load(sys.stdin).get('result', {}); print(result.get('hostids', [''])[0])" 2>/dev/null)
    
    if [ -n "$host_id" ]; then
        if [ -n "$TEMPLATE_ID" ]; then
            echo -e "${GREEN}✓ Host ${hostname} created with ID: ${host_id} (with template)${NC}"
        else
            echo -e "${GREEN}✓ Host ${hostname} created with ID: ${host_id} (no template - please link manually)${NC}"
        fi
        
        # Verify host was actually created
        sleep 1
        local verify_response=$(zabbix_api_call "host.get" "{
            \"output\": [\"hostid\", \"host\", \"name\", \"status\"],
            \"hostids\": [\"${host_id}\"]
        }")
        
        local verified_host=$(echo "$verify_response" | python3 -c "import sys, json; result = json.load(sys.stdin)['result']; print(result[0]['host'] if result else '')" 2>/dev/null)
        
        if [ "$verified_host" = "$hostname" ]; then
            echo -e "${GREEN}✓ Host ${hostname} verified successfully in Zabbix${NC}"
            return 0
        else
            echo -e "${RED}✗ Host ${hostname} verification failed - not found in Zabbix${NC}"
            echo -e "${YELLOW}Verification response: ${verify_response}${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to add host ${hostname} - no host ID returned${NC}"
        echo -e "${YELLOW}Full response: $response${NC}"
        return 1
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
    
    # Debug: Show total lines in file
    local total_lines=$(wc -l < "$inventory_file")
    echo -e "${YELLOW}Total lines in inventory file: ${total_lines}${NC}"
    
    # Debug: Show lines that match the pattern
    local matching_lines=$(grep -E "^[0-9]" "$inventory_file" | wc -l)
    echo -e "${YELLOW}Lines matching pattern ^[0-9]: ${matching_lines}${NC}"
    
    # Debug: Show first few matching lines
    echo -e "${YELLOW}First 5 matching lines:${NC}"
    grep -E "^[0-9]" "$inventory_file" | head -5
    
    # If no lines match the numeric pattern, try alternative parsing
    if [ "$matching_lines" -eq 0 ]; then
        echo -e "${YELLOW}No lines match numeric pattern, trying alternative parsing...${NC}"
        echo -e "${YELLOW}Showing first 10 lines of file:${NC}"
        head -10 "$inventory_file"
        echo -e "${YELLOW}---${NC}"
        
        # Try parsing lines that contain ansible_host
        local alt_matching=$(grep "ansible_host=" "$inventory_file" | wc -l)
        echo -e "${YELLOW}Lines containing 'ansible_host=': ${alt_matching}${NC}"
        
        if [ "$alt_matching" -gt 0 ]; then
            echo -e "${YELLOW}Using alternative parsing for ansible_host format...${NC}"
            # Parse Ansible inventory format - alternative method
            local hosts_added=0
            local hosts_failed=0
            
            # Read all matching lines into an array first
            local host_lines=()
            while IFS= read -r line; do
                if [[ -n "$line" && ! "$line" =~ ^# && ! "$line" =~ ^\[ ]]; then
                    host_lines+=("$line")
                fi
            done < <(grep "ansible_host=" "$inventory_file")
            
            echo -e "${YELLOW}Found ${#host_lines[@]} host entries to process${NC}"
            
            # Process each host line
            for i in "${!host_lines[@]}"; do
                local line="${host_lines[$i]}"
                echo -e "${BLUE}=== Processing host $((i+1))/${#host_lines[@]} ===${NC}"
                
                hostname=$(echo "$line" | awk '{print $1}')
                ip_address=$(echo "$line" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2)
                
                echo -e "${YELLOW}Processing line: $line${NC}"
                echo -e "${YELLOW}  Hostname: '$hostname'${NC}"
                echo -e "${YELLOW}  IP Address: '$ip_address'${NC}"
                
                if [ -n "$hostname" ] && [ -n "$ip_address" ]; then
                    echo -e "${BLUE}Calling add_host function for $hostname...${NC}"
                    # Use set +e to continue on errors
                    set +e
                    add_host "$hostname" "$ip_address"
                    local exit_code=$?
                    # Keep set +e to prevent script termination on errors
                    # set -e
                    
                    echo -e "${BLUE}add_host returned exit code: $exit_code${NC}"
                    
                    if [ $exit_code -eq 0 ]; then
                        ((hosts_added++))
                        echo -e "${GREEN}Successfully processed host $hostname${NC}"
                    else
                        ((hosts_failed++))
                        echo -e "${RED}  Failed to add host '$hostname'${NC}"
                    fi
                else
                    echo -e "${RED}  Skipping - missing hostname or IP${NC}"
                    ((hosts_failed++))
                fi
                
                echo -e "${BLUE}--- Completed processing $hostname (${i+1}/${#host_lines[@]}) ---${NC}"
                echo ""
            done
            
            echo -e "${GREEN}Total hosts processed (alternative method): ${hosts_added}${NC}"
            echo -e "${RED}Total hosts failed: ${hosts_failed}${NC}"
            return 0  # Always return success to prevent script termination
        fi
    fi
    
    # Parse Ansible inventory format - original method
    local hosts_added=0
    local hosts_failed=0
    
    # Read all matching lines into an array first
    local host_lines=()
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            host_lines+=("$line")
        fi
    done < <(grep -E "^[0-9]" "$inventory_file")
    
    echo -e "${YELLOW}Found ${#host_lines[@]} host entries to process (original method)${NC}"
    
    # Process each host line
    for i in "${!host_lines[@]}"; do
        local line="${host_lines[$i]}"
        echo -e "${BLUE}=== Processing host $((i+1))/${#host_lines[@]} ===${NC}"
        
        hostname=$(echo "$line" | awk '{print $1}')
        ip_address=$(echo "$line" | grep -o "ansible_host=[0-9.]*" | cut -d= -f2)
        
        echo -e "${YELLOW}Processing line: $line${NC}"
        echo -e "${YELLOW}  Hostname: '$hostname'${NC}"
        echo -e "${YELLOW}  IP Address: '$ip_address'${NC}"
        
        if [ -n "$hostname" ] && [ -n "$ip_address" ]; then
            echo -e "${BLUE}Calling add_host function for $hostname...${NC}"
            # Use set +e to continue on errors
            set +e
            add_host "$hostname" "$ip_address"
            local exit_code=$?
            # Keep set +e to prevent script termination on errors
            # set -e
            
            echo -e "${BLUE}add_host returned exit code: $exit_code${NC}"
            
            if [ $exit_code -eq 0 ]; then
                ((hosts_added++))
                echo -e "${GREEN}Successfully processed host $hostname${NC}"
            else
                ((hosts_failed++))
                echo -e "${RED}  Failed to add host '$hostname'${NC}"
            fi
        else
            echo -e "${RED}  Skipping - missing hostname or IP${NC}"
            ((hosts_failed++))
        fi
        
        echo -e "${BLUE}--- Completed processing $hostname (${i+1}/${#host_lines[@]}) ---${NC}"
        echo ""
    done
    
    echo -e "${GREEN}Total hosts processed: ${hosts_added}${NC}"
    echo -e "${RED}Total hosts failed: ${hosts_failed}${NC}"
}

# Main execution
main() {
    echo -e "${GREEN}=== Aztec Nodes Zabbix Auto-Add Script ===${NC}"
    
    # Check if inventory file is provided
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <inventory_file>"
        echo "Example: $0 aztec_ansible/common/inventory/hosts"
        echo ""
        echo "Environment variables:"
        echo "  FORCE_RECREATE=true  - Delete and recreate existing hosts"
        exit 1
    fi
    
    local inventory_file="$1"
    
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  Force recreate: ${FORCE_RECREATE}"
    echo -e "  Inventory file: ${inventory_file}"
    echo ""
    
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
        echo -e "${RED}Please set ZABBIX_SERVER environment variable or configure it in the script!${NC}"
        echo -e "${YELLOW}Example: export ZABBIX_SERVER=http://your-zabbix-server/zabbix${NC}"
        exit 1
    fi
    
    # Check if essential variables are set
    if [[ -z "$ZABBIX_SERVER" ]]; then
        echo -e "${RED}Error: ZABBIX_SERVER is required!${NC}"
        echo -e "  ZABBIX_SERVER (current: ${ZABBIX_SERVER:-'not set'})"
        exit 1
    fi
    
    # Check authentication method
    if [[ -n "$ZABBIX_API_TOKEN" ]]; then
        echo -e "${GREEN}✓ API Token authentication configured${NC}"
    elif [[ -n "$ZABBIX_USER" && -n "$ZABBIX_PASSWORD" ]]; then
        echo -e "${YELLOW}⚠ Username/password authentication configured${NC}"
        echo -e "${YELLOW}  Consider using API Token for better security${NC}"
    else
        echo -e "${RED}Error: No valid authentication method configured!${NC}"
        echo -e "${YELLOW}Required authentication (choose one):${NC}"
        echo -e "  Option 1 (Recommended): ZABBIX_API_TOKEN"
        echo -e "  Option 2 (Legacy): ZABBIX_USER + ZABBIX_PASSWORD"
        echo ""
        echo -e "${YELLOW}Current values:${NC}"
        echo -e "  ZABBIX_API_TOKEN: ${ZABBIX_API_TOKEN:-'not set'}"
        echo -e "  ZABBIX_USER: ${ZABBIX_USER:-'not set'}"
        echo -e "  ZABBIX_PASSWORD: ${ZABBIX_PASSWORD:-'not set'}"
        exit 1
    fi
    
    # Execute steps - disable strict error handling to continue on individual host failures
    set +e
    authenticate
    if [ $? -ne 0 ]; then
        echo -e "${RED}Authentication failed, exiting${NC}"
        exit 1
    fi
    
    get_template_id
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to get template ID, continuing without template${NC}"
        echo -e "${YELLOW}⚠ Hosts will be created without Aztec monitoring template${NC}"
        echo -e "${YELLOW}⚠ Please import 'aztec_zabbix_template.xml' and manually link it to hosts${NC}"
        TEMPLATE_ID=""
    fi
    
    get_hostgroup_id  
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to get hostgroup ID, exiting${NC}"
        exit 1
    fi
    
    get_linux_hostgroup_id  
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to get Linux hostgroup ID, exiting${NC}"
        exit 1
    fi
    
    read_hosts_from_inventory "$inventory_file"
    local final_result=$?
    set -e
    
    echo -e "${GREEN}=== Finished adding hosts to Zabbix ===${NC}"
    
    if [ -z "$TEMPLATE_ID" ]; then
        echo ""
        echo -e "${YELLOW}⚠ IMPORTANT: Hosts were created without Aztec monitoring template!${NC}"
        echo -e "${YELLOW}Next steps:${NC}"
        echo -e "  1. Import 'aztec_zabbix_template.xml' into your Zabbix server"
        echo -e "  2. Go to Configuration → Hosts in Zabbix web interface"
        echo -e "  3. Select your Aztec hosts and link 'Template Aztec Node Monitoring' template"
        echo -e "  4. Wait 2-3 minutes for monitoring data to appear"
        echo ""
    else
        echo ""
        echo -e "${GREEN}✅ All hosts configured with Aztec monitoring template!${NC}"
        echo -e "${GREEN}Next steps:${NC}"
        echo -e "  1. Check host status in Zabbix web interface"
        echo -e "  2. Wait 2-3 minutes for monitoring data to appear"
        echo -e "  3. Configure alerts and notifications as needed"
        echo ""
    fi
    
    exit $final_result
}

# Run main function
main "$@" 
