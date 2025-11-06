#!/usr/bin/env python3
import sys
import signal
from pymavlink import mavutil
from collections import defaultdict
import time

# Track messages by system ID and source port
messages_by_vehicle = defaultdict(set)
message_counts = defaultdict(lambda: defaultdict(int))
running = True


def signal_handler(sig, frame):
    global running
    running = False
    print("\n\nStopping capture...\n")


signal.signal(signal.SIGINT, signal_handler)

# Create MAVLink connections for each port
connections = {
    14580: mavutil.mavlink_connection('udpin:0.0.0.0:14580', source_system=255, dialect='common'),
    14581: mavutil.mavlink_connection('udpin:0.0.0.0:14581', source_system=255, dialect='common'),
    14582: mavutil.mavlink_connection('udpin:0.0.0.0:14582', source_system=255, dialect='common')
}

print("Listening for MAVLink messages on ports 14580, 14581, 14582...")
print("Press Ctrl+C to stop and show results\n")

# Read MAVLink messages from all connections
while running:
    for port, conn in connections.items():
        msg = conn.recv_match(blocking=False)
        if msg:
            msg_type = msg.get_type()
            if msg_type != 'BAD_DATA':
                vehicle_id = f"Port_{port}_SysID_{msg.get_srcSystem()}"
                messages_by_vehicle[vehicle_id].add(msg_type)
                message_counts[vehicle_id][msg_type] += 1

    time.sleep(0.001)  # Small delay to prevent CPU spinning

# Print results
print("\n" + "="*70)
print("MESSAGE SUMMARY BY VEHICLE")
print("="*70)

for vehicle in sorted(messages_by_vehicle.keys()):
    port = vehicle.split('_')[1]
    sysid = vehicle.split('_')[3]
    msg_types = messages_by_vehicle[vehicle]

    print(f"\n📡 Vehicle: System ID {sysid} on Port {port}")
    print(f"   Unique message types: {len(msg_types)}")
    print(f"   {'-'*50}")

    for msg_type in sorted(msg_types):
        count = message_counts[vehicle][msg_type]
        print(f"   {count:6d}  {msg_type}")
