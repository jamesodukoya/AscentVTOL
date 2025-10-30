#!/bin/bash

# High-performance headless multi-vehicle spawn script
# Optimized for Axon C2 direct MAVLink UDP connection
# FIXED: Proper Gazebo service calls to initialize sensor plugins

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PX4_DIR="$HOME/workspace/PX4-Autopilot"
MODEL_PATH="$PX4_DIR/Tools/simulation/gz/models"

# Kill any existing instances
echo "Cleaning up existing processes..."
pkill -9 px4 || true
pkill -9 gz || true
pkill -9 ruby || true
sleep 2

# Set Gazebo model path
export GZ_SIM_RESOURCE_PATH=$MODEL_PATH:$GZ_SIM_RESOURCE_PATH

echo "========================================"
echo "Axon C2 Multi-Vehicle Headless Simulation"
echo "Direct MAVLink UDP Connection Mode"
echo "FIXED: Proper sensor plugin initialization"
echo "========================================"
echo ""

# Vehicle 1: x500 Quadcopter (Uses make to properly start everything)
echo "[1/3] Spawning Vehicle 1 (x500 Quadcopter)..."
cd $PX4_DIR

# Start first vehicle with make - this properly initializes Gazebo
echo "  Starting Gazebo and Vehicle 1..."
HEADLESS=1 PX4_SYS_AUTOSTART=4001 make px4_sitl gz_x500 > /tmp/px4_1.log 2>&1 &
PX4_1_PID=$!
echo "  ✓ Vehicle 1 process started (PID: $PX4_1_PID)"
echo "  ✓ MAVLink UDP Port: 14540"
echo "  ✓ System ID: 1"
echo "  Waiting 25s for Gazebo and vehicle to fully initialize..."
sleep 25

# Verify Vehicle 1 is ready
echo "  Checking Vehicle 1 status..."
if grep -q "Ready for takeoff\|Startup script returned successfully" /tmp/px4_1.log 2>/dev/null; then
    echo "  ✓ Vehicle 1 is ready!"
else
    echo "  ⚠ Vehicle 1 may still be initializing..."
fi

# Verify Vehicle 1 sensors are active
echo "  Verifying Vehicle 1 sensors..."
if gz topic -l 2>/dev/null | grep -q "x500_0.*imu"; then
    echo "  ✓ Vehicle 1 sensors detected in Gazebo"
else
    echo "  ✗ WARNING: Vehicle 1 sensors not detected!"
fi

# Vehicle 2: Standard VTOL
echo ""
echo "[2/3] Spawning Vehicle 2 (Standard VTOL)..."

# Use Gazebo service to spawn model (this properly loads all plugins)
echo "  Spawning VTOL model via Gazebo service..."
gz service -s /world/default/create \
  --reqtype gz.msgs.EntityFactory \
  --reptype gz.msgs.Boolean \
  --timeout 5000 \
  --req "sdf_filename: \"$MODEL_PATH/standard_vtol\", name: \"standard_vtol_1\", pose: {position: {x: 5, y: 0, z: 0.15}}" 2>&1 | head -n3

echo "  Waiting for model to fully initialize..."
sleep 8

# Verify model and sensors are loaded
echo "  Verifying VTOL model registration..."
if gz model --list 2>/dev/null | grep -q "standard_vtol_1"; then
    echo "  ✓ Model registered in Gazebo"
else
    echo "  ✗ WARNING: Model not found in Gazebo!"
fi

echo "  Verifying VTOL sensors..."
if gz topic -l 2>/dev/null | grep -q "standard_vtol_1.*imu"; then
    echo "  ✓ VTOL sensors detected in Gazebo"
else
    echo "  ✗ WARNING: VTOL sensors not detected - PX4 may fail to arm!"
fi

# Start PX4 instance for vehicle 2
echo "  Starting PX4 for Vehicle 2..."
cd $PX4_DIR
nohup env HEADLESS=1 \
  PX4_SIM_MODEL=gz_standard_vtol \
  PX4_GZ_MODEL_NAME=standard_vtol_1 \
  PX4_GZ_WORLD=default \
  MAV_SYS_ID=2 \
  ./build/px4_sitl_default/bin/px4 \
  -i 1 -d "$PX4_DIR/ROMFS/px4fmu_common" \
  < /dev/null > /tmp/px4_2.log 2>&1 &
PX4_2_PID=$!
echo "  ✓ Vehicle 2 PID: $PX4_2_PID"
echo "  ✓ MAVLink UDP Port: 14541"
echo "  ✓ System ID: 2"
echo "  Waiting for PX4 initialization..."
sleep 15

# Check Vehicle 2 status
if grep -q "Ready for takeoff\|Startup script returned successfully" /tmp/px4_2.log 2>/dev/null; then
    echo "  ✓ Vehicle 2 is ready!"
else
    echo "  ⚠ Vehicle 2 may still be initializing"
fi

# Check for EKF2 errors
if grep -q "ekf2.*failed\|ekf2 missing data" /tmp/px4_2.log 2>/dev/null; then
    echo "  ✗ WARNING: Vehicle 2 has EKF2 errors (check /tmp/px4_2.log)"
else
    echo "  ✓ Vehicle 2 EKF2 appears healthy"
fi

# Vehicle 3: Fixed-Wing Plane
echo ""
echo "[3/3] Spawning Vehicle 3 (Fixed-Wing Cessna)..."

# Use Gazebo service to spawn model
echo "  Spawning Cessna model via Gazebo service..."
gz service -s /world/default/create \
  --reqtype gz.msgs.EntityFactory \
  --reptype gz.msgs.Boolean \
  --timeout 5000 \
  --req "sdf_filename: \"$MODEL_PATH/rc_cessna\", name: \"rc_cessna_2\", pose: {position: {x: 10, y: 0, z: 0.15}}" 2>&1 | head -n3

echo "  Waiting for model to fully initialize..."
sleep 8

# Verify model and sensors
echo "  Verifying Cessna model registration..."
if gz model --list 2>/dev/null | grep -q "rc_cessna_2"; then
    echo "  ✓ Model registered in Gazebo"
else
    echo "  ✗ WARNING: Model not found in Gazebo!"
fi

echo "  Verifying Cessna sensors..."
if gz topic -l 2>/dev/null | grep -q "rc_cessna_2.*imu"; then
    echo "  ✓ Cessna sensors detected in Gazebo"
else
    echo "  ✗ WARNING: Cessna sensors not detected - PX4 may fail to arm!"
fi

# Start PX4 instance for vehicle 3
echo "  Starting PX4 for Vehicle 3..."
nohup env HEADLESS=1 \
  PX4_SIM_MODEL=gz_rc_cessna \
  PX4_GZ_MODEL_NAME=rc_cessna_2 \
  PX4_GZ_WORLD=default \
  MAV_SYS_ID=3 \
  ./build/px4_sitl_default/bin/px4 \
  -i 2 -d "$PX4_DIR/ROMFS/px4fmu_common" \
  < /dev/null > /tmp/px4_3.log 2>&1 &
PX4_3_PID=$!
echo "  ✓ Vehicle 3 PID: $PX4_3_PID"
echo "  ✓ MAVLink UDP Port: 14542"
echo "  ✓ System ID: 3"
echo "  Waiting for PX4 initialization..."
sleep 15

# Check Vehicle 3 status
if grep -q "Ready for takeoff\|Startup script returned successfully" /tmp/px4_3.log 2>/dev/null; then
    echo "  ✓ Vehicle 3 is ready!"
else
    echo "  ⚠ Vehicle 3 may still be initializing"
fi

# Check for EKF2 errors
if grep -q "ekf2.*failed\|ekf2 missing data" /tmp/px4_3.log 2>/dev/null; then
    echo "  ✗ WARNING: Vehicle 3 has EKF2 errors (check /tmp/px4_3.log)"
else
    echo "  ✓ Vehicle 3 EKF2 appears healthy"
fi

echo ""
echo "========================================"
echo "Deployment Summary"
echo "========================================"
echo "Process IDs: $PX4_1_PID, $PX4_2_PID, $PX4_3_PID"
echo ""
echo "Log files:"
echo "  /tmp/px4_1.log (x500 Quadcopter)"
echo "  /tmp/px4_2.log (Standard VTOL)"
echo "  /tmp/px4_3.log (RC Cessna)"
echo ""
echo "MAVLink Endpoints:"
echo "  Vehicle 1: udp://127.0.0.1:14540"
echo "  Vehicle 2: udp://127.0.0.1:14541"
echo "  Vehicle 3: udp://127.0.0.1:14542"
echo ""
echo "Verification Commands:"
echo "  gz model --list"
echo "  gz topic -l | grep '/world/.*sensor'"
echo "  tail -f /tmp/px4_{1,2,3}.log"
echo ""
echo "Sensor Health Check:"
echo "  gz topic -l | grep 'imu\|air_pressure'"
echo ""
echo "Connect Axon C2 to these endpoints"
echo "Press Ctrl+C to stop all vehicles"
echo "========================================"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Shutting down all vehicles and Gazebo..."
    kill $PX4_1_PID $PX4_2_PID $PX4_3_PID 2>/dev/null || true
    sleep 1
    pkill -9 px4 || true
    pkill -9 gz || true
    echo "✓ Cleanup complete"
    exit 0
}

# Wait for interrupt
trap cleanup SIGINT SIGTERM

wait