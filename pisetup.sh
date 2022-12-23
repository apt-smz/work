#/bin/bash

#PI_SETUP
sudo apt update && sudo apt upgrade -y
sudo apt install jq wireguard resolvconf gcc git net-tools

#file_system
mkdir src
mkdir collection


#sixfab
git clone https://github.com/sixfab/Sixfab_PPP_Installer.git


#aircrack
sudo apt install aircrack-ng


#kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | sudo apt-key add -
echo 'deb https://www.kismetwireless.net/repos/apt/release/buster buster main' | sudo tee /etc/apt/sources.list.d/kismet.list
sudo apt update
sudo apt install kismet


#wifite
sudo apt install wifite

#hcxdumptool
cd src
git clone https://github.com/ZerBea/hcxdumptool.git
sudo apt-get install libcurl4-openssl-dev libssl-dev pkg-config 
cd hcxdumptool
git checkout 6.2.5
make
sudo make install

#wps
sudo apt -y install build-essential libpcap-dev aircrack-ng pixiewps
cd src
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x/
cd src/
./configure
make
sudo make install
cd ~
