#!/bin/bash

# Script to fix AllowRoot issue and remove PSK from all Zabbix agents
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

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check if inventory exists
if [[ ! -f "$INVENTORY_PATH" ]]; then
    error "Inventory file not found: $INVENTORY_PATH"
    exit 1
fi

log "=== Fixing Zabbix AllowRoot issue and removing PSK configuration on all servers ==="

# Step 1: Remove AllowRoot and PSK configuration from config files
log "Step 1: Removing AllowRoot and PSK configuration from all Zabbix configs..."

# Remove AllowRoot
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "sed -i '/AllowRoot=1/d' /etc/zabbix/zabbix_agent2.conf" \
  --become || error "Failed to remove AllowRoot from some servers"

# Remove PSK related parameters
log "Removing PSK Identity configuration..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "sed -i '/^TLSPSKIdentity=/d' /etc/zabbix/zabbix_agent2.conf" \
  --become || warning "Failed to remove TLSPSKIdentity from some servers"

log "Removing PSK File configuration..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "sed -i '/^TLSPSKFile=/d' /etc/zabbix/zabbix_agent2.conf" \
  --become || warning "Failed to remove TLSPSKFile from some servers"

log "Removing TLS Accept PSK configuration..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "sed -i '/^TLSAccept=.*psk/d' /etc/zabbix/zabbix_agent2.conf" \
  --become || warning "Failed to remove TLSAccept PSK from some servers"

log "Removing TLS Connect PSK configuration..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "sed -i '/^TLSConnect=psk/d' /etc/zabbix/zabbix_agent2.conf" \
  --become || warning "Failed to remove TLSConnect PSK from some servers"

# Step 2: Remove PSK files if they exist
log "Step 2: Removing PSK key files..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "find /etc/zabbix/ -name '*.psk' -delete 2>/dev/null || true" \
  --become || warning "Failed to remove PSK files from some servers"

# Step 3: Set TLS to unencrypted if not already set
log "Step 3: Setting TLS to unencrypted mode..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "
    if ! grep -q '^TLSConnect=' /etc/zabbix/zabbix_agent2.conf; then
      echo 'TLSConnect=unencrypted' >> /etc/zabbix/zabbix_agent2.conf
    fi
  " \
  --become || warning "Failed to set TLSConnect on some servers"

ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "
    if ! grep -q '^TLSAccept=' /etc/zabbix/zabbix_agent2.conf; then
      echo 'TLSAccept=unencrypted' >> /etc/zabbix/zabbix_agent2.conf
    fi
  " \
  --become || warning "Failed to set TLSAccept on some servers"

# Step 4: Restart all agents
log "Step 4: Restarting all Zabbix agents..."
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m systemd -a "name=zabbix-agent2 state=restarted" \
  --become || error "Failed to restart some agents"

# Wait for agents to start
sleep 5

# Step 5: Check status
log "Step 5: Checking agent status on all servers..."
echo ""
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "systemctl is-active zabbix-agent2 && echo 'Agent OK on' \$(hostname)" \
  --become

echo ""

# Step 6: Verify AllowRoot and PSK are removed
log "Step 6: Verifying AllowRoot and PSK configuration is removed..."

# Check AllowRoot removal
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "if grep -q 'AllowRoot' /etc/zabbix/zabbix_agent2.conf; then echo 'ERROR: AllowRoot still present'; exit 1; else echo 'OK: AllowRoot removed'; fi" \
  --become

# Check PSK removal
ansible all -i "$INVENTORY_PATH" --private-key="$SSH_KEY" \
  --ssh-extra-args="$SSH_OPTS" \
  -m shell -a "if grep -q 'TLSPSK' /etc/zabbix/zabbix_agent2.conf; then echo 'WARNING: PSK config still present'; else echo 'OK: PSK config removed'; fi" \
  --become

echo ""
success "=== AllowRoot and PSK issues fixed on all servers! ==="

log "Next steps:"
echo "  1. Check Zabbix Server for agent connectivity (should work without encryption now)"
echo "  2. Test UserParameters: ansible all -i $INVENTORY_PATH --private-key=$SSH_KEY --ssh-extra-args=\"$SSH_OPTS\" -m shell -a 'zabbix_agent2 -t aztec.service.status' --become"
echo "  3. Monitor logs: journalctl -u zabbix-agent2.service -f"
echo "  4. Update Zabbix Server host configuration to use unencrypted connection"
echo ""
warning "Note: All agents are now configured for unencrypted connection to Zabbix Server" 
