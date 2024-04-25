#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <interface_selected> <AP_ssid> <channel> <AP_MAC> <security_mode> [wpa_passphrase]"
    echo "security_mode options: WPA, WPA2, OPEN, EAP"
    exit 1
}

# Check minimum required arguments
if [ "$#" -lt 5 ]; then
    usage
fi

# Assign command-line arguments to variables
interface_selected="$1"
AP_ssid="$2"
channel="$3"
AP_MAC="$4"
security_mode=$(echo "$5" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase for case-insensitive comparison
wpa_passphrase="${6:-}"  # Optional passphrase argument

# Determine the real user's home directory
real_user=$(logname 2>/dev/null || echo $SUDO_USER)
work_dir="/home/$real_user/src/work"
mkdir -p "$work_dir"
log_file="$work_dir/$AP_ssid-mana.log"
unique_macs_file="$work_dir/$AP_ssid.macs"

# Make interface predictable name
interface_wlx=$(ip link show $interface_selected | awk '/link\/ieee802.11\/radiotap/ {print $2}' | sed 's/://g' | awk '{print "wlx"$1}')


#pause
sleep 5

# Get the interface up and ready
sudo ifconfig $interface_wlx up

#pause
sleep 5

# Define certificate paths
certs_dir="/etc/hostapd/certs"
mkdir -p "$certs_dir"
ca_key="$certs_dir/ca.key"
ca_cert="$certs_dir/ca.crt"
server_key="$certs_dir/server.key"
server_csr="$certs_dir/server.csr"
server_cert="$certs_dir/server.crt"
eap_user_file="$certs_dir/eap_user_file"

# Generate CA and server certificates
generate_certs() {
    echo "Generating certificates..."
    openssl genrsa -out "$ca_key" 2048
    openssl req -new -x509 -days 3650 -key "$ca_key" -out "$ca_cert" -subj "/C=US/ST=State/L=City/O=Organization/CN=RootCA"
    openssl genrsa -out "$server_key" 2048
    openssl req -new -key "$server_key" -out "$server_csr" -subj "/C=US/ST=State/L=City/O=Organization/CN=$AP_ssid"
    openssl x509 -req -in "$server_csr" -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial -out "$server_cert" -days 3650
}

# Create the EAP user file
create_eap_user_file() {
    cat <<EOF > "$eap_user_file"
# Phase 1 authentication methods
* PEAP
* TTLS
* TLS
# Phase 2 authentication for user "user"
"user" TLS
"user" MD5 "password"
EOF
}

# Configure security settings
setup_security() {
    case "$security_mode" in
        wpa|wpa2)
            setup_wpa "$wpa_passphrase"
            ;;
        open)
            setup_open
            ;;
        eap)
            setup_eap
            ;;
        *)
            echo "Invalid security mode selected."
            exit 1
            ;;
    esac
}

# Configure WPA/WPA2, Open, and EAP with their respective settings
setup_wpa() {
    if [ -z "$1" ]; then
        echo "Error: WPA passphrase required for WPA/WPA2 security."
        exit 1
    fi
    cat <<EOF >> "$config_file"
wpa=3
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
wpa_passphrase=$1
EOF
}

setup_open() {
    echo "auth_algs=1" >> "$config_file"
}

setup_eap() {
    generate_certs
    create_eap_user_file
    cat <<EOF >> "$config_file"
eap_server=1
eap_user_file=$eap_user_file
ca_cert=$ca_cert
server_cert=$server_cert
private_key=$server_key
EOF
}

# Create base hostapd configuration
config_file="/etc/hostapd/hostapd.conf"
cat <<EOF > "$config_file"
interface=$interface_wlx
ssid=$AP_ssid
channel=$channel
hw_mode=g
bssid=$AP_MAC
auth_algs=1
EOF

# Configure logging
echo "logger_syslog=-1" >> "$config_file"
echo "logger_syslog_level=2" >> "$config_file"
echo "logger_stdout=-1" >> "$config_file"
echo "logger_stdout_level=2" >> "$config_file"

# Get the interface up and ready
sudo ifconfig "$interface_wlx" up
setup_security  # Apply security settings based on mode

# Function to extract unique MAC addresses and save to a file named after the AP_ssid
extract_and_save_macs() {
    grep -v 'Using interface' "$log_file" | grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | sort | uniq > "$unique_macs_file"
    echo "MAC extraction completed, saved to $unique_macs_file" >> "$log_file"
}

# Trap SIGINT (Ctrl+C) and SIGTERM
trap 'extract_and_save_macs; sudo kill $!; exit' SIGINT SIGTERM

# Start hostapd and redirect output to log file
echo "Starting hostapd with configuration:" >> "$log_file"
cat "$config_file" >> "$log_file"
sudo hostapd "$config_file" | tee -a "$log_file" &

wait # Wait indefinitely until the hostapd process exits or is killed

# Cleanup actions after hostapd exits
extract_and_save_macs
sudo kill $!  # Ensure the hostapd process is terminated
echo "Hostapd has been stopped." >> "$log_file"
