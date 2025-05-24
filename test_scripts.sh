#!/bin/bash

# Test script for new functionality
set -e

echo "🧪 Testing Aztec Management Scripts"
echo "=================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Test 1: Check if scripts exist
print_colored $BLUE "🔍 Test 1: Checking if scripts exist..."

scripts_to_check=(
    "./get_proof.sh"
    "./sync_check.sh"
    "aztec_ansible/get_proof_playbook/run_get_proof.sh"
    "aztec_ansible/get_proof_playbook/run_sync_check.sh"
    "aztec_ansible/get_proof_playbook/sync_check_single.sh"
    "aztec_ansible/get_proof_playbook/parse_proof.py"
)

for script in "${scripts_to_check[@]}"; do
    if [[ -f "$script" ]]; then
        print_colored $GREEN "✅ $script exists"
    else
        print_colored $RED "❌ $script missing"
    fi
done

# Test 2: Check if scripts are executable
print_colored $BLUE "🔍 Test 2: Checking if scripts are executable..."

executable_scripts=(
    "./get_proof.sh"
    "./sync_check.sh"
    "aztec_ansible/get_proof_playbook/run_get_proof.sh"
    "aztec_ansible/get_proof_playbook/run_sync_check.sh"
    "aztec_ansible/get_proof_playbook/sync_check_single.sh"
)

for script in "${executable_scripts[@]}"; do
    if [[ -x "$script" ]]; then
        print_colored $GREEN "✅ $script is executable"
    else
        print_colored $YELLOW "⚠️  $script is not executable"
        chmod +x "$script" 2>/dev/null && print_colored $GREEN "   Fixed: made executable"
    fi
done

# Test 3: Check help functionality
print_colored $BLUE "🔍 Test 3: Testing help functionality..."

echo "Testing get_proof.sh --help:"
if ./get_proof.sh --help >/dev/null 2>&1; then
    print_colored $GREEN "✅ get_proof.sh --help works"
else
    print_colored $RED "❌ get_proof.sh --help failed"
fi

echo "Testing sync_check.sh --help:"
if ./sync_check.sh --help >/dev/null 2>&1; then
    print_colored $GREEN "✅ sync_check.sh --help works"
else
    print_colored $RED "❌ sync_check.sh --help failed"
fi

# Test 4: Check required files structure
print_colored $BLUE "🔍 Test 4: Checking required directory structure..."

required_dirs=(
    "aztec_ansible"
    "aztec_ansible/common"
    "aztec_ansible/get_proof_playbook"
    "aztec_ansible/install_playbook"
)

for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        print_colored $GREEN "✅ Directory $dir exists"
    else
        print_colored $RED "❌ Directory $dir missing"
    fi
done

# Test 5: Check if inventory file exists
print_colored $BLUE "🔍 Test 5: Checking inventory file..."

inventory_file="aztec_ansible/common/inventory/hosts"
if [[ -f "$inventory_file" ]]; then
    server_count=$(grep -E '^\s*[0-9]+\.' "$inventory_file" | wc -l | tr -d ' ')
    print_colored $GREEN "✅ Inventory file exists with $server_count servers"
else
    print_colored $YELLOW "⚠️  Inventory file not found: $inventory_file"
    print_colored $YELLOW "   Run: cd aztec_ansible/install_playbook && ./run_01_prepare.sh path/to/servers.csv"
fi

# Test 6: Check SSH key
print_colored $BLUE "🔍 Test 6: Checking SSH key..."

ssh_key="aztec_ansible/common/ssh/id_rsa"
if [[ -f "$ssh_key" ]]; then
    print_colored $GREEN "✅ SSH key exists"
    # Check permissions
    perms=$(stat -f "%OLp" "$ssh_key" 2>/dev/null || stat -c "%a" "$ssh_key" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        print_colored $GREEN "✅ SSH key has correct permissions (600)"
    else
        print_colored $YELLOW "⚠️  SSH key permissions: $perms (should be 600)"
        chmod 600 "$ssh_key" && print_colored $GREEN "   Fixed: set permissions to 600"
    fi
else
    print_colored $YELLOW "⚠️  SSH key not found: $ssh_key"
fi

# Test 7: Test Python parser
print_colored $BLUE "🔍 Test 7: Testing Python parser..."

if python3 -c "import re, json, sys" 2>/dev/null; then
    print_colored $GREEN "✅ Python3 with required modules available"
    
    # Test the parser with sample data
    sample_output="Номер блока: 2226\n\nProof: AAAAHQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgp3r7EQXbWMX"
    
    if [[ -f "aztec_ansible/get_proof_playbook/parse_proof.py" ]]; then
        result=$(python3 aztec_ansible/get_proof_playbook/parse_proof.py "$sample_output" 2>/dev/null)
        if echo "$result" | jq . >/dev/null 2>&1; then
            print_colored $GREEN "✅ Python parser works correctly"
            block_num=$(echo "$result" | jq -r '.block_number')
            print_colored $GREEN "   Parsed block number: $block_num"
        else
            print_colored $RED "❌ Python parser output is not valid JSON"
        fi
    else
        print_colored $RED "❌ Python parser not found"
    fi
else
    print_colored $RED "❌ Python3 or required modules not available"
fi

# Test 8: Validate Ansible playbook syntax
print_colored $BLUE "🔍 Test 8: Validating Ansible playbook syntax..."

playbooks=(
    "aztec_ansible/get_proof_playbook/get_proof.yml"
    "aztec_ansible/get_proof_playbook/sync_check.yml"
)

for playbook in "${playbooks[@]}"; do
    if [[ -f "$playbook" ]]; then
        if command -v ansible-playbook >/dev/null 2>&1; then
            if ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
                print_colored $GREEN "✅ $playbook syntax is valid"
            else
                print_colored $RED "❌ $playbook has syntax errors"
            fi
        else
            print_colored $YELLOW "⚠️  ansible-playbook not found, skipping syntax check for $playbook"
        fi
    else
        print_colored $RED "❌ $playbook not found"
    fi
done

# Final summary
print_colored $BLUE "🎯 Test Summary"
print_colored $GREEN "✅ All basic functionality tests completed"
print_colored $YELLOW "⚠️  To actually test functionality, ensure:"
echo "   1. Servers are prepared via install playbook"
echo "   2. Inventory file exists with valid server IPs"
echo "   3. SSH key has proper access to servers"
echo ""
print_colored $BLUE "🚀 Ready to use:"
echo "   ./sync_check.sh    - Check sync status of all nodes"
echo "   ./get_proof.sh     - Collect proof from all nodes" 
