#!/bin/bash

REMOTE_RPC="https://aztec-rpc.cerberusnode.com"

# Check if any app is running on port 8080
if lsof -i :8080 >/dev/null 2>&1; then
  echo "✅ Detected app running on port 8080"
  PORT=8080
else
  # Check common Aztec ports
  if lsof -i :8081 >/dev/null 2>&1; then
    echo "✅ Detected app running on port 8081"
    PORT=8081
  elif lsof -i :8082 >/dev/null 2>&1; then
    echo "✅ Detected app running on port 8082"
    PORT=8082
  else
    echo "❌ No Aztec node found on common ports (8080, 8081, 8082)"
    exit 1
  fi
fi

LOCAL_RPC="http://localhost:$PORT"

# Single check without loop
echo "🔍 Checking Aztec node sync status at $(date '+%Y-%m-%d %H:%M:%S')"

# Check LOCAL node status
LOCAL_RESPONSE=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$LOCAL_RPC")

if [ -z "$LOCAL_RESPONSE" ] || [[ "$LOCAL_RESPONSE" == *"error"* ]]; then
  echo "❌ Local node not responding or returned an error. Please check if it's running on $LOCAL_RPC"
  LOCAL="N/A"
else
  LOCAL=$(echo "$LOCAL_RESPONSE" | jq -r ".result.proven.number")
fi

# Check REMOTE node status
REMOTE_RESPONSE=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$REMOTE_RPC")

if [ -z "$REMOTE_RESPONSE" ] || [[ "$REMOTE_RESPONSE" == *"error"* ]]; then
  echo "⚠️ Remote RPC ($REMOTE_RPC) not responding or returned an error."
  REMOTE="N/A"
else
  REMOTE=$(echo "$REMOTE_RESPONSE" | jq -r ".result.proven.number")
fi

echo "🧱 Local block:  $LOCAL"
echo "🌐 Remote block: $REMOTE"

if [[ "$LOCAL" == "N/A" ]] || [[ "$REMOTE" == "N/A" ]]; then
  echo "🚫 Cannot determine sync status due to an error in one of the RPC responses."
  exit 2
elif [ "$LOCAL" = "$REMOTE" ]; then
  echo "✅ Your node is fully synced!"
  exit 0
else
  echo "⏳ Still syncing... ($LOCAL / $REMOTE)"
  exit 3
fi

echo "-------------------------------" 
