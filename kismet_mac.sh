#!/bin/bash

# Function to check if kismon interface exists
check_kismon() {
    if ! /sbin/ip link show kismon &> /dev/null; then
        systemctl restart kismet.service
        logger "kismet_mac.sh: Restarted Kismet service because kismon interface was not found."
    fi
}

# Check kismon interface
check_kismon
