#!/bin/bash
#critical script for fixing your GPS moving around USBs
#can bind as an alias or use the service setup script to run standalone

#setuserpath
userpath=$(pwd)

touch .gpsUSB
dmesg | grep usb | grep "pl2303 converter" > .gpsUSB

#to print 7 characters starting from the 8th-last character and add to the $GPS variable:
GPS=$(awk '{print substr($0,length($0)-6,7)}' .gpsUSB )

#change config to match
echo "# Start the gpsd daemon automatically at boot time
START_DAEMON="true"
# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="true"
# Devices gpsd should collect to at boot time.
# IF YOU SEE THIS LINE THE SERVICE IS WORKING.
DEVICES="/dev/$GPS"
# Other options you want to pass to gpsd
GPSD_OPTIONS="-n -G -b"
GPSD_SOCKET="/var/run/gpsd.sock"" > /etc/default/gpsd

systemctl restart gpsd

