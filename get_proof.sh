#!/bin/bash

# Simple wrapper script to run get_proof from project root
# Usage: ./get_proof.sh [options]

cd "$(dirname "$0")/aztec_ansible/get_proof_playbook"
exec ./run_get_proof.sh "$@" 
