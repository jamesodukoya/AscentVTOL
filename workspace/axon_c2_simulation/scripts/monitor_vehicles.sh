#!/bin/bash
# monitor_mavlink.sh - Monitor MAVLink traffic for all vehicles

echo "Starting MAVLink monitoring for 3 vehicles..."
echo "Press Ctrl+C to stop"
echo ""

# Create monitoring log directory
MONITOR_DIR="/tmp/mavlink_monitor"
mkdir -p $MONITOR_DIR

# Monitor Vehicle 1 (X500 #1 - Port 14540, Instance 0)
sudo tcpdump -i lo udp port 14540 -l -n -tttt >> $MONITOR_DIR/vehicle1.log 2>&1 &
PID1=$!

# Monitor Vehicle 2 (VTOL - Port 14541, Instance 1)
sudo tcpdump -i lo udp port 14541 -l -n -tttt >> $MONITOR_DIR/vehicle2.log 2>&1 &
PID2=$!

# Monitor Vehicle 3 (X500 #2 - Port 14542, Instance 2)
sudo tcpdump -i lo udp port 14542 -l -n -tttt >> $MONITOR_DIR/vehicle3.log 2>&1 &
PID3=$!

echo "Log files (appending mode):"
echo "  - Vehicle 1 (X500 #1): $MONITOR_DIR/vehicle1.log"
echo "  - Vehicle 2 (VTOL):    $MONITOR_DIR/vehicle2.log"
echo "  - Vehicle 3 (X500 #2): $MONITOR_DIR/vehicle3.log"
echo ""

# Display real-time packet counts and statistics
while true; do
    clear
    echo "==================================="
    echo "MAVLink Traffic Monitor"
    echo "==================================="
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Count UDP connections per port
    echo "Active Connections:"
    netstat -an | grep -E "14540|14541|14542" | awk '{print $4}' | sort | uniq -c
    
    echo ""
    echo "Total Packets (cumulative):"
    # Show packet count for each log
    if [ -f "$MONITOR_DIR/vehicle1.log" ]; then
        V1_LINES=$(wc -l < "$MONITOR_DIR/vehicle1.log")
        echo "  Vehicle 1 (port 14540): $V1_LINES packets"
    fi
    
    if [ -f "$MONITOR_DIR/vehicle2.log" ]; then
        V2_LINES=$(wc -l < "$MONITOR_DIR/vehicle2.log")
        echo "  Vehicle 2 (port 14541): $V2_LINES packets"
    fi
    
    if [ -f "$MONITOR_DIR/vehicle3.log" ]; then
        V3_LINES=$(wc -l < "$MONITOR_DIR/vehicle3.log")
        echo "  Vehicle 3 (port 14542): $V3_LINES packets"
    fi
    
    echo ""
    echo "Log files: $MONITOR_DIR/vehicle*.log"
    echo "Press Ctrl+C to stop monitoring"
    
    sleep 2
done

# Cleanup
trap "kill $PID1 $PID2 $PID3 2>/dev/null; echo ''; echo 'Monitoring stopped'; echo 'Logs preserved in $MONITOR_DIR'; exit" SIGINT SIGTERM
