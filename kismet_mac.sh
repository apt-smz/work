#!/bin/bash
#this is a one shot at boot to make sure kismet starts bookworm is being funky with mediatek

# Check if there are any interfaces with 'kismon' in their name
if ! /sbin/ip link show | grep -q 'kismon'; then
    # No kismon interfaces found, restart Kismet
    systemctl restart kismet
fi
