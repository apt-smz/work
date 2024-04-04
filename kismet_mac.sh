#!/bin/bash

# Check if there are any interfaces with 'kismon' in their name
if ! /sbin/ip link show | grep -q 'kismon'; then
    # No kismon interfaces found, restart Kismet
    systemctl restart kismet
fi
