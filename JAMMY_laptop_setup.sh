#!/bin/bash
#This script will setup an ubuntu 22.04 entire laptop for you.
#sudo the script from your regular user HOME DIRECTORY

#TODOS
#hcxdumptool setup and execute as a script in /usr/bin

#set the userpath variable
userpath=$(pwd)

#FIRST
apt update && upgrade -Y

#set up file_system for rest of installs and ops
cd $userpath
mkdir collection
mkdir src
mkdir upload
chown $USER:$USER src/
chown $USER:$USER collection/
chown $USER:$USER upload/

#depends and crits
apt install gcc git gpsd gpsd-clients net-tools rsync wireshark macchanger aircrack-ng haveged hostapd util-linux procps iproute2 iw dnsmasq iptables openrazer-meta

#a28git
cd $userpath/src
git clone https://github.com/apt-smz/work.git
chmod +x *.sh
cd $userpath

#wireguard
apt install wireguard jq resolvconf
chown $USER:$USER /etc/wireguard

#kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/jammy jammy main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
apt update
apt install kismet
mv $userpath/src/class/kismet_site.conf /etc/kismet/

#pmkid
apt install hcxdumptool

#hcxtools
apt install hcxtools

#HASHCAT
apt install hashcat

#wifite
apt install wifite

#WPS
apt -y install build-essential libpcap-dev pixiewps
cd $userpath/src
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/
cd src/
./configure
make
make install

#netrecon
apt install traceroute nmap

#wpa3
cd $userpath/src
sudo git clone https://github.com/oblique/create_ap.git
cd create_ap
make install

#alias
# example echo -e "\nalias cdear='cd | clear'" >> .bashrc
cd $userpath
echo -e "alias gps1='sudo dmesg | grep ttyUSB'" >> .bashrc
echo -e "alias gps2='sudo nano /etc/default/gpsd'" >> .bashrc
echo -e "alias gps3='sudo systemctl restart gpsd'" >> .bashrc
echo -e "alias site='sudo nano /etc/kismet/kismet_site.conf'" >> .bashrc
echo -e "alias wgup='sudo wg-quick up laptop-wg0'"  >> .bashrc
echo -e "alias wgdown='sudo wg-quick down laptop-wg0'"  >> .bashrc
source .bashrc

#FIXGPS
cd $userpath/src/work
chmod +x fixgps.sh
cp fixgps.sh /usr/bin/
cd ~

#create the service file
touch /etc/systemd/system/fixgps.service
chown $USER:$USER /etc/systemd/system/fixgps.service
#add the required fields to the service file
echo "[Unit]
Description=fixgps

[Service]
Type=forking
ExecStart=/usr/bin/fixgps.sh

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/fixgps.service

chown root:root /etc/systemd/system/fixgps.service

#MAKE THE TIMER
#create the service file
touch /etc/systemd/system/fixgps.timer
chown $USER:$USER /etc/systemd/system/fixgps.timer
#add the required fields to the service file

#fixgps.timer
echo "[Unit] 
Description=Runs the fixgps.service 10 seconds after boot up

[Timer] 
OnBootSec=10
Unit=fixgps.service 

[Install] 
WantedBy=basic.target" > /etc/systemd/system/fixgps.timer

chown root:root /etc/systemd/system/fixgps.timer

#Reload all systemd service files
systemctl daemon-reload

#start the timer service
systemctl enable fixgps.timer
