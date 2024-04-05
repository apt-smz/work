#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <interface_selected> <TARGET_SSID> <user_input_password>"
    exit 1
fi

# Assign arguments to variables
interface_selected="$1"
target_ssid="$2"
user_input_password="$3"

# Extract the MAC address and format it for use with 'wlx' prefix
interface_wlx=$(ip link show $interface_selected | awk '/link\/ieee802.11\/radiotap/ {print $2}' | sed 's/://g' | awk '{print "wlx"$1}')


#pause
sleep 2

# Bring down the interface
sudo ifconfig $interface_selected down

#pause
sleep 5

# Change the MAC address randomly
sudo macchanger -r $interface_wlx

#pause
sleep 5

# Set the interface to be managed by NetworkManager
sudo nmcli device set $interface_wlx managed true

#pause
sleep 5

# Connect to the target SSID with the provided password
sudo nmcli device wifi connect $target_ssid password $user_input_password ifname $interface_wlx && \
GATEWAY_IP=$(ip route show dev $interface_wlx | grep 'default via' | awk '{print $3}') && \
sudo ip route replace default via $GATEWAY_IP dev $interface_wlx metric 600 && \
echo "IP Address for $interface_wlx:" && \
ip addr show $interface_wlx | grep 'inet ' | awk '{print $2}'