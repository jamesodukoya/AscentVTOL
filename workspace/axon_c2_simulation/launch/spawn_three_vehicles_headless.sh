#!/bin/bash
# PX4 v1.14 Compatible - Launch 2x X500 quadcopters and 1x VTOL
# Fixed for headless ARM64 - starts Gazebo separately


set -e

# Configuration
PX4_DIR="$HOME/workspace/PX4-Autopilot"
HEADLESS=${HEADLESS:-1}
LOG_DIR="/tmp"

cd "$PX4_DIR" || exit 1

# Build if not already built
if [ ! -f "./build/px4_sitl_default/bin/px4" ]; then
    echo "Building PX4 SITL..."
    make px4_sitl
fi

echo "Launching multi-vehicle simulation (PX4 v1.14)..."
echo "Log files: $LOG_DIR/px4_1.log, $LOG_DIR/px4_2.log, $LOG_DIR/px4_3.log"
echo ""

# CRITICAL FIX: Start Gazebo server headless FIRST
echo "Starting Gazebo simulation engine (headless)..."
HEADLESS=$HEADLESS \
  gz sim -r -s Tools/simulation/gz/worlds/default.sdf > $LOG_DIR/gz_server.log 2>&1 &
GZ_SERVER_PID=$!

# Wait for Gazebo to fully initialize before spawning vehicles
sleep 8

# Vehicle 1: X500 Quadcopter at default position (connects to existing gz-server)
echo "Starting X500 #1 (instance 0) at origin..."
HEADLESS=$HEADLESS \
  PX4_SYS_AUTOSTART=4001 \
  PX4_GZ_MODEL=x500 \
  ./build/px4_sitl_default/bin/px4 -i 0 -d > $LOG_DIR/px4_1.log 2>&1 &
X500_1_PID=$!

# Wait for first vehicle to connect to Gazebo
sleep 3

# Vehicle 2: Standard VTOL at x=5m (standalone mode - spawns in existing world)
echo "Starting VTOL (instance 1) at x=5m..."
HEADLESS=$HEADLESS \
  PX4_GZ_STANDALONE=1 \
  PX4_SYS_AUTOSTART=4004 \
  PX4_GZ_MODEL_POSE="5,0,0.15" \
  PX4_GZ_MODEL=standard_vtol \
  ./build/px4_sitl_default/bin/px4 -i 1 -d > $LOG_DIR/px4_2.log 2>&1 &
VTOL_PID=$!

# Wait for second vehicle to connect
sleep 2

# Vehicle 3: X500 Quadcopter at x=10m (standalone mode)
echo "Starting X500 #2 (instance 2) at x=10m..."
HEADLESS=$HEADLESS \
  PX4_GZ_STANDALONE=1 \
  PX4_SYS_AUTOSTART=4001 \
  PX4_GZ_MODEL_POSE="10,0,0.15" \
  PX4_GZ_MODEL=x500 \
  ./build/px4_sitl_default/bin/px4 -i 2 -d > $LOG_DIR/px4_3.log 2>&1 &
X500_2_PID=$!

echo ""
echo "==================================="
echo "Multi-vehicle simulation launched!"
echo "==================================="
echo "Gazebo Server: PID $GZ_SERVER_PID"
echo "Vehicle 1 (X500 #1): Position (0, 0, 0), MAVLink port 14540, PID $X500_1_PID"
echo "Vehicle 2 (VTOL): Position (5, 0, 0.15), MAVLink port 14541, PID $VTOL_PID"
echo "Vehicle 3 (X500 #2): Position (10, 0, 0.15), MAVLink port 14542, PID $X500_2_PID"
echo ""
echo "ROS2 namespaces: /px4_1, /px4_2, /px4_3"
echo ""
echo "Logs:"
echo " - Gazebo: $LOG_DIR/gz_server.log"
echo " - Vehicle 1: $LOG_DIR/px4_1.log"
echo " - Vehicle 2: $LOG_DIR/px4_2.log"
echo " - Vehicle 3: $LOG_DIR/px4_3.log"
echo ""
echo "Monitor with: tail -f $LOG_DIR/px4_1.log"
echo "Press Ctrl+C to stop all vehicles"
echo "==================================="

# Cleanup function
cleanup() {
    echo ""
    echo "Stopping all vehicles and Gazebo..."
    kill $X500_1_PID $VTOL_PID $X500_2_PID $GZ_SERVER_PID 2>/dev/null || true
    pkill -f "px4 -i" 2>/dev/null || true
    pkill -f "gz sim" 2>/dev/null || true
    sleep 1
    echo "Simulation stopped."
    echo ""
    echo "Log files preserved at:"
    echo " - $LOG_DIR/gz_server.log"
    echo " - $LOG_DIR/px4_1.log"
    echo " - $LOG_DIR/px4_2.log"
    echo " - $LOG_DIR/px4_3.log"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Wait for all background processes
wait
