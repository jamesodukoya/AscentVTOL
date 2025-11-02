#!/bin/bash

# PX4 v1.14 Multi-vehicle SITL (pure SITL, no Gazebo)
# Works reliably on headless ARM64 Docker

set -e

PX4_DIR="$HOME/workspace/PX4-Autopilot"
LOG_DIR="/tmp"

cd "$PX4_DIR" || exit 1

# Build if needed
if [ ! -f "./build/px4_sitl_default/bin/px4" ]; then
    echo "Building PX4 SITL..."
    make px4_sitl
fi

echo "Starting PX4 SITL (UDP MAVLink only, no Gazebo)..."
echo ""

# Vehicle 1: Instance 0, UDP port 14540
echo "Starting Vehicle 1 (Instance 0) - MAVLink UDP 127.0.0.1:14540..."
HEADLESS=1 \
  PX4_SYS_AUTOSTART=1001 \
  ./build/px4_sitl_default/bin/px4 -i 0 -d > $LOG_DIR/px4_1.log 2>&1 &
PID1=$!

sleep 2

# Vehicle 2: Instance 1, UDP port 14541
echo "Starting Vehicle 2 (Instance 1) - MAVLink UDP 127.0.0.1:14541..."
HEADLESS=1 \
  PX4_SYS_AUTOSTART=1001 \
  ./build/px4_sitl_default/bin/px4 -i 1 -d > $LOG_DIR/px4_2.log 2>&1 &
PID2=$!

sleep 2

# Vehicle 3: Instance 2, UDP port 14542
echo "Starting Vehicle 3 (Instance 2) - MAVLink UDP 127.0.0.1:14542..."
HEADLESS=1 \
  PX4_SYS_AUTOSTART=1001 \
  ./build/px4_sitl_default/bin/px4 -i 2 -d > $LOG_DIR/px4_3.log 2>&1 &
PID3=$!

echo ""
echo "==================================="
echo "PX4 SITL Multi-vehicle launched!"
echo "==================================="
echo "Vehicle 1: MAVLink UDP 127.0.0.1:14540 (PID $PID1)"
echo "Vehicle 2: MAVLink UDP 127.0.0.1:14541 (PID $PID2)"
echo "Vehicle 3: MAVLink UDP 127.0.0.1:14542 (PID $PID3)"
echo ""
echo "Connect with QGC: Add connection to 127.0.0.1:14540"
echo "Or use ROS2: ros2 run px4_msgs px4_msgs_demo"
echo ""
echo "Logs: $LOG_DIR/px4_*.log"
echo "Stop: kill $PID1 $PID2 $PID3"
echo "==================================="

cleanup() {
    echo "Stopping all vehicles..."
    kill $PID1 $PID2 $PID3 2>/dev/null || true
    pkill -f "px4 -i" 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

wait
