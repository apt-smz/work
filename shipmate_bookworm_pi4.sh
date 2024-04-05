#!/bin/bash
# Setup script for Raspberry Pi 4 - Wireless Analysis Tools
# Usage: sudo ./setup_pi4_wireless_analysis.sh

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
REAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
USER_PATH=$(pwd)
REPO_WORK="https://github.com/apt-smz/work.git"
REPO_SIXFAB="https://github.com/sixfab/Sixfab_PPP_Installer.git"
REPO_HCXDUMPTOOL="https://github.com/ZerBea/hcxdumptool.git"
REPO_MANA="https://github.com/sensepost/hostapd-mana.git
REPO_BULLY="https://github.com/kimocoder/bully.git"
REPO_CREATE_AP="https://github.com/oblique/create_ap.git"
KISMET_CONFIG="/etc/kismet/kismet_site.conf"

# Function to install required packages
install_packages() {
    echo "Updating and installing packages..."
    apt update && apt upgrade -y
    apt-get install -yq git
    apt-get install -yq jq wireguard scapy resolvconf libnl-genl-3-dev pip gcc net-tools gpsd gpsd-clients rsync haveged hostapd util-linux procps iproute2 iw dnsmasq iptables aircrack-ng libcurl4-openssl-dev libssl-dev pkg-config build-essential libpcap-dev pixiewps traceroute nmap macchanger wifite
     
}

# Function to set up file system
setup_file_system() {
    echo "Setting up file system..."
    cd "$USER_PATH"
    mkdir -p src collection upload
    sudo chown -R $REAL_USER src/ collection/ upload/
}

# Function to clone repositories
clone_repositories() {
    echo "Cloning repositories..."
    git clone "$REPO_WORK" "$USER_PATH/src/work"
    chmod +x "$USER_PATH/src/work/deauth.py"
    cp "$USER_PATH/src/work/deauth.py" $USER_PATH
    git clone "$REPO_SIXFAB" "$USER_PATH/src/Sixfab_PPP_Installer"
    git clone "$REPO_HCXDUMPTOOL" "$USER_PATH/src/hcxdumptool"
    git clone "$REPO_BULLY" "$USER_PATH/src/bully"
    git clone "$REPO_CREATE_AP" "$USER_PATH/src/create_ap"
}

# Function to set up Kismet
setup_kismet() {
    echo "Setting up Kismet..."
    export DEBIAN_FRONTEND=noninteractive
    echo "kismet kismet/install-setuid boolean false" | debconf-set-selections
    wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
    apt update
    apt-get install -yq kismet
    mv "$USER_PATH/src/work/kismet_site.conf" "$KISMET_CONFIG"
    unset DEBIAN_FRONTEND
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
    echo "Setting up Bully..."
    cd "$USER_PATH/src/bully/src"
    make
    make install
}

# Function to install and set up create_ap
setup_create_ap() {
    echo "Setting up create_ap..."
    cd "$USER_PATH/src/create_ap"
    make install
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
    echo "dtoverlay=disable-wifi" >> /boot/config.txt
}

# Function to set up services
setup_services() {
    echo "Setting up services..."
    cd "$USER_PATH/src/work/"
    chmod +x fixgps.sh kismet_mac.sh
    cp fixgps.sh /usr/bin/
    cp kismet_mac.sh /usr/bin/

    {
        echo "[Unit]"
        echo "Description=fixgps"
        echo ""
        echo "[Service]"
        echo "Type=forking"
        echo "ExecStart=/usr/bin/fixgps.sh"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    } > /etc/systemd/system/fixgps.service

    {
        echo "[Unit]"
        echo "Description=Runs the fixgps.service 10 seconds after boot up"
        echo ""
        echo "[Timer]"
        echo "OnBootSec=10"
        echo "Unit=fixgps.service"
        echo ""
        echo "[Install]"
        echo "WantedBy=basic.target"
    } > /etc/systemd/system/fixgps.timer

    {
        echo "[Unit]"
        echo "Description=Disable USB Wi-Fi interfaces and randomize MAC addresses and start kismet"
        echo ""
        echo "[Service]"
        echo "Type=oneshot"
        echo "ExecStart=/usr/bin/kismet_mac.sh"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
    } > /etc/systemd/system/kismet_mac.service

    systemctl daemon-reload
    systemctl enable fixgps.timer
    systemctl enable kismet_mac.service

}

# Function to configure Raspberry Pi settings
configure_raspi() {
    echo "Configuring Raspberry Pi settings..."
    
    # Set the environment variable for non-interactive mode
    export RASPI_CONFIG_NONINT=1
    
    # Enable predictable network interface names
    raspi-config nonint do_net_names 0
}
# Main script execution
main() {
    install_packages
    setup_file_system
    clone_repositories
    setup_kismet
    setup_hcxdumptool
    setup_bully
    setup_create_ap
    setup_aliases
    disable_onboard_wifi
    setup_services
    configure_raspi
}
main
