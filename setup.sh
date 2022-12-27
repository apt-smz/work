#!/bin/bash
#username needs to be user right now
#hcxdumptool setup as a script in /usr/bin

#set the userpath variable
cd ~
userpath=$(pwd)

#FIRST
sudo apt update && upgrade -Y



#set up file_system for rest of installs and ops
cd $userpath
mkdir collection
mkdir src
mkdir upload
sudo chown $USER:$USER src/
sudo chown $USER:$USER collection/
sudo chown $USER:$USER upload/

#depends and crits
sudo apt install gcc git gpsd gpsd-clients net-tools rsync
sudo apt install wireshark 
sudo apt install macchanger 
sudo apt install aircrack-ng 

#a28git
cd ~/src
git clone https://github.com/a28-class/class.git
cd ~

#wireguard
sudo apt install wireguard jq resolvconf
sudo chown $USER:$USER /etc/wireguard

#kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | sudo apt-key add -
echo 'deb https://www.kismetwireless.net/repos/apt/release/jammy jammy main' | sudo tee /etc/apt/sources.list.d/kismet.list
sudo apt update
sudo apt install kismet
sudo mv $userpath/src/class/kismet_site.conf /etc/kismet/
cd ~

#pmkid
sudo apt install hcxdumptool

#hcxtools
sudo apt install hcxtools

#HASHCAT
sudo apt install hashcat

#wifite
sudo apt install wifite

#WPS
sudo apt -y install build-essential libpcap-dev pixiewps
cd $userpath/src
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/
cd src/
./configure
make
sudo make install
cd ~

#netrecon
sudo apt install traceroute nmap

#alias
# example echo -e "\nalias cdear='cd | clear'" >> .bashrc
cd $userpath
echo -e "alias gps1='sudo dmesg | grep ttyUSB'" >> .bashrc
echo -e "alias gps2='sudo nano /etc/default/gpsd'" >> .bashrc
echo -e "alias site='sudo nano /etc/kismet/kismet_site.conf'" >> .bashrc
echo -e "alias wgup='sudo wg-quick up laptop-wg0'"  >> .bashrc
echo -e "alias wgdown='sudo wg-quick down laptop-wg0'"  >> .bashrc

#HCXEXMODE
#echo -e "alias hcx='sudo ifconfig wlx00c0cab21e1c down && sudo macchanger -r wlx00c0cab21e1c && sudo iwconfig wlx00c0cab21e1c mode monitor && sudo ifconfig wlx00c0cab21e1c up'

source .bashrc

#FIXGPS
#FIXGPS
cd $userpath/src/class
sudo chmod +x fixgps.sh
sudo cp fixgps.sh /usr/bin/
cd ~

#create the service file
sudo touch /etc/systemd/system/fixgps.service
sudo chown $USER:$USER /etc/systemd/system/fixgps.service
#add the required fields to the service file
sudo echo "[Unit]
Description=fixgps

[Service]
Type=forking
ExecStart=/usr/bin/fixgps.sh

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/fixgps.service

#MAKE THE TIMER
#create the service file
sudo touch /etc/systemd/system/fixgps.timer
sudo chown $USER:$USER /etc/systemd/system/fixgps.timer
#add the required fields to the service file

# fixgps.timer
sudo echo "[Unit] 
Description=Runs the fixgps.service 10 seconds after boot up

[Timer] 
OnBootSec=10
Unit=fixgps.service 

[Install] 
WantedBy=basic.target" > /etc/systemd/system/fixgps.timer

#Reload all systemd service files
sudo systemctl daemon-reload

#start the timer service
sudo systemctl enable fixgps.timer
