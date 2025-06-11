#!/bin/bash

# Test script for Zabbix Aztec monitoring
# Usage: ./test_zabbix_monitoring.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
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

test_service_status() {
    log "Testing service status checks..."
    
    echo "Zabbix Agent Status:"
    systemctl is-active zabbix-agent2 && success "Zabbix Agent is running" || error "Zabbix Agent is not running"
    
    echo "Aztec Service Status:"
    systemctl is-active aztec-node.service && success "Aztec Service is running" || warning "Aztec Service is not running"
    
    echo ""
}

test_userparameters() {
    log "Testing Zabbix UserParameters..."
    
    local tests=(
        "aztec.service.status:Service Status"
        "aztec.rpc.check:RPC Check"
        "aztec.port.check:Port Check"
        "aztec.block.local:Local Block"
        "aztec.sync.status:Sync Status"
        "aztec.process.count:Process Count"
    )
    
    for test in "${tests[@]}"; do
        IFS=':' read -r key desc <<< "$test"
        result=$(zabbix_agent2 -t "$key" 2>/dev/null | grep -oE '[0-9]+$' || echo "FAILED")
        
        if [[ "$result" =~ ^[0-9]+$ ]]; then
            success "$desc: $result"
        else
            error "$desc: $result"
        fi
    done
    
    echo ""
}

test_manual_scripts() {
    log "Testing manual monitoring scripts..."
    
    if [[ -f "/usr/local/bin/aztec_monitor.sh" ]]; then
        success "Aztec monitor script found"
        
        local tests=(
            "service_status:Service Status"
            "rpc_check:RPC Check"
            "port_check:Port Check"
            "local_block:Local Block"
        )
        
        for test in "${tests[@]}"; do
            IFS=':' read -r cmd desc <<< "$test"
            result=$(/usr/local/bin/aztec_monitor.sh "$cmd" 2>/dev/null || echo "FAILED")
            
            if [[ "$result" =~ ^[0-9]+$ ]]; then
                success "$desc: $result"
            else
                warning "$desc: $result"
            fi
        done
    else
        error "Aztec monitor script not found at /usr/local/bin/aztec_monitor.sh"
    fi
    
    echo ""
}

test_rpc_directly() {
    log "Testing RPC directly (as Zabbix does)..."
    
    # Test the exact curl command that Zabbix uses
    response=$(curl -m 5 -s -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' \
        "http://localhost:8080" 2>/dev/null)
    
    if [[ -n "$response" && "$response" != *"error"* ]]; then
        success "RPC responding correctly"
        
        # Extract block number
        if command -v jq >/dev/null 2>&1; then
            block=$(echo "$response" | jq -r '.result.proven.number' 2>/dev/null)
            if [[ "$block" != "null" && "$block" != "" ]]; then
                info "Current block: $block"
            else
                warning "Could not parse block number from response"
            fi
        else
            info "Install jq for detailed JSON parsing"
        fi
        
        # Show raw response (truncated)
        info "Raw response: ${response:0:100}..."
    else
        error "RPC not responding or returned error"
        warning "Response: $response"
    fi
    
    echo ""
}

test_network() {
    log "Testing network connectivity..."
    
    # Test port 8080
    if lsof -i :8080 >/dev/null 2>&1; then
        success "Port 8080 is listening"
        
        # Show what's listening
        process=$(lsof -i :8080 2>/dev/null | tail -1 | awk '{print $1}')
        info "Process: $process"
    else
        error "Port 8080 is not listening"
    fi
    
    # Test port 10050 (Zabbix agent)
    if lsof -i :10050 >/dev/null 2>&1; then
        success "Zabbix agent port 10050 is listening"
    else
        warning "Zabbix agent port 10050 is not listening"
    fi
    
    echo ""
}

test_logs() {
    log "Checking recent logs..."
    
    # Zabbix agent logs
    if [[ -f "/var/log/zabbix/zabbix_agent2.log" ]]; then
        info "Recent Zabbix agent log entries:"
        tail -3 /var/log/zabbix/zabbix_agent2.log 2>/dev/null || warning "Could not read Zabbix logs"
    else
        warning "Zabbix log file not found"
    fi
    
    echo ""
    
    # Aztec service logs
    info "Recent Aztec service log entries:"
    journalctl -u aztec-node.service -n 3 --no-pager 2>/dev/null || warning "Could not read Aztec logs"
    
    echo ""
}

show_summary() {
    log "=== Test Summary ==="
    
    info "Configuration files:"
    echo "  • Zabbix config: /etc/zabbix/zabbix_agent2.conf"
    echo "  • UserParameters: /etc/zabbix/zabbix_agent2.d/aztec_monitoring.conf"
    echo "  • Monitor script: /usr/local/bin/aztec_monitor.sh"
    
    echo ""
    info "Useful commands:"
    echo "  • Test UserParameter: zabbix_agent2 -t aztec.service.status"
    echo "  • Manual test: /usr/local/bin/aztec_monitor.sh service_status"
    echo "  • View logs: tail -f /var/log/zabbix/zabbix_agent2.log"
    echo "  • Check service: systemctl status zabbix-agent2"
    
    echo ""
    info "Next steps:"
    echo "  1. Import aztec_zabbix_template.xml to Zabbix server"
    echo "  2. Add this host to Zabbix with IP: $(hostname -I | awk '{print $1}')"
    echo "  3. Link 'Template Aztec Node Monitoring' template"
    echo "  4. Wait 2-3 minutes for data collection"
    
    echo ""
}

main() {
    echo "=================================================="
    log "🔍 Zabbix Aztec Monitoring Test Suite"
    echo "=================================================="
    echo ""
    
    test_service_status
    test_network
    test_rpc_directly
    test_manual_scripts
    test_userparameters
    test_logs
    show_summary
    
    success "=== Testing completed! ==="
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warning "Running as root. Some tests may need to be run as zabbix user."
fi

# Run main function
main "$@" 
