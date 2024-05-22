#!/bin/bash
#sets interface names to a good format
# Function to get the MAC address of a network interface
get_mac_address() {
    local interface=$1
    cat /sys/class/net/$interface/address
}

# Function to create udev rule
create_udev_rule() {
    local interface=$1
    local mac_address=$(get_mac_address $interface)
    local new_name="wlx${mac_address//:/}"

    echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$mac_address\", NAME=\"$new_name\"" | sudo tee -a /etc/udev/rules.d/70-persistent-net.rules > /dev/null
}

# Main script logic
main() {
    # Detect all wlan interfaces
    interfaces=$(ls /sys/class/net | grep -E 'wlan[0-9]+')

    for interface in $interfaces; do
        create_udev_rule $interface
    done

    # Reload udev rules
    sudo udevadm control --reload-rules
    # Trigger udev to apply new rules
    sudo udevadm trigger
}

# Run the main function
main
