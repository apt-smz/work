#!/bin/bash

REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)

# Check if the correct number of arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <interface_selected> '<TARGET_SSID>' '<user_input_password>' '<user_input_mac>' '<user_input_hostname>'"
    exit 1
fi

# Assign arguments to variables
interface_selected="$1"
target_ssid="$2"
user_input_password="$3"
user_input_mac="$4"
user_input_hostname="$5"

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
sleep 9

# Change the MAC for association
echo "Setting MAC in preparation of Network Association:"
macchanger -m $user_input_mac $interface_wlx
echo ""

# Pause
sleep 5

# Save the current hostname before changing it
current_hostname=$(hostname)
echo "Current hostname is $current_hostname, changing to $user_input_hostname"

# Log the current hostname to a file
echo "$current_hostname" > /home/$REAL_USER/src/work/logs/hostname_history.txt

# Change the Hostname
sudo hostnamectl set-hostname $user_input_hostname

sleep 5

# Set the interface to be managed by NetworkManager
echo ""
echo "Taking control of established interface."
echo ""
nmcli device set $interface_wlx managed true

# Pause
sleep 5
echo "Establishing Connection to Target Network:"
echo ""

# Connect to the target SSID with the provided password
if nmcli device wifi connect "$target_ssid" password "$user_input_password" ifname $interface_wlx; then
    # Get the current gateway IP for the wlx interface
    GATEWAY_IP=$(ip route show dev $interface_wlx | grep 'default via' | awk '{print $3}')

    # Remove any existing default route for the wlx interface
    sudo ip route del default dev $interface_wlx

    # Set the default route for wlx with a high metric (e.g., 2000) to make it lower priority
    sudo ip route add default via $GATEWAY_IP dev $interface_wlx metric 2000

    # Get and display the assigned IP address
    IP_ADDRESS=$(ip addr show $interface_wlx | grep 'inet ' | awk '{print $2}')
    printf "\nSuccess: Connected to %s\n\n" "$target_ssid"
    printf "IP Address for %s: %s\n\n" "$interface_wlx" "$IP_ADDRESS"
    printf "Gateway IP: %s\n\n" "$GATEWAY_IP"

    # Print IP route info for all interfaces
    echo "IP Route Info:"
    ip route

    # Log connection information
    {
        echo "Connection to $target_ssid"
        echo "IP Address for $interface_wlx: $IP_ADDRESS"
        echo "Gateway IP: $GATEWAY_IP"
        echo "IP Route Info:"
        ip route
    } > /home/$REAL_USER/src/work/logs/$target_ssid_connection_log.txt
else
    printf "\n\e[1mError:\e[0m Failed to connect to %s\n\n" "$target_ssid"
fi
