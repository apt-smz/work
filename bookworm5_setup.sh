#!/bin/bash
#setsup an entire PI for you.
#sudo the script from your regular user HOME DIRECTORY

#PI_SETUP
apt update && apt upgrade -y

#set the userpath variable
userpath=$(pwd)

#Requirements
apt install jq wireguard resolvconf gcc git net-tools gpsd gpsd-clients rsync macchanger haveged hostapd util-linux procps iproute2 iw dnsmasq iptables
pip install scapy

#file_system
cd $userpath
mkdir src
mkdir collection
mkdir upload
chown $USER:$USER src/
chown $USER:$USER collection/
chown $USER:$USER upload/

#a28git
cd $userpath/src
git clone https://github.com/apt-smz/work.git
chmod +x *.sh
cd $userpath

#sixfab
cd $userpath/src
git clone https://github.com/sixfab/Sixfab_PPP_Installer.git

#aircrack
apt install aircrack-ng

#kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
sudo apt update
sudo apt install kismet
mv $userpath/src/work/kismet_site.conf /etc/kismet/
cd $userpath

#wifite
apt install wifite

#hcxdumptool
cd $userpath/src/
git clone https://github.com/ZerBea/hcxdumptool.git
apt-get install libcurl4-openssl-dev libssl-dev pkg-config 
cd hcxdumptool
git checkout 6.2.5
make
make install
cd $userpath

#wps
apt -y install build-essential libpcap-dev aircrack-ng pixiewps
cd $userpath/src/
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/
cd src/
./configure
make
make install
cd $userpath
cd $userpath/src/
git clone https://github.com/kimocoder/bully.git
cd bully/src
make
make install

#netrecon
apt install traceroute nmap

#wpa3
cd $userpath/src
git clone https://github.com/oblique/create_ap.git
cd create_ap
make install

#alias
# example echo -e "\nalias cdear='cd | clear'" >> .bashrc
cd $userpath
echo -e "alias gps1='sudo dmesg | grep ttyUSB'" >> .bashrc
echo -e "alias gps2='sudo nano /etc/default/gpsd'" >> .bashrc
echo -e "alias site='sudo nano /etc/kismet/kismet_site.conf'" >> .bashrc

#HCXEXMODE
#echo -e "alias hcx='sudo ifconfig wlx00c0cab21e1c down && sudo macchanger -r wlx00c0cab21e1c && sudo iwconfig wlx00c0cab21e1c mode monitor && sudo ifconfig wlx00c0cab21e1c up'

source .bashrc

#disable onboard wifi
echo "dtoverlay=disable-wifi" >> /boot/config.txt

#FIXGPS
cd $userpath/src/work/
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
