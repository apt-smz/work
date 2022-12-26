#!/bin/bash
dmesg | grep usb | grep "pl2303 converter" > .gpsUSB
GPS=$(awk '{print substr($0,60,7)}' .gpsUSB )
sudo echo DEVICES="/dev/$GPS"
sudo systemctl restart gpsd

