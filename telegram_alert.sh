#!/bin/bash

# Telegram Alert Script for Zabbix
# Usage: telegram_alert.sh <chat_id> <subject> <message>

# Configuration
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="$1"
SUBJECT="$2"
MESSAGE="$3"

# Check if all required parameters are provided
if [[ -z "$BOT_TOKEN" ]]; then
    echo "Error: TELEGRAM_BOT_TOKEN environment variable is not set"
    exit 1
fi

if [[ -z "$CHAT_ID" ]] || [[ -z "$SUBJECT" ]] || [[ -z "$MESSAGE" ]]; then
    echo "Usage: $0 <chat_id> <subject> <message>"
    exit 1
fi

# Prepare message text
TEXT="🚨 *Zabbix Alert*
*Subject:* $SUBJECT

*Message:*
$MESSAGE

*Time:* $(date '+%Y-%m-%d %H:%M:%S')"

# URL encode the message
TEXT=$(echo "$TEXT" | sed 's/ /%20/g; s/\*/%2A/g; s/_/%5F/g; s/\[/%5B/g; s/\]/%5D/g; s/(/%28/g; s/)/%29/g; s/~/%7E/g; s/`/%60/g; s/>/%3E/g; s/#/%23/g; s/+/%2B/g; s/-/%2D/g; s/=/%3D/g; s/|/%7C/g; s/{/%7B/g; s/}/%7D/g; s/\./%2E/g; s/!/%21/g')

# Send message to Telegram
TELEGRAM_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"

# Try curl first, then wget as fallback
if command -v curl >/dev/null 2>&1; then
    curl -s -X POST "$TELEGRAM_URL" \
        -d chat_id="$CHAT_ID" \
        -d text="$TEXT" \
        -d parse_mode="Markdown" \
        > /dev/null 2>&1
    RESULT=$?
elif command -v wget >/dev/null 2>&1; then
    wget -q -O - --post-data="chat_id=$CHAT_ID&text=$TEXT&parse_mode=Markdown" \
        "$TELEGRAM_URL" > /dev/null 2>&1
    RESULT=$?
else
    echo "Error: Neither curl nor wget is available"
    exit 1
fi

if [[ $RESULT -eq 0 ]]; then
    echo "Telegram notification sent successfully"
    exit 0
else
    echo "Failed to send Telegram notification"
    exit 1
fi 
