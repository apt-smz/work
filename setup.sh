#!/bin/bash
#GITADDS
#kismet_site.conf 
#sixfab
#wireguard.sh

#FIRST
sudo apt update && upgrade -Y

#file_system
mkdir collection
mkdir src
mkdir scripts

#depends and crits
sudo apt install gcc git gpsd gpsd-clients reaver 
sudo apt install wireshark 
sudo apt install macchanger 
sudo apt install aircrack-ng 

#wireguard
sudo apt install wireguard jq resolvconf
sudo chown user:user /etc/wireguard

#kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | sudo apt-key add -
echo 'deb https://www.kismetwireless.net/repos/apt/release/jammy jammy main' | sudo tee /etc/apt/sources.list.d/kismet.list
sudo apt update
sudo apt install kismet

#pmkid
sudo apt install hcxdumptool

#hcxtools
sudo apt install hcxtools

#HASHCAT
sudo apt install hashcat

#wifite
sudo apt install wifite

#netrecon
sudo apt install traceroute nmap
