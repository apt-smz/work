#!/bin/bash

for interface in $(ls /sys/class/net); do
    if [[ "$(readlink /sys/class/net/$interface)" == *"/usb"* ]]; then
        ip link set $interface down
        macchanger -r $interface
        ip link set $interface up
    fi
done

#start Kismet
sudo systemctl start kismet.service
