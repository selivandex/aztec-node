#!/bin/bash
# SSH wrapper to auto-accept host keys
echo "yes" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=no "$@" 
