#!/bin/bash

#PI_SETUP
sudo apt update && sudo apt upgrade -y

#set the userpath variable
cd ~
userpath=$(pwd)
#$userpath

sudo apt install jq wireguard resolvconf gcc git net-tools gpsd gpsd-clients rsync
sudo apt install macchanger

#file_system
cd $userpath
mkdir src
mkdir collection
mkdir upload
sudo chown $USER:$USER src/
sudo chown $USER:$USER collection/
sudo chown $USER:$USER upload/

#a28git
cd $userpath/src
git clone https://github.com/a28-class/class.git
cd $userpath

#sixfab
cd $userpath/src
git clone https://github.com/sixfab/Sixfab_PPP_Installer.git

#aircrack
sudo apt install aircrack-ng

#kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | sudo apt-key add -
echo 'deb https://www.kismetwireless.net/repos/apt/release/buster buster main' | sudo tee /etc/apt/sources.list.d/kismet.list
sudo apt update
sudo apt install kismet
sudo mv $userpath/src/class/kismet_site.conf /etc/kismet/
cd ~

#wifite
sudo apt install wifite

#hcxdumptool
cd $userpath/src/
git clone https://github.com/ZerBea/hcxdumptool.git
sudo apt-get install libcurl4-openssl-dev libssl-dev pkg-config 
cd hcxdumptool
git checkout 6.2.5
make
sudo make install
cd $userpath

#wps
sudo apt -y install build-essential libpcap-dev aircrack-ng pixiewps
cd $userpath/src/
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/
cd src/
./configure
make
sudo make install
cd $userpath

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
sudo echo "dtoverlay=disable-wifi" >> /boot/config.txt

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


