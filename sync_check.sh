#!/bin/bash

# Simple wrapper script to run sync check from project root
# Redirects to the actual implementation in get_proof_playbook folder

exec bash "$(dirname "$0")/aztec_ansible/get_proof_playbook/run_sync_check.sh" "$@" 
