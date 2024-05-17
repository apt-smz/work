#!/bin/bash
echo -e "\n\n\nStarting Basic Network Recon\n\n"

# Define the REAL_USER and directory path
REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
base_directory="/home/$REAL_USER/src/work"

# Function to get connected WiFi network SSID
get_wifi_ssid() {
    iwconfig 2>/dev/null | grep -o 'ESSID:"[^"]*' | sed 's/ESSID:"//'
}

# Create directory based on WiFi SSID
wifi_ssid=$(get_wifi_ssid)
if [ -n "$wifi_ssid" ]; then
    directory_name=$(echo "$wifi_ssid" | tr -d '[:space:]') # Remove spaces from SSID
    mkdir -p "$base_directory/$directory_name" 2>/dev/null # Suppress error
    echo "Files are located in: $base_directory/$directory_name"
    cd "$base_directory/$directory_name" || exit 1
fi

echo -e "\nTarget network SSID: $directory_name"
your_ip_address=$(ip a | grep 'wlx' | grep -oP 'inet \K[\d.]+/\d+' | head -n 1)
echo "Hosts    (Your IP is: $your_ip_address)"

# Extract hosts using nmap and redirect output to files in the directory
sudo nmap -sn $(ip a | grep 'wlx' | grep -oP 'inet \K[\d.]+/\d+' | head -n 1) | grep -oP '\d+\.\d+\.\d+\.\d+' >> scan 2>/dev/null
sleep 5
arp -a | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" >> scan 2>/dev/null
ip_address=$(ip a | grep 'wlx' | grep -oP 'inet \K[\d.]+/\d+' | head -n 1 | grep -oP '\d+\.\d+\.\d+\.' | sed 's/\./\\\./g')
grep "^$ip_address" scan | sort -u > list 2>/dev/null
sort -u list -o list

echo "===================="
cat list
rm scan
echo -e "Port scan started..."

# Run nmap command and redirect output to scanned file in the directory
sudo nmap -sS -Pn -iL list >> scanned 2>/dev/null &
NMAP_PID=$!

# Wait for nmap to finish
while kill -0 $NMAP_PID >/dev/null 2>&1; do
    echo -n " "
    sleep 1
done
echo ""
echo "Scan completed."
echo "Results from scan"

cat scanned
echo ""

# Add default gateway to the list
default_gateway=$(ip route | grep "wlx" | awk '/default/ { print $3 " " $4 " " $5 }')
echo "Default Gateway: $default_gateway" | tee "$base_directory/$directory_name/default_gateway"
echo " "

# Get public IP using curl
public_ip=$(curl -s --interface $(ip a | grep 'inet ' | grep 'wlx' | grep -oP 'wlx[a-fA-F0-9:]{12}') http://ifconfig.me 2>/dev/null)

# Check if public_ip is empty
if [ -z "$public_ip" ]; then
    echo "Could not determine a public IP. This could be an airgapped network"
else
    # Display the result
    echo "Your public IP address is: $public_ip" | tee "$base_directory/$directory_name/public_ip"
fi
echo " "

# Perform traceroute and display results with wlx interface
traceroute -i $(ip route | grep "wlx" | grep default | awk '{print $5}') 8.8.8.8 2>/dev/null | tee "$base_directory/$directory_name/traceroute_google"

echo " "
echo " "
echo "FINISHED"
