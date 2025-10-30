#!/bin/bash
# High-performance random motion generator for 3 PX4 vehicles
# Sends MAVLink commands via pymavlink for maximum dynamics

set -e

# Configuration
UPDATE_RATE_HZ=2  # Commands per second per vehicle
WAYPOINT_RADIUS_M=50  # Max distance from origin
ALT_MIN_M=10
ALT_MAX_M=100
VELOCITY_MPS=5  # Target velocity

echo "=== Axon C2 Dynamic Motion Generator ==="
echo "Sending random waypoints at ${UPDATE_RATE_HZ}Hz to 3 vehicles"
echo "Press Ctrl+C to stop"
echo ""

# Python script for parallel MAVLink commanding
python3 - <<'PYTHON_SCRIPT'
import time
import random
import threading
from pymavlink import mavutil
import sys

class VehicleCommander:
    def __init__(self, port, sysid, update_rate, radius, alt_range, velocity):
        self.port = port
        self.sysid = sysid
        self.update_rate = update_rate
        self.radius = radius
        self.alt_min, self.alt_max = alt_range
        self.velocity = velocity
        self.running = True
        self.conn = None
        
    def connect(self):
        self.conn = mavutil.mavlink_connection(f'udp:127.0.0.1:{self.port}')
        self.conn.wait_heartbeat()
        print(f"[Vehicle {self.sysid}] Connected on port {self.port}")
        
    def arm_and_takeoff(self):
        # Set mode to GUIDED/AUTO/MISSION
        self.conn.mav.command_long_send(
            self.sysid, 1,
            mavutil.mavlink.MAV_CMD_DO_SET_MODE,
            0, 1, 4, 0, 0, 0, 0, 0)
        
        # Arm
        self.conn.mav.command_long_send(
            self.sysid, 1,
            mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
            0, 1, 0, 0, 0, 0, 0, 0)
        
        # Takeoff
        self.conn.mav.command_long_send(
            self.sysid, 1,
            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
            0, 0, 0, 0, 0, 0, 0, 20)
        
        print(f"[Vehicle {self.sysid}] Armed and taking off")
        
    def send_random_waypoint(self):
        # Generate random NED position
        x = random.uniform(-self.radius, self.radius)
        y = random.uniform(-self.radius, self.radius)
        z = -random.uniform(self.alt_min, self.alt_max)  # NED is down-positive
        
        # Send SET_POSITION_TARGET_LOCAL_NED
        self.conn.mav.set_position_target_local_ned_send(
            0,  # timestamp
            self.sysid, 1,
            mavutil.mavlink.MAV_FRAME_LOCAL_NED,
            0b0000111111111000,  # Position only
            x, y, z,
            0, 0, 0,  # velocity
            0, 0, 0,  # acceleration
            0, 0)     # yaw, yaw_rate
            
    def run(self):
        self.connect()
        time.sleep(2)
        self.arm_and_takeoff()
        time.sleep(5)
        
        interval = 1.0 / self.update_rate
        while self.running:
            start = time.time()
            self.send_random_waypoint()
            elapsed = time.time() - start
            sleep_time = max(0, interval - elapsed)
            time.sleep(sleep_time)

# Configuration
PORTS = [14540, 14541, 14542]
SYSIDS = [1, 2, 3]
UPDATE_RATE = 2
RADIUS = 50
ALT_RANGE = (10, 100)
VELOCITY = 5

commanders = []
threads = []

try:
    # Start commander threads
    for port, sysid in zip(PORTS, SYSIDS):
        cmd = VehicleCommander(port, sysid, UPDATE_RATE, RADIUS, ALT_RANGE, VELOCITY)
        commanders.append(cmd)
        t = threading.Thread(target=cmd.run, daemon=True)
        threads.append(t)
        t.start()
        time.sleep(0.5)  # Stagger startup
    
    # Monitor
    while True:
        time.sleep(1)
        
except KeyboardInterrupt:
    print("\nStopping motion generator...")
    for cmd in commanders:
        cmd.running = False
    for t in threads:
        t.join(timeout=1)
    print("Stopped")
    
PYTHON_SCRIPT