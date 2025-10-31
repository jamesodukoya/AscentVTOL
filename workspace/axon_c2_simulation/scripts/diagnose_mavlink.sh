#!/bin/bash
# Diagnostic script to check PX4 SITL MAVLink connectivity

echo "=== PX4 SITL MAVLink Diagnostics ==="
echo ""

echo "1. Checking if PX4 processes are running..."
PX4_PROCS=$(ps aux | grep -E "px4.*sitl" | grep -v grep | wc -l)
echo "   Found $PX4_PROCS PX4 processes"
ps aux | grep -E "px4.*sitl" | grep -v grep | head -n 3
echo ""

echo "2. Checking UDP ports..."
for port in 14540 14541 14542; do
    if netstat -uln 2>/dev/null | grep -q ":$port "; then
        echo "   ✓ Port $port is open"
    else
        echo "   ✗ Port $port is NOT open"
    fi
done
echo ""

echo "3. Testing MAVLink connection with mavproxy..."
for port in 14540 14541 14542; do
    echo "   Testing port $port..."
    timeout 5 mavproxy.py --master=udp:127.0.0.1:$port 2>&1 | grep -E "Heartbeat|heartbeat|online|Connect" | head -n 3
done
echo ""

echo "4. Checking PX4 logs for MAVLink output..."
for log in /tmp/px4_1.log /tmp/px4_2.log /tmp/px4_3.log; do
    if [ -f "$log" ]; then
        echo "   Checking $log..."
        grep -i "mavlink\|udp\|14540\|14541\|14542" "$log" | tail -n 5
    fi
done
echo ""

echo "5. Testing raw UDP with Python..."
python3 - <<'PYTHON'
import socket
import time

ports = [14540, 14541, 14542]
for port in ports:
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(2)
        sock.bind(('127.0.0.1', 0))  # Bind to any available port
        sock.sendto(b'\xfe\x09\x00\xff\xbe\x00\x00\x00\x00\x00\x00\x02\x03\x59\x03\x03\x37\x0d', ('127.0.0.1', port))
        data, addr = sock.recvfrom(1024)
        print(f"   ✓ Port {port} responding to MAVLink heartbeat")
        sock.close()
    except socket.timeout:
        print(f"   ✗ Port {port} timeout (no response)")
    except Exception as e:
        print(f"   ✗ Port {port} error: {e}")
PYTHON
echo ""

echo "6. Checking if MAVLink mode is correct in PX4 logs..."
grep -E "mode.*mavlink|mavlink.*mode" /tmp/px4_*.log 2>/dev/null | tail -n 5
echo ""

echo "=== Diagnosis Complete ==="
echo ""
echo "Common issues:"
echo "  - PX4 not fully started (wait 30s after spawn)"
echo "  - MAVLink not configured in SITL startup"
echo "  - Port conflicts (another program using ports)"
echo "  - Using 'udp:' instead of 'udpout:' in pymavlink"