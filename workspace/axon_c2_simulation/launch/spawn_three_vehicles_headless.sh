#!/bin/bash
# PX4 v1.14 Compatible - Launch 2x X500 quadcopters and 1x VTOL

set -e

# Configuration
PX4_DIR="$HOME/workspace/PX4-Autopilot"  # PX4 path
HEADLESS=${HEADLESS:-1}        # Set to 0 to enable GUI
LOG_DIR="/tmp"                 # Log file directory

cd "$PX4_DIR" || exit 1

# Build if not already built
if [ ! -f "./build/px4_sitl_default/bin/px4" ]; then
    echo "Building PX4 SITL..."
    make px4_sitl
fi

echo "Launching multi-vehicle simulation (PX4 v1.14)..."
echo "Log files: $LOG_DIR/px4_1.log, $LOG_DIR/px4_2.log, $LOG_DIR/px4_3.log"
echo ""

# Vehicle 1: X500 Quadcopter at default position (starts gz-server)
echo "Starting X500 #1 (instance 1) at origin..."
HEADLESS=$HEADLESS \
PX4_SYS_AUTOSTART=4001 \
PX4_GZ_MODEL=x500 \
./build/px4_sitl_default/bin/px4 -i 0 -d > $LOG_DIR/px4_1.log 2>&1 &
X500_1_PID=$!

# Wait for gz-server to initialize
sleep 5

# Vehicle 2: Standard VTOL at x=5m (standalone mode)
echo "Starting VTOL (instance 2) at x=5m..."
HEADLESS=$HEADLESS \
PX4_GZ_STANDALONE=1 \
PX4_SYS_AUTOSTART=4004 \
PX4_GZ_MODEL_POSE="5,0,0.15" \
PX4_GZ_MODEL=standard_vtol \
./build/px4_sitl_default/bin/px4 -i 1 -d > $LOG_DIR/px4_2.log 2>&1 &
VTOL_PID=$!

# Vehicle 3: X500 Quadcopter at x=10m (standalone mode)
echo "Starting X500 #2 (instance 3) at x=10m..."
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
echo "Vehicle 1 (X500 #1):  Position (0, 0, 0), MAVLink port 14540, PID $X500_1_PID"
echo "Vehicle 2 (VTOL):     Position (5, 0, 0.15), MAVLink port 14541, PID $VTOL_PID"
echo "Vehicle 3 (X500 #2):  Position (10, 0, 0.15), MAVLink port 14542, PID $X500_2_PID"
echo ""
echo "ROS2 namespaces: /px4_1, /px4_2, /px4_3"
echo ""
echo "Logs:"
echo "  - Vehicle 1: $LOG_DIR/px4_1.log"
echo "  - Vehicle 2: $LOG_DIR/px4_2.log"
echo "  - Vehicle 3: $LOG_DIR/px4_3.log"
echo ""
echo "Press Ctrl+C to stop all vehicles"
echo "==================================="

# Cleanup function
cleanup() {
    echo ""
    echo "Stopping all vehicles..."
    kill $X500_1_PID $VTOL_PID $X500_2_PID 2>/dev/null
    pkill -f "px4 -i"
    echo "Simulation stopped."
    echo ""
    echo "Log files preserved at:"
    echo "  - $LOG_DIR/px4_1.log"
    echo "  - $LOG_DIR/px4_2.log"
    echo "  - $LOG_DIR/px4_3.log"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Wait for all background processes
wait