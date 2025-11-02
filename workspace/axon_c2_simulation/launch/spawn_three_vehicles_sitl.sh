#!/bin/bash

# PX4 v1.14 Multi-vehicle SITL with SIH (Software-in-the-Loop)
# Pure dynamics simulation, no Gazebo

set -e

PX4_DIR="$HOME/workspace/PX4-Autopilot"
LOG_DIR="/tmp"

cd "$PX4_DIR" || exit 1

echo "Starting PX4 SITL (SIH simulator)..."
echo ""

# Vehicle 1: Instance 0, MAVLink port 14540
echo "Starting Vehicle 1 (Instance 0)..."
HEADLESS=1 \
  PX4_SYS_AUTOSTART=10040 \
  ./build/px4_sitl_default/bin/px4 -i 0 -d > $LOG_DIR/px4_1.log 2>&1 &
PID1=$!

sleep 2

# Vehicle 2: Instance 1, MAVLink port 14541
echo "Starting Vehicle 2 (Instance 1)..."
HEADLESS=1 \
  PX4_SYS_AUTOSTART=10040 \
  ./build/px4_sitl_default/bin/px4 -i 1 -d > $LOG_DIR/px4_2.log 2>&1 &
PID2=$!

sleep 2

# Vehicle 3: Instance 2, MAVLink port 14542
echo "Starting Vehicle 3 (Instance 2)..."
HEADLESS=1 \
  PX4_SYS_AUTOSTART=10040 \
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
echo "Using SIH (Software-in-the-Loop) simulator"
echo "Logs: $LOG_DIR/px4_*.log"
echo "Tail: docker exec ascent_vtol_container tail -f /tmp/px4_1.log"
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
