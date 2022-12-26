#!/bin/bash
#findgps

dmesg | grep usb | grep "pl2303 converter" > .gpsUSB

#add the ttyUSB# to the $GPS variable
GPS=$(awk '{print substr($0,60,7)}' .gpsUSB )

#stop gpsd to make config change
sudo systemctl stop gpsd

#change config to match
sudo echo "# Start the gpsd daemon automatically at boot time
START_DAEMON="true"
# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="true"
# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/$GPS"
# Other options you want to pass to gpsd
GPSD_OPTIONS=""" > /etc/default/gpsd

sudo systemctl start gpsd

