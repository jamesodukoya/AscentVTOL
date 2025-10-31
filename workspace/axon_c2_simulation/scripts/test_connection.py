import time
import sys
from pymavlink import mavutil

def test_vehicle(port, sysid):
    """Test connection to a single vehicle"""
    print(f"\n[Vehicle {sysid}] Testing port {port}...")
    
    try:
        # CRITICAL: PX4 SITL broadcasts on UDP ports
        # We need to LISTEN (udpin) not SEND (udpout)
        # The correct connection string is 'udpin:0.0.0.0:PORT'
        conn_str = f'udpin:0.0.0.0:{port}'
        print(f"[Vehicle {sysid}] Connecting with: {conn_str}")
        
        conn = mavutil.mavlink_connection(conn_str, source_system=255)
        
        # Wait for heartbeat with timeout
        print(f"[Vehicle {sysid}] Waiting for heartbeat...")
        msg = conn.wait_heartbeat(timeout=10)
        
        if msg:
            print(f"[Vehicle {sysid}] ✓ SUCCESS! Received heartbeat from system {msg.get_srcSystem()}")
            print(f"[Vehicle {sysid}]   Type: {msg.type}, Autopilot: {msg.autopilot}")
            return True
        else:
            print(f"[Vehicle {sysid}] ✗ TIMEOUT - No heartbeat received")
            return False
            
    except Exception as e:
        print(f"[Vehicle {sysid}] ✗ ERROR: {e}")
        return False

# Test all three vehicles
ports = [14540, 14541, 14542]
sysids = [1, 2, 3]
results = []

for port, sysid in zip(ports, sysids):
    result = test_vehicle(port, sysid)
    results.append(result)
    time.sleep(1)

print("\n" + "="*50)
print("Connection Test Results:")
print("="*50)
for i, (port, result) in enumerate(zip(ports, results), 1):
    status = "✓ Connected" if result else "✗ Failed"
    print(f"Vehicle {i} (port {port}): {status}")

if all(results):
    print("\n✓ All vehicles connected successfully!")
else:
    print("\n✗ Some vehicles failed to connect.")
    print("\nTroubleshooting:")
    print("1. Make sure spawn script completed successfully")
    print("2. Check: ps aux | grep px4")
    print("3. Check logs: tail -f /tmp/px4_*.log")
    print("4. Verify ports: netstat -uln | grep '14540\\|14541\\|14542'")
