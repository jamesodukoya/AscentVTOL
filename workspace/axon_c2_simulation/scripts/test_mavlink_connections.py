#!/usr/bin/env python3
"""
PX4 Multi-Drone Connection Test v2
Properly handles System ID 0 (GCS/Simulator component)

System ID 0 is NORMAL - it represents:
- Ground Control Station messages
- Simulator telemetry
- MAVLink system components

What matters is that each port receives its CORRECT drone System ID (1, 2, or 3)
and NOT the other drones' System IDs.
"""

import sys
import time
from pymavlink import mavutil
from collections import defaultdict

def test_connection(port, expected_system_id, test_duration=10):
    """Test a single port connection"""
    print(f"\n{'='*60}")
    print(f"Testing Port {port} (expecting System ID {expected_system_id})")
    print(f"{'='*60}")
    
    try:
        # Connect
        conn_str = f'udpin:127.0.0.1:{port}'
        print(f"Connecting to {conn_str}...")
        conn = mavutil.mavlink_connection(conn_str, source_system=255)
        
        # Wait for heartbeat
        print("Waiting for heartbeat from drone...")
        hb = conn.wait_heartbeat(timeout=15)
        
        if not hb:
            print(f"❌ FAILED: No heartbeat received within 15 seconds")
            return False
        
        received_system_id = hb.get_srcSystem()
        print(f"✓ Received heartbeat from System ID: {received_system_id}")
        
        # Check if system ID matches (allow 0 as it's GCS/simulator)
        if received_system_id != expected_system_id and received_system_id != 0:
            print(f"❌ FAILED: Expected System ID {expected_system_id}, got {received_system_id}")
            return False
        
        if received_system_id == expected_system_id:
            print(f"✓ Heartbeat from correct System ID")
        else:
            print(f"ℹ️  First heartbeat from System ID 0 (GCS/Simulator) - this is normal")
            print(f"   Waiting for drone heartbeat (System ID {expected_system_id})...")
            
            # Try to get a heartbeat from the actual drone
            start = time.time()
            found_drone = False
            while time.time() - start < 10:
                hb = conn.recv_match(type='HEARTBEAT', blocking=True, timeout=1)
                if hb and hb.get_srcSystem() == expected_system_id:
                    print(f"✓ Found drone heartbeat from System ID {expected_system_id}")
                    found_drone = True
                    break
            
            if not found_drone:
                print(f"❌ FAILED: Never received heartbeat from System ID {expected_system_id}")
                return False
        
        # Collect messages for test duration
        print(f"\nCollecting messages for {test_duration} seconds...")
        start_time = time.time()
        system_message_counts = defaultdict(int)  # Count messages per system ID
        message_type_counts = defaultdict(int)
        total_messages = 0
        
        while time.time() - start_time < test_duration:
            msg = conn.recv_match(blocking=True, timeout=1)
            if msg:
                msg_type = msg.get_type()
                src_system = msg.get_srcSystem()
                
                system_message_counts[src_system] += 1
                message_type_counts[msg_type] += 1
                total_messages += 1
        
        # Results
        elapsed = time.time() - start_time
        msg_rate = total_messages / elapsed
        
        print(f"\n{'─'*60}")
        print(f"Results for Port {port}:")
        print(f"{'─'*60}")
        print(f"Total messages received: {total_messages}")
        print(f"Message rate: {msg_rate:.1f} msg/s")
        print(f"Unique message types: {len(message_type_counts)}")
        
        print(f"\nMessages by System ID:")
        for sys_id in sorted(system_message_counts.keys()):
            count = system_message_counts[sys_id]
            percentage = (count / total_messages * 100) if total_messages > 0 else 0
            
            if sys_id == 0:
                print(f"  System ID {sys_id} (GCS/Simulator): {count:5d} ({percentage:5.1f}%) ✓ Normal")
            elif sys_id == expected_system_id:
                print(f"  System ID {sys_id} (This Drone):     {count:5d} ({percentage:5.1f}%) ✓ Correct!")
            else:
                print(f"  System ID {sys_id} (Other Drone):    {count:5d} ({percentage:5.1f}%) ✗ WRONG!")
        
        # Check for contamination from OTHER drones (not System ID 0)
        other_drones = [sid for sid in system_message_counts.keys() 
                       if sid != expected_system_id and sid != 0]
        
        if other_drones:
            print(f"\n❌ FAILED: Port {port} receiving data from OTHER drones: {other_drones}")
            print(f"   This indicates improper port configuration!")
            print(f"   Each port should ONLY receive data from its designated drone.")
            return False
        
        # Check that we got messages from the expected drone
        if expected_system_id not in system_message_counts:
            print(f"\n❌ FAILED: No messages received from System ID {expected_system_id}")
            print(f"   Port {port} should be receiving data from this drone!")
            return False
        
        drone_msg_count = system_message_counts[expected_system_id]
        drone_percentage = (drone_msg_count / total_messages * 100) if total_messages > 0 else 0
        
        if drone_percentage < 10:
            print(f"\n⚠️  WARNING: Only {drone_percentage:.1f}% of messages from expected drone")
            print(f"   Expected at least 10%. Check PX4 configuration.")
        
        # Show top message types
        print(f"\nTop 10 message types:")
        sorted_msgs = sorted(message_type_counts.items(), key=lambda x: x[1], reverse=True)[:10]
        for msg_type, count in sorted_msgs:
            print(f"  {msg_type:30s} {count:6d}")
        
        print(f"\n✅ Port {port} test PASSED")
        print(f"   ✓ Receiving data from correct drone (System ID {expected_system_id})")
        print(f"   ✓ No contamination from other drones")
        print(f"   ✓ System ID 0 messages present (normal simulator data)")
        return True
        
    except Exception as e:
        print(f"❌ FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("""
╔══════════════════════════════════════════════════════════════╗
║     PX4 Multi-Drone MAVLink Connection Test v2.0            ║
╚══════════════════════════════════════════════════════════════╝

This script verifies that:
1. Each port receives data from its designated drone
2. No cross-contamination between drones
3. Message rates are reasonable

IMPORTANT NOTES:
✓ System ID 0 messages are NORMAL (GCS/Simulator)
✓ What matters: Each port gets its drone's System ID (1, 2, or 3)
✗ Problem: If a port receives ANOTHER drone's System ID

Example of CORRECT behavior:
  Port 14540 receives: System ID 0 ✓ and System ID 1 ✓
  Port 14541 receives: System ID 0 ✓ and System ID 2 ✓
  Port 14542 receives: System ID 0 ✓ and System ID 3 ✓

Example of WRONG behavior:
  Port 14540 receives: System ID 0, 1, 2, 3 ✗ (contaminated!)

""")
    
    input("Press ENTER to start test...")
    
    # Test configuration
    tests = [
        (14540, 1),  # Port 14540 should receive from System ID 1
        (14541, 2),  # Port 14541 should receive from System ID 2
        (14542, 3),  # Port 14542 should receive from System ID 3
    ]
    
    results = []
    
    # Run tests
    for port, expected_system_id in tests:
        success = test_connection(port, expected_system_id, test_duration=10)
        results.append((port, expected_system_id, success))
        time.sleep(2)
    
    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    
    for port, system_id, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"Port {port} (Drone System ID {system_id}): {status}")
    
    all_passed = all(success for _, _, success in results)
    
    if all_passed:
        print(f"\n{'='*60}")
        print("🎉 ALL TESTS PASSED!")
        print(f"{'='*60}")
        print("""
Your PX4 multi-drone setup is correctly configured:
✓ Each drone is sending to its own port
✓ No data contamination between drones
✓ System IDs are correctly assigned
✓ System ID 0 messages present (normal)

You can now start the dashboard backend (app.py) and it should
display the correct data for each drone.

NOTE: It's completely normal to see System ID 0 in the data.
This represents simulator and ground station components.
""")
        return 0
    else:
        print(f"\n{'='*60}")
        print("❌ SOME TESTS FAILED!")
        print(f"{'='*60}")
        print("""
TROUBLESHOOTING:

The issue is cross-contamination between drones, NOT System ID 0.

1. Check PX4 MAVLink configuration:
   grep "mavlink start" /tmp/px4_logs/px4_*.log
   
   Each log should show a DIFFERENT port:
   - px4_1.log: mavlink start -x -u 14540 ...
   - px4_2.log: mavlink start -x -u 14541 ...
   - px4_3.log: mavlink start -x -u 14542 ...

2. Check the actual spawn script being used:
   - Did you replace it with the fixed version?
   - Is the PORT variable being set correctly?

3. Clean restart:
   pkill -9 px4
   rm -rf ~/workspace/PX4-Autopilot/build/px4_sitl_default/instance_*
   ./spawn_three_vehicles_sitl.sh
   sleep 30
   python test_mavlink_connections.py

4. Verify extras.txt files:
   for i in 0 1 2; do
     echo "Instance $i:"
     cat ~/workspace/PX4-Autopilot/build/px4_sitl_default/instance_$i/etc/extras.txt
   done
""")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(1)