#!/bin/bash

# Script to fix AllowRoot issue on all Zabbix agents
# Usage: ./fix_zabbix_allowroot.sh [inventory_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INVENTORY_NAME="${1:-hosts}"
INVENTORY_PATH="../common/inventory/$INVENTORY_NAME"
SSH_KEY="../common/ssh/id_rsa"

# SSH options to avoid host key checking
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Check if inventory exists
if [[ ! -f "$INVENTORY_PATH" ]]; then
    error "Inventory file not found: $INVENTORY_PATH"
    exit 1
fi

log "=== Fixing Zabbix AllowRoot issue on all servers ==="

# Step 1: Remove AllowRoot from config files
log "Step 1: Removing AllowRoot from all Zabbix configs..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "sed -i '/AllowRoot=1/d' /etc/zabbix/zabbix_agent2.conf" \
  --become || error "Failed to remove AllowRoot from some servers"

# Step 2: Restart all agents
log "Step 2: Restarting all Zabbix agents..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m systemd -a "name=zabbix-agent2 state=restarted" \
  --become || error "Failed to restart some agents"

# Wait a bit for agents to start
sleep 5

# Step 3: Check status
log "Step 3: Checking agent status on all servers..."
echo ""
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "systemctl is-active zabbix-agent2 && echo 'Agent OK on' \$(hostname)" \
  --become

echo ""

# Step 4: Verify AllowRoot is gone
log "Step 4: Verifying AllowRoot is removed from all configs..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "if grep -q 'AllowRoot' /etc/zabbix/zabbix_agent2.conf; then echo 'ERROR: AllowRoot still present'; exit 1; else echo 'OK: AllowRoot removed'; fi" \
  --become

echo ""
success "=== AllowRoot issue fixed on all servers! ==="

log "Next steps:"
echo "  1. Check Zabbix Server for agent connectivity"
echo "  2. Test UserParameters: ansible all -i $INVENTORY_PATH --private-key=$SSH_KEY --ssh-extra-args=\"$SSH_OPTS\" -m shell -a 'zabbix_agent2 -t aztec.service.status' --become"
echo "  3. Monitor logs: journalctl -u zabbix-agent2.service -f" 
