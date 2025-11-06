#!/usr/bin/env python3
"""
Configure MAVLink stream rates for multiple PX4 SITL instances
Sets all telemetry streams to 30Hz
"""

from pymavlink import mavutil
import time
import sys

def configure_rates(connection_string, rate_hz=1, timeout=10):
    """Configure MAVLink stream rates for a single vehicle"""
    try:
        print(f"Connecting to {connection_string}...", end=" ")
        mav = mavutil.mavlink_connection(connection_string)
        
        # Wait for heartbeat with timeout
        if not mav.wait_heartbeat(timeout=timeout):
            print("❌ No heartbeat received")
            return False
        
        print(f"✓ Connected (System ID: {mav.target_system})")
        
        # Request all data streams at specified rate
        mav.mav.request_data_stream_send(
            mav.target_system,
            mav.target_component,
            mavutil.mavlink.MAV_DATA_STREAM_ALL,
            rate_hz,
            1  # 1 = start streaming, 0 = stop streaming
        )
        
        print(f"  ✓ Configured all streams to {rate_hz}Hz")
        
        # Also set individual important streams explicitly
        streams = [
            (mavutil.mavlink.MAV_DATA_STREAM_POSITION, rate_hz),
            (mavutil.mavlink.MAV_DATA_STREAM_EXTRA1, rate_hz),  # Attitude
            (mavutil.mavlink.MAV_DATA_STREAM_EXTRA2, rate_hz),  # VFR_HUD
            (mavutil.mavlink.MAV_DATA_STREAM_RAW_SENSORS, rate_hz),
        ]
        
        for stream_id, rate in streams:
            mav.mav.request_data_stream_send(
                mav.target_system,
                mav.target_component,
                stream_id,
                rate,
                1
            )
        
        print(f"  ✓ Configured individual streams")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("=" * 50)
    print("  MAVLink Rate Configuration Tool")
    print("  Setting all streams to 30Hz")
    print("=" * 50)
    print()
    
    # Configuration
    num_vehicles = 3
    base_port = 14540
    rate_hz = 30
    
    success_count = 0
    
    # Configure each vehicle
    for i in range(num_vehicles):
        port = base_port + i
        connection_string = f'udp:127.0.0.1:{port}'
        
        print(f"[Drone {i+1}] Configuring vehicle on port {port}")
        
        if configure_rates(connection_string, rate_hz=rate_hz):
            success_count += 1
        
        print()
        time.sleep(0.5)  # Small delay between vehicles
    
    print("=" * 50)
    print(f"Configuration complete: {success_count}/{num_vehicles} vehicles configured")
    print("=" * 50)
    
    if success_count < num_vehicles:
        print("\n⚠️  Some vehicles failed to configure")
        print("   Check that PX4 instances are running and MAVLink is active")
        sys.exit(1)
    else:
        print("\n✓ All vehicles configured successfully")
        sys.exit(0)

if __name__ == "__main__":
    main()
