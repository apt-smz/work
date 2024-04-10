#!/bin/bash

REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)

# Check if the correct number of arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <interface_selected> '<TARGET_SSID>' '<user_input_password>' '<user_input_mac>' "
    exit 1
fi

# Assign arguments to variables
interface_selected="$1"
target_ssid="$2"
user_input_password="$3"
user_input_mac="$4"

# Extract the MAC address and format it for use with 'wlx' prefix
interface_wlx=$(ip link show $interface_selected | awk '/link\/ieee802.11\/radiotap/ {print $2}' | sed 's/://g' | awk '{print "wlx"$1}')

# Pause
echo ""
echo "Connection to target network process STARTED."
echo ""
sleep 5

# Bring down the interface
sudo ifconfig $interface_selected down

# Pause
echo "Bringing down kismet controlled interface."
echo ""
sleep 5

# Change the MAC for association
echo "Setting MAC in preperation of Network Association:"
sudo macchanger -m $user_input_mac $interface_wlx

# Pause
sleep 5

# Set the interface to be managed by NetworkManager
echo ""
echo "Taking control of established interface."
echo ""
sudo nmcli device set $interface_wlx managed true

# Pause
sleep 5
echo "Establishing Connection to Target Network:"
echo ""

# Connect to the target SSID with the provided password
# Connect to the target SSID with the provided password
if sudo nmcli device wifi connect "$target_ssid" password "$user_input_password" ifname $interface_wlx; then
    GATEWAY_IP=$(ip route show dev $interface_wlx | grep 'default via' | awk '{print $3}')
    sudo ip route replace default via $GATEWAY_IP dev $interface_wlx metric 600
    IP_ADDRESS=$(ip addr show $interface_wlx | grep 'inet ' | awk '{print $2}')
    printf "\n\e[1mSuccess:\e[0m Connected to %s\n\n" "$target_ssid"
    printf "\e[1mIP Address for %s:\e[0m %s\n\n" "$interface_wlx" "$IP_ADDRESS"
    printf "\e[1mGateway IP:\e[0m %s\n\n" "$GATEWAY_IP"

    # Print IP route info for all interfaces
    echo -e "\e[1mIP Route Info:\e[0m"
    ip route

    # Log connection information
    {
        echo "Connection to $target_ssid"
        echo "IP Address for $interface_wlx: $IP_ADDRESS"
        echo "Gateway IP: $GATEWAY_IP"
        echo "IP Route Info:"
        ip route
    } > /home/pi/$target_ssid_connection_log.txt
else
    printf "\n\e[1mError:\e[0m Failed to connect to %s\n\n" "$target_ssid"
fi
