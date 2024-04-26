#!/bin/bash

# Fix the user
REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)

# Check if the correct number of arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 '<kismet_login>' '<kismet_pass>' '<target_ssid>' '<target_key>' '<target_mac>' "
    exit 1
fi

# Assign arguments to variables
kismet_login="$1"
kismet_password="$2"
target_ssid="$3"
target_key="$4"
target_mac="$5"

# Download the pcap file using curl
curl -u "$kismet_login":"$kismet_password" -o "/home/$REAL_USER/src/work/handshakes/${target_ssid}.${target_mac}.handshake.pcap" "http://0.0.0.0:2501/phy/phy80211/by-key/$target_key/device/$target_mac/pcap/handshake.pcap"

# Convert the pcap file to hash format using hcxpcapngtool
hcxpcapngtool -o "/home/$REAL_USER/src/work/handshakes/${target_ssid}.${target_mac}.handshake.hash" "/home/$REAL_USER/src/work/handshakes/${target_ssid}.${target_mac}.handshake.pcap"

# Check if the hash file was created successfully
if [ -f "/home/$REAL_USER/src/work/handshakes/${target_ssid}.${target_mac}.handshake.hash" ]; then
    echo "Success: hash file was created for $target_ssid."
else
    echo "Error: hash file not created."
fi
