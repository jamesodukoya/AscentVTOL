#!/usr/bin/env python3

"""
Autonomous Flight Controller for 3 PX4 Drones (FIXED)
Connects to PX4 SITL instances using proper UDP connections

Compatible with PX4 v1.14
Port Architecture:
  - Commands (write to):     14540-14542 (UDP client to PX4 servers)
  - Telemetry (read from):   14580-14582 (UDP broadcast from PX4)
"""

import time
import random
import math
import threading
from pymavlink import mavutil
import sys

# Drone Configuration
DRONES = [
    {"id": 1, "cmd_port": 14540, "telem_port": 14580, "color": "🔵", "base_lat": 47.397742, "base_lon": 8.545594},
    {"id": 2, "cmd_port": 14541, "telem_port": 14581, "color": "🟢", "base_lat": 47.398000, "base_lon": 8.546000},
    {"id": 3, "cmd_port": 14542, "telem_port": 14582, "color": "🟡", "base_lat": 47.397500, "base_lon": 8.545000},
]

# Flight parameters
FLIGHT_ALTITUDE = 50  # meters
WAYPOINT_RADIUS = 0.002  # degrees (~200m)
WAYPOINT_INTERVAL = 30  # seconds between waypoints
CRUISE_SPEED = 5  # m/s


class DroneController:
    """Controls a single PX4 drone via MAVLink"""
    
    def __init__(self, drone_id, cmd_port, telem_port, color, base_lat, base_lon):
        self.drone_id = drone_id
        self.cmd_port = cmd_port
        self.telem_port = telem_port
        self.color = color
        self.base_lat = base_lat
        self.base_lon = base_lon
        
        self.connection = None  # Single connection for both read/write
        
        self.armed = False
        self.mode = "UNKNOWN"
        self.current_lat = base_lat
        self.current_lon = base_lon
        self.current_alt = 0
        self.running = True
        
    def connect(self):
        """Connect to PX4 instance via UDP"""
        try:
            # Use UDP connection (not udpin or udpout)
            # Format: udp:IP:PORT for bidirectional communication
            connection_string = f"udp:127.0.0.1:{self.cmd_port}"
            
            print(f"{self.color} [Drone {self.drone_id}] Connecting to: {connection_string}")
            
            self.connection = mavutil.mavlink_connection(
                connection_string,
                source_system=255,
                source_component=0,
                dialect='common'
            )
            
            # Wait for heartbeat
            print(f"{self.color} [Drone {self.drone_id}] Waiting for heartbeat on port {self.cmd_port}...")
            msg = self.connection.wait_heartbeat(timeout=30)
            
            if msg:
                print(f"{self.color} [Drone {self.drone_id}] ✓ Connected!")
                print(f"  System ID: {self.connection.target_system}")
                print(f"  Component: {self.connection.target_component}")
                print(f"  Autopilot: {msg.autopilot}")
                print(f"  Type: {msg.type}")
                return True
            else:
                print(f"{self.color} [Drone {self.drone_id}] ✗ No heartbeat received")
                return False
            
        except Exception as e:
            print(f"{self.color} [Drone {self.drone_id}] ✗ Connection failed: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def wait_for_gps(self, timeout=60):
        """Wait for GPS 3D fix"""
        print(f"{self.color} [Drone {self.drone_id}] Waiting for GPS fix...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            msg = self.connection.recv_match(type='GPS_RAW_INT', blocking=True, timeout=3)
            if msg:
                fix_type = msg.fix_type
                sats = msg.satellites_visible
                print(f"{self.color} [Drone {self.drone_id}] GPS: fix_type={fix_type}, sats={sats}")
                
                if fix_type >= 3:  # 3D fix
                    print(f"{self.color} [Drone {self.drone_id}] ✓ GPS 3D fix acquired ({sats} sats)")
                    self.current_lat = msg.lat / 1e7
                    self.current_lon = msg.lon / 1e7
                    return True
            else:
                print(f"{self.color} [Drone {self.drone_id}] Waiting for GPS message...")
                    
        print(f"{self.color} [Drone {self.drone_id}] ✗ GPS fix timeout")
        return False
    
    def set_mode(self, mode_name):
        """Set flight mode"""
        # PX4 custom mode mapping
        mode_mapping = {
            'MANUAL': 1,
            'ALTCTL': 2,
            'POSCTL': 3,
            'AUTO.MISSION': 4,
            'AUTO.LOITER': 5,
            'AUTO.RTL': 6,
            'ACRO': 7,
            'OFFBOARD': 8,
            'STABILIZED': 9,
            'RATTITUDE': 10,
        }
        
        if mode_name not in mode_mapping:
            print(f"{self.color} [Drone {self.drone_id}] Unknown mode: {mode_name}")
            return False
        
        custom_mode = mode_mapping[mode_name]
        
        # PX4 requires base_mode with CUSTOM_MODE flag
        base_mode = mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED
        
        print(f"{self.color} [Drone {self.drone_id}] Setting mode to {mode_name} (custom_mode={custom_mode})...")
        
        self.connection.mav.set_mode_send(
            self.connection.target_system,
            base_mode,
            custom_mode
        )
        
        time.sleep(1)
        
        # Verify mode change
        msg = self.connection.recv_match(type='HEARTBEAT', blocking=True, timeout=5)
        if msg:
            current_mode = msg.custom_mode
            print(f"{self.color} [Drone {self.drone_id}] Current custom_mode: {current_mode}")
            if current_mode == custom_mode:
                print(f"{self.color} [Drone {self.drone_id}] ✓ Mode set to {mode_name}")
                self.mode = mode_name
                return True
        
        print(f"{self.color} [Drone {self.drone_id}] Mode change pending or failed")
        return True  # Continue anyway
    
    def arm(self):
        """Arm the drone"""
        print(f"{self.color} [Drone {self.drone_id}] Arming...")
        
        self.connection.mav.command_long_send(
            self.connection.target_system,
            self.connection.target_component,
            mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
            0,  # confirmation
            1,  # 1 to arm, 0 to disarm
            0, 0, 0, 0, 0, 0
        )
        
        # Wait for acknowledgment
        ack = self.connection.recv_match(type='COMMAND_ACK', blocking=True, timeout=5)
        if ack and ack.command == mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM:
            if ack.result == mavutil.mavlink.MAV_RESULT_ACCEPTED:
                print(f"{self.color} [Drone {self.drone_id}] ✓ Armed successfully")
                self.armed = True
                return True
            else:
                print(f"{self.color} [Drone {self.drone_id}] ✗ Arming rejected (result={ack.result})")
                return False
        else:
            print(f"{self.color} [Drone {self.drone_id}] ✗ No arm acknowledgment")
            return False
    
    def takeoff(self, altitude):
        """Takeoff to specified altitude"""
        print(f"{self.color} [Drone {self.drone_id}] Taking off to {altitude}m...")
        
        self.connection.mav.command_long_send(
            self.connection.target_system,
            self.connection.target_component,
            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
            0,
            0, 0, 0, 0,
            self.current_lat,
            self.current_lon,
            altitude
        )
        
        time.sleep(2)
        print(f"{self.color} [Drone {self.drone_id}] ✓ Takeoff command sent")
        return True
    
    def send_position_target(self, lat, lon, alt):
        """Send position setpoint in OFFBOARD mode"""
        
        self.connection.mav.set_position_target_global_int_send(
            0,  # time_boot_ms (not used)
            self.connection.target_system,
            self.connection.target_component,
            mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            0b0000111111111000,  # type_mask (position only)
            int(lat * 1e7),      # lat
            int(lon * 1e7),      # lon
            alt,                 # alt
            0, 0, 0,             # vx, vy, vz
            0, 0, 0,             # afx, afy, afz
            0, 0                 # yaw, yaw_rate
        )
    
    def generate_random_waypoint(self):
        """Generate random waypoint around base position"""
        angle = random.uniform(0, 2 * math.pi)
        distance = random.uniform(0.0005, WAYPOINT_RADIUS)
        
        lat = self.base_lat + distance * math.cos(angle)
        lon = self.base_lon + distance * math.sin(angle)
        alt = FLIGHT_ALTITUDE + random.uniform(-10, 10)
        
        return lat, lon, alt
    
    def offboard_loop(self):
        """Maintain OFFBOARD mode with continuous setpoint stream"""
        print(f"{self.color} [Drone {self.drone_id}] Starting OFFBOARD setpoint loop")
        
        waypoint_count = 0
        target_lat, target_lon, target_alt = self.generate_random_waypoint()
        last_waypoint_time = time.time()
        
        while self.running:
            try:
                # Check if it's time for a new waypoint
                if time.time() - last_waypoint_time > WAYPOINT_INTERVAL:
                    target_lat, target_lon, target_alt = self.generate_random_waypoint()
                    waypoint_count += 1
                    last_waypoint_time = time.time()
                    
                    print(f"{self.color} [Drone {self.drone_id}] Waypoint #{waypoint_count}: "
                          f"({target_lat:.6f}, {target_lon:.6f}) @ {target_alt:.1f}m")
                
                # Send position setpoint at 2Hz (required for OFFBOARD)
                self.send_position_target(target_lat, target_lon, target_alt)
                
                # Update current position estimate
                self.current_lat = target_lat
                self.current_lon = target_lon
                self.current_alt = target_alt
                
                # 2Hz setpoint rate
                time.sleep(0.5)
                
            except Exception as e:
                print(f"{self.color} [Drone {self.drone_id}] Error in OFFBOARD loop: {e}")
                time.sleep(1)
    
    def run(self):
        """Main execution"""
        # Connect
        if not self.connect():
            print(f"{self.color} [Drone {self.drone_id}] Failed to connect.")
            return
        
        # Wait for GPS
        if not self.wait_for_gps():
            print(f"{self.color} [Drone {self.drone_id}] Failed to get GPS fix.")
            return
        
        # Start sending setpoints before arming (OFFBOARD requirement)
        print(f"{self.color} [Drone {self.drone_id}] Starting pre-arm setpoint stream...")
        target_lat, target_lon, target_alt = self.current_lat, self.current_lon, FLIGHT_ALTITUDE
        
        for _ in range(10):  # Send 10 setpoints before arming
            self.send_position_target(target_lat, target_lon, target_alt)
            time.sleep(0.1)
        
        # Set to OFFBOARD mode
        self.set_mode('OFFBOARD')
        time.sleep(1)
        
        # Arm
        if not self.arm():
            print(f"{self.color} [Drone {self.drone_id}] Failed to arm.")
            return
        
        # Continue OFFBOARD loop with random waypoints
        self.offboard_loop()
    
    def stop(self):
        """Stop the drone"""
        self.running = False
        print(f"{self.color} [Drone {self.drone_id}] Stopping...")


def main():
    """Main function"""
    print("=" * 60)
    print("  PX4 Autonomous Flight Controller (FIXED)")
    print("  3 Drones - UDP Connections")
    print("=" * 60)
    print()
    print("Port Configuration:")
    print("  📥 Command ports: 14540-14542")
    print("  📤 Telemetry ports: 14580-14582")
    print()
    
    # Create drone controllers
    controllers = []
    threads = []
    
    for drone_config in DRONES:
        controller = DroneController(
            drone_id=drone_config["id"],
            cmd_port=drone_config["cmd_port"],
            telem_port=drone_config["telem_port"],
            color=drone_config["color"],
            base_lat=drone_config["base_lat"],
            base_lon=drone_config["base_lon"]
        )
        controllers.append(controller)
    
    # Start each drone in separate thread
    print("Starting autonomous flight for all drones...")
    print()
    
    for controller in controllers:
        thread = threading.Thread(target=controller.run, daemon=True)
        thread.start()
        threads.append(thread)
        time.sleep(5)  # Stagger startup
    
    print()
    print("=" * 60)
    print("  All drones launched!")
    print("=" * 60)
    print()
    print("Drones are flying autonomously in OFFBOARD mode")
    print(f"Waypoint interval: {WAYPOINT_INTERVAL} seconds")
    print(f"Flight altitude: {FLIGHT_ALTITUDE}m ± 10m")
    print()
    print("Press Ctrl+C to stop")
    print()
    
    # Keep main thread alive
    try:
        while True:
            time.sleep(1)
            
            alive_count = sum(1 for t in threads if t.is_alive())
            if alive_count == 0:
                print("\nAll drone threads stopped. Exiting...")
                break
                
    except KeyboardInterrupt:
        print("\n\nStopping all drones...")
        for controller in controllers:
            controller.stop()
        
        print("Waiting for threads to finish...")
        for thread in threads:
            thread.join(timeout=5)
        
        print("Done!")


if __name__ == "__main__":
    main()