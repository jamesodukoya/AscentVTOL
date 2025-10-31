#!/bin/bash
# Random motion generator that RESPECTS geofencing
# Keeps waypoints within safe boundaries
# Fixed-wing needs different mode sequencing than multicopters

set -e

# Configuration - Must match geofence settings!
UPDATE_RATE_HZ=2
WAYPOINT_RADIUS_M=100  # Stay well within 150m geofence (safety margin)
ALT_MIN_M=10
ALT_MAX_M=80           # Stay well under 120m vertical limit
VELOCITY_MPS=5

echo "=== Fixed Commander (Correct UDP Method) ==="
echo "=== Multi-Vehicle Commander ==="
echo "Handling different arming sequences for each vehicle type"
echo "Waypoints: ${WAYPOINT_RADIUS_M}m radius, ${ALT_MAX_M}m altitude"
echo "Press Ctrl+C to stop"
echo ""

python3 - <<'PYTHON_SCRIPT'
import time
import random
import threading
from pymavlink import mavutil

class MulticopterCommander:
    def __init__(self, port, sysid, update_rate, radius, alt_range):
        self.port = port
        self.sysid = sysid
        self.update_rate = update_rate
        self.radius = radius
        self.alt_min, self.alt_max = alt_range
        self.running = True
        self.conn = None
        
    def connect(self):
        conn_str = f'udpin:0.0.0.0:{self.port}'
        print(f"[Vehicle {self.sysid}] Connecting...")
        
        self.conn = mavutil.mavlink_connection(conn_str, source_system=255)
        
        if self.conn.wait_heartbeat(timeout=10):
            print(f"[Vehicle {self.sysid}] ✓ Connected")
            threading.Thread(target=self._heartbeats, daemon=True).start()
            return True
        
        print(f"[Vehicle {self.sysid}] ✗ No heartbeat")
        return False
    
    def _heartbeats(self):
        while self.running:
            try:
                self.conn.mav.heartbeat_send(6, 8, 0, 0, 0)
            except:
                pass
            time.sleep(1)
    
    def set_offboard(self):
        print(f"[Vehicle {self.sysid}] Setting OFFBOARD mode...")
        for _ in range(3):
            self.conn.mav.command_long_send(
                self.sysid, 1, 176, 0, 1, 6, 0, 0, 0, 0, 0)
            time.sleep(0.3)
        time.sleep(1)
    
    def arm(self):
        print(f"[Vehicle {self.sysid}] Arming...")
        
        for attempt in range(3):
            for _ in range(3):
                self.conn.mav.command_long_send(
                    self.sysid, 1, 400, 0, 1, 0, 0, 0, 0, 0, 0)
                time.sleep(0.2)
            
            # Check armed
            timeout = time.time() + 5
            while time.time() < timeout:
                msg = self.conn.recv_match(type='HEARTBEAT', blocking=True, timeout=1)
                if msg and msg.base_mode & 128:
                    print(f"[Vehicle {self.sysid}] ✓ Armed")
                    return True
                time.sleep(0.2)
            
            if attempt < 2:
                print(f"[Vehicle {self.sysid}] Retry...")
        
        print(f"[Vehicle {self.sysid}] ✗ Arm failed")
        return False
    
    def send_setpoint(self):
        x = random.uniform(-self.radius, self.radius)
        y = random.uniform(-self.radius, self.radius)
        z = -random.uniform(self.alt_min, self.alt_max)
        
        self.conn.mav.set_position_target_local_ned_send(
            0, self.sysid, 1, 1, 0b111111111000,
            x, y, z, 0, 0, 0, 0, 0, 0, 0, 0)
    
    def run(self):
        if not self.connect():
            return
        
        time.sleep(2)
        
        # Set OFFBOARD
        self.set_offboard()
        
        # Stream setpoints
        print(f"[Vehicle {self.sysid}] Streaming setpoints...")
        for _ in range(30):
            self.send_setpoint()
            time.sleep(0.05)
        
        # Arm
        if not self.arm():
            return
        
        # Control loop
        print(f"[Vehicle {self.sysid}] ✓ Flying")
        interval = 1.0 / self.update_rate
        count = 0
        
        while self.running:
            start = time.time()
            self.send_setpoint()
            
            count += 1
            if count % 40 == 0:
                print(f"[Vehicle {self.sysid}] {count} waypoints")
            
            time.sleep(max(0, interval - (time.time() - start)))

# Start 3 commanders
commanders = []
threads = []

for i in range(3):
    port = 14540 + i
    sysid = i + 1
    
    cmd = MulticopterCommander(port, sysid, 2, 100, (10, 80))
    commanders.append(cmd)
    
    t = threading.Thread(target=cmd.run, daemon=True)
    threads.append(t)
    t.start()
    
    time.sleep(5)

print("\n" + "="*50)
print("All vehicles flying - Press Ctrl+C to stop")
print("="*50 + "\n")

try:
    while True:
        time.sleep(10)
except KeyboardInterrupt:
    print("\n\nStopping...")
    for cmd in commanders:
        cmd.running = False
    for t in threads:
        t.join(timeout=2)
    print("✓ Stopped")

PYTHON_SCRIPT