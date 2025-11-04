#!/bin/bash

# PX4 v1.14 Multi-vehicle SITL with SIH (Software-in-the-Loop)
# Pure dynamics simulation, no Gazebo

set -e

# Configuration
PX4_DIR="${HOME}/workspace/PX4-Autopilot"
LOG_DIR="/tmp"
NUM_VEHICLES=3
BASE_PORT=14540
HEADLESS=1
PX4_SYS_AUTOSTART=10040
BUILD_BINARY="./build/px4_sitl_default/bin/px4"

# Validate environment
if [ ! -d "$PX4_DIR" ]; then
  echo "❌ Error: PX4_DIR not found: $PX4_DIR"
  exit 1
fi

cd "$PX4_DIR" || exit 1

if [ ! -f "$BUILD_BINARY" ]; then
  echo "❌ Error: Build binary not found. Run 'make px4_sitl_default' first"
  exit 1
fi

# Clean up old rootfs instances to prevent duplication
echo "🧹 Cleaning up old rootfs instances..."
rm -rf px4_sitl_default/rootfs/0 px4_sitl_default/rootfs/1 px4_sitl_default/rootfs/2 2>/dev/null || true

# Create log directory
mkdir -p "$LOG_DIR"

echo "🚀 Starting PX4 SITL Multi-Vehicle Simulation"
echo ""

# Array to store PIDs
declare -a PIDS

# Start vehicles in a loop
for i in $(seq 0 $((NUM_VEHICLES - 1))); do
  PORT=$((BASE_PORT + i))
  LOG_FILE="$LOG_DIR/px4_$((i+1)).log"
  
  echo "   Vehicle $((i+1)) → Instance $i, MAVLink port $PORT"
  
  HEADLESS=$HEADLESS \
    PX4_SYS_AUTOSTART=$PX4_SYS_AUTOSTART \
    $BUILD_BINARY -i $i -d > "$LOG_FILE" 2>&1 &
  
  PIDS[$i]=$!
  sleep 2
done

echo ""
echo "==================================="
echo "✓ PX4 SITL Multi-Vehicle Launched!"
echo "==================================="

# Display summary
for i in $(seq 0 $((NUM_VEHICLES - 1))); do
  PORT=$((BASE_PORT + i))
  echo "Vehicle $((i+1)): MAVLink UDP 127.0.0.1:$PORT (PID ${PIDS[$i]})"
done

echo ""
echo "Simulator: SIH (Software-in-the-Loop)"
echo "Logs: $LOG_DIR/px4_*.log"
echo ""
echo "Usage:"
echo "  Tail logs:  tail -f $LOG_DIR/px4_1.log"
echo "  Stop all:   kill ${PIDS[0]} ${PIDS[1]} ${PIDS[2]}"
echo "==================================="
echo ""

# Cleanup function
cleanup() {
  echo ""
  echo "⏹️  Stopping all vehicles..."
  
  # Kill all stored PIDs
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  
  # Fallback: kill any remaining px4 processes
  pkill -f "px4 -i" 2>/dev/null || true
  
  # Optional: Clean up rootfs after shutdown to save space
  echo "🧹 Cleaning up rootfs instances..."
  rm -rf "$PX4_DIR/px4_sitl_default/rootfs/"* 2>/dev/null || true
  
  echo "Done."
  exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Keep script running
wait