#!/bin/bash

# Function to check if kismon interface exists
check_kismon() {
    if ! /sbin/ip link show kismon &> /dev/null; then
        systemctl restart kismet.service
    fi
}

# Check kismon interface
check_kismon
