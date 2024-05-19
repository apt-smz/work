#!/bin/bash

# Function to get connected WiFi network SSID
get_wifi_ssid() {
    iwconfig 2>/dev/null | grep -o 'ESSID:"[^"]*' | sed 's/ESSID:"//'
}

# Function to get the IP address of the wireless interface
get_ip_address() {
    ip a | grep 'wlx' | grep -oP 'inet \K[\d.]+/\d+' | head -n 1
}

# Function to create a directory based on the WiFi SSID
create_directory() {
    local base_directory="/home/$REAL_USER/src/work"
    local wifi_ssid=$(get_wifi_ssid)
    if [ -n "$wifi_ssid" ]; then
        local directory_name=$(echo "$wifi_ssid" | tr -d '[:space:]')
        mkdir -p "$base_directory/$directory_name" 2>/dev/null
        echo "$base_directory/$directory_name"
    fi
}

# Function to get host IP information for the wireless interface only
get_host_ip_info() {
    local wifi_interface=$(ip route | grep -o 'wlx[^ ]*' | awk '{print $1}' | sort -u)
    nmcli dev show "$wifi_interface" | grep -E 'GENERAL.DEVICE|IP4.ADDRESS|IP4.GATEWAY|IP4.DNS'
}

# Function to discover hosts on the network
discover_hosts() {
    local ip_address=$1
    sudo nmap -sn "$ip_address" | grep -oP '\d+\.\d+\.\d+\.\d+' >> scan 2>/dev/null
    sleep 5
    arp -a | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" >> scan 2>/dev/null
    local ip_base=$(echo "$ip_address" | grep -oP '\d+\.\d+\.\d+\.')
    grep "^$ip_base" scan | sort -u > list 2>/dev/null
    sort -u list -o list
    sed -i "/$(echo $ip_address | cut -d'/' -f1)/d" list
    cat list
    rm scan
}

# Function to perform Nmap scan based on user's choice
perform_nmap_scan() {
    local scan_choice="$1"
    case $scan_choice in
        1)
            echo "Performing Quick Nmap Scan..."
            sudo nmap -T4 -sS -F -Pn -iL list >> scanned_$timestamp
            ;;
        2)
            echo "Performing Standard Nmap Scan..."
            sudo nmap -T4 -sS -sV -Pn -iL list >> scanned_$timestamp
            ;;
        3)
            echo "Performing Intense Nmap Scan..."
            sudo nmap -T4 -A -Pn -iL list >> scanned_$timestamp
            ;;
        4)
            echo "Performing Comprehensive Nmap Scan..."
            sudo nmap -T5 -A -p- -Pn -iL list >> scanned_$timestamp
            ;;
        *)
            echo "Invalid option. Exiting."
            exit 1
            ;;
    esac
}

# Function to get the default gateway
get_default_gateway() {
    ip route | grep "wlx" | awk '/default/ { print $3 " " $4 " " $5 }'
}

# Function to get public IP address
get_public_ip() {
    curl -s --interface $(ip a | grep 'inet ' | grep 'wlx' | grep -oP 'wlx[a-fA-F0-9:]{12}') http://ifconfig.me
}

# Function to perform traceroute
perform_traceroute() {
    traceroute -i $(ip route | grep "wlx" | grep default | awk '{print $5}') 8.8.8.8 2>/dev/null
}

# Main script starts here
echo -e "\n\n\nStarting Basic Network Recon for $(get_wifi_ssid)"
echo -e "=============================\n\n"

# Assign command-line argument to variable
scan_choice="$1"

# Define the REAL_USER and directory path
REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
directory=$(create_directory)
wifi_ssid=$(get_wifi_ssid)
echo "Files are located in: $directory"
cd "$directory" || exit 1

# Get the timestamp for file names
timestamp=$(date +'%d-%b-%Y')

# Get your IP address
your_ip_address=$(get_ip_address)
host_ip_info=$(get_host_ip_info)

echo "Hosts info     (Your IP is: $your_ip_address)"
echo -e "============================\n"
echo "$host_ip_info" | tee "host_info_$timestamp"

# Discover hosts
echo -e "Discovered hosts"
echo "===================="
discover_hosts "$your_ip_address"

# Perform Nmap scan
echo -e "\n\n"
perform_nmap_scan "$scan_choice"

echo -e "\nScan completed."
echo "Results from scan"
cat "scanned_$timestamp"
echo " "

# Get and display default gateway (commented out)
#default_gateway=$(get_default_gateway)
#echo "Default Gateway: $default_gateway" | tee "$base_directory/$directory_name/default_gateway"
#echo " "

# Get public IP and display
public_ip=$(get_public_ip)
if [ -z "$public_ip" ]; then
    echo "Could not determine a public IP. This could be an airgapped network"
else
    echo "Your public IP address is: $public_ip" | tee "public_ip_$timestamp"
fi
echo " "

# Perform traceroute and display results
perform_traceroute | tee "traceroute_google_$timestamp"

# Completion message
echo " "
echo "SCAN OF $wifi_ssid COMPLETE"
echo "Log files are located in: $directory"
