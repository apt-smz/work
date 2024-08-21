#!/bin/bash
# Setup script for Raspberry Pi 4 - FINCH
# Usage: FROM YOUR HOME DIRECTORY sudo ./setup.sh

# ASCII Art
echo ''
echo '  $$$$$$\  $$\   $$\ $$$$$$\ $$$$$$$\  $$\      $$\  $$$$$$\  $$$$$$$$\ $$$$$$$$\ '
echo ' $$  __$$\ $$ |  $$ |\_$$  _|$$  __$$\ $$$\    $$$ |$$  __$$\ \__$$  __|$$  _____|'
echo ' $$ /  \__|$$ |  $$ |  $$ |  $$ |  $$ |$$$$\  $$$$ |$$ /  $$ |   $$ |   $$ |      '
echo ' \$$$$$$\  $$$$$$$$ |  $$ |  $$$$$$$  |$$\$$\$$ $$ |$$$$$$$$ |   $$ |   $$$$$\    '
echo '  \____$$\ $$  __$$ |  $$ |  $$  ____/ $$ \$$$  $$ |$$  __$$ |   $$ |   $$  __|   '
echo ' $$\   $$ |$$ |  $$ |  $$ |  $$ |      $$ |\$  /$$ |$$ |  $$ |   $$ |   $$ |      '
echo ' \$$$$$$  |$$ |  $$ |$$$$$$\ $$ |      $$ | \_/ $$ |$$ |  $$ |   $$ |   $$$$$$$$\ '
echo '  \______/ \__|  \__|\______|\__|      \__|     \__|\__|  \__|   \__|   \________|'
echo ''

# Exit if not run as root
if [ "$(id -u)" != "0" ]; then
 echo "ERROR: This script must be run as root."
 exit 1
fi

# Configurable Variables
REAL_USER="finch"
USER_PATH="/home/$REAL_USER"
REPO_WORK="https://github.com/apt-smz/work.git"
REPO_SIXFAB="https://github.com/sixfab/Sixfab_PPP_Installer.git"
REPO_HCXDUMPTOOL="https://github.com/ZerBea/hcxdumptool.git"
REPO_MANA="https://github.com/sensepost/hostapd-mana.git"
REPO_BULLY="https://github.com/kimocoder/bully.git"
KISMET_CONFIG="/etc/kismet/kismet_site.conf"

# Function to install required packages
install_packages() {
 echo "Updating and installing packages..."
 apt update && apt upgrade -y

 # Preconfigure debconf settings for macchanger and wireshark-common
 echo "macchanger macchanger/dontautostart boolean true" | debconf-set-selections
 echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections

 DEBIAN_FRONTEND=noninteractive apt-get install -yq git make gcc nano netcat-traditional tcpdump jq wireguard scapy resolvconf libnl-genl-3-dev pip gcc net-tools hcxtools gpsd gpsd-clients rsync haveged hostapd util-linux procps iproute2 iw dnsmasq iptables aircrack-ng libcurl4-openssl-dev libssl-dev pkg-config build-essential libpcap-dev pixiewps traceroute nmap macchanger wifite wireshark-common
}

# Function to set up file system
setup_file_system() {
 echo "Setting up file system..."
 cd "$USER_PATH"
 mkdir -p src collection upload
 chown -R $REAL_USER:$REAL_USER src/ collection/ upload/
}

# Function to clone repositories
clone_repositories() {
 echo "Cloning repositories..."
 git clone "$REPO_WORK" "$USER_PATH/src/work"
 git clone "$REPO_SIXFAB" "$USER_PATH/src/Sixfab_PPP_Installer"
 git clone "$REPO_HCXDUMPTOOL" "$USER_PATH/src/hcxdumptool"
 git clone "$REPO_BULLY" "$USER_PATH/src/bully"
 git clone "$REPO_MANA" "$USER_PATH/src/hostapd-mana"
 chown -R $REAL_USER:$REAL_USER "$USER_PATH/src/work"
}

# Function to set up Kismet
setup_kismet() {
 echo "Setting up Kismet..."
 export DEBIAN_FRONTEND=noninteractive
 echo "kismet kismet/install-setuid boolean false" | debconf-set-selections
 wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
 echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
 apt update
 DEBIAN_FRONTEND=noninteractive apt-get install -yq kismet
 mv "$USER_PATH/src/work/kismet_site.conf" "$KISMET_CONFIG"
 unset DEBIAN_FRONTEND
 systemctl enable kismet.service
}

# Function to install and set up hcxdumptool
setup_hcxdumptool() {
 echo "Setting up hcxdumptool..."
 cd "$USER_PATH/src/hcxdumptool"
 make
 make install
}

# Function to install and set up Bully
setup_bully() {
 echo "Setting up bully..."
 cd "$USER_PATH/src/bully/src"
 make
 make install
}

# Function to install and set up hostapd_mana
setup_hostapd_mana() {
 echo "Setting up hostapd-mana..."
 cd "$USER_PATH/src/hostapd-mana"
 make -C hostapd
}

# Function to set up aliases
setup_aliases() {
 echo "Setting up aliases..."
 {
     echo "alias gps1='sudo dmesg | grep ttyUSB'"
     echo "alias gps2='sudo nano /etc/default/gpsd'"
     echo "alias gps3='sudo systemctl restart gpsd'"
     echo "alias site='sudo nano $KISMET_CONFIG'"
 } >> $USER_PATH/.bashrc
}

# Function to disable onboard WiFi
disable_onboard_wifi() {
 echo "Disabling onboard WiFi..."
 echo "dtoverlay=disable-wifi" >> /boot/firmware/config.txt
}

# Function to set up services
setup_services() {
 echo "Setting up services..."
 cd "$USER_PATH/src/work/"
 chmod +x fixgps.sh deauth.py eviltwin.sh associate.sh pcap_dl.sh full_scan.sh
 cp fixgps.sh /usr/bin/
 mkdir handshakes/ logs/
 sudo chown -R $REAL_USER:$REAL_USER handshakes/ logs/

 create_systemd_service "fixgps" "
[Unit]
Description=fixgps

[Service]
Type=forking
ExecStart=/usr/bin/fixgps.sh

[Install]
WantedBy=multi-user.target
"

 create_systemd_timer "fixgps" "
[Unit]
Description=Runs the fixgps.service 10 seconds after boot up

[Timer]
OnBootSec=10
Unit=fixgps.service

[Install]
WantedBy=basic.target
"

 sudo systemctl daemon-reload
 sudo systemctl enable fixgps.timer
}

# Function to disable MOTD and login banner
disable_motd_banner() {
 echo "Disabling MOTD and login banner..."

 # Backup original files
 sudo mv /etc/motd /etc/motd.bak
 sudo mv /etc/issue /etc/issue.bak
 sudo mv /etc/issue.net /etc/issue.net.bak

 # Create empty MOTD and banner files
 sudo touch /etc/motd
 sudo touch /etc/issue
 sudo touch /etc/issue.net

 # Disable dynamic MOTD scripts
 sudo chmod -x /etc/update-motd.d/*
}

# Function to set up udev rule and systemd service for interface renaming
setup_interface_monitor() {
 echo "Setting up interface renaming monitor..."

 # Create the setup_interfaces.sh script
 cat <<'EOF' | sudo tee /usr/local/bin/setup_interfaces.sh > /dev/null
#!/bin/bash

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

 # Check if the source already exists in kismet_site.conf
 if ! grep -q "source=$new_name" /etc/kismet/kismet_site.conf; then
     echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$mac_address\", NAME=\"$new_name\"" | sudo tee -a /etc/udev/rules.d/70-persistent-net.rules > /dev/null

     # Add the new interface name to kismet_site.conf
     echo "source=$new_name" | sudo tee -a /etc/kismet/kismet_site.conf > /dev/null
 fi
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
EOF

 # Make the setup_interfaces.sh script executable
 sudo chmod +x /usr/local/bin/setup_interfaces.sh

 # Create the udev rule
 echo 'SUBSYSTEM=="net", ACTION=="add", RUN+="/usr/local/bin/setup_interfaces.sh"' | sudo tee /etc/udev/rules.d/99-network-interface.rules > /dev/null

 # Create the systemd service file
 cat <<EOF | sudo tee /etc/systemd/system/network-interface-monitor.service > /dev/null
[Unit]
Description=Network Interface Monitor Service
After=network.target kismet.service

[Service]
Type=simple
ExecStart=/usr/local/bin/setup_interfaces.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

 # Create the check_kismon.sh script
 cat <<'EOF' | sudo tee /usr/local/bin/check_kismon.sh > /dev/null
#!/bin/bash

sleep 1

if ip link show kismon > /dev/null 2>&1; then
 echo "$(date): kismon interface found. No action needed." >> /var/log/check-kismon.log
else
 echo "$(date): kismon interface not found. Restarting Kismet." >> /var/log/check-kismon.log
 systemctl restart kismet.service
fi
EOF

 # Make the check_kismon.sh script executable
 sudo chmod +x /usr/local/bin/check_kismon.sh

 # Create the systemd service file to check for kismon and restart kismet if needed
 cat <<EOF | sudo tee /etc/systemd/system/check-kismon.service > /dev/null
[Unit]
Description=Check for kismon interface and restart Kismet if not found
After=kismet.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check_kismon.sh

[Install]
WantedBy=multi-user.target
EOF

 # Reload systemd to recognize the new services
 sudo systemctl daemon-reload
 # Enable the services to start on boot
 sudo systemctl enable network-interface-monitor.service
 sudo systemctl enable check-kismon.service
 # Start the services
 sudo systemctl start network-interface-monitor.service
 sudo systemctl start check-kismon.service
}

# Function to set up systemd service and timer to restart Kismet at 59th minute of every hour
setup_kismet_restart_timer() {
 echo "Setting up Kismet restart timer..."

 # Create the systemd service file
 cat <<EOF | sudo tee /etc/systemd/system/restart_kismet.service > /dev/null
[Unit]
Description=Restart Kismet Service

[Service]
ExecStart=/bin/systemctl restart kismet
EOF

 # Create the systemd timer file
 cat <<EOF | sudo tee /etc/systemd/system/restart_kismet.timer > /dev/null
[Unit]
Description=Timer to Restart Kismet at the 59th Minute of Every Hour

[Timer]
OnCalendar=*:59
Persistent=true
Unit=restart_kismet.service

[Install]
WantedBy=timers.target
EOF

 # Reload systemd to recognize the new service and timer
 sudo systemctl daemon-reload
 # Enable and start the timer
 sudo systemctl enable restart_kismet.timer
 sudo systemctl start restart_kismet.timer
}

# Helper functions to create systemd services and timers
create_systemd_service() {
 local service_name=$1
 local service_content=$2
 echo "$service_content" | sudo tee /etc/systemd/system/$service_name.service > /dev/null
}

create_systemd_timer() {
 local timer_name=$1
 local timer_content=$2
 echo "$timer_content" | sudo tee /etc/systemd/system/$timer_name.timer > /dev/null
}

# Main script execution
main() {
 install_packages
 setup_file_system
 clone_repositories
 setup_kismet
 setup_hcxdumptool
 setup_bully
 setup_hostapd_mana
 setup_aliases
 disable_onboard_wifi
 setup_services
 disable_motd_banner
 setup_interface_monitor
 setup_kismet_restart_timer

 # Start Kismet service after setting up the interface monitor
 systemctl enable kismet.service
 systemctl start kismet.service
}

main
