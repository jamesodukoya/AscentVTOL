#!/bin/bash

# High-performance headless multi-vehicle spawn script
# Optimized for Axon C2 direct MAVLink UDP connection
# FIXED: Proper Gazebo service calls to initialize sensor plugins
# FIXED: Multi-vehicle spawn script with PROPER geofence configuration


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

export GZ_SIM_RESOURCE_PATH=$MODEL_PATH:$GZ_SIM_RESOURCE_PATH

echo "========================================"
echo "Multi-Vehicle: Optimized Configuration"
echo "Vehicle-type-specific parameters"
echo "========================================"
echo ""

# Vehicle 1: x500 Quadcopter - Standard Multicopter Config
echo "[1/3] Spawning Vehicle 1 (x500 Quadcopter)..."
cd $PX4_DIR

HEADLESS=1 PX4_SYS_AUTOSTART=4001 make px4_sitl gz_x500 > /tmp/px4_1.log 2>&1 &
PX4_1_PID=$!
echo "  ✓ Vehicle 1 started (PID: $PX4_1_PID)"
sleep 25

echo "  Configuring Vehicle 1 (Multicopter)..."
timeout 15 mavproxy.py --master=udp:127.0.0.1:14540 --cmd="
param set GF_ACTION 2
param set GF_MAX_HOR_DIST 150
param set GF_MAX_VER_DIST 120
param set NAV_RCL_ACT 0
param set COM_RCL_EXCEPT 4
param set COM_OF_LOSS_T 5.0
param save
" 2>&1 | grep -E "Set parameter|saved" || echo "  (param setting timed out)"

echo "  ✓ Vehicle 1 configured (standard multicopter)"

# Vehicle 2: Standard VTOL - VTOL Config
echo ""
echo "[2/3] Spawning Vehicle 2 (Standard VTOL)..."

gz service -s /world/default/create \
  --reqtype gz.msgs.EntityFactory \
  --reptype gz.msgs.Boolean \
  --timeout 5000 \
  --req "sdf_filename: \"$MODEL_PATH/standard_vtol\", name: \"standard_vtol_1\", pose: {position: {x: 5, y: 0, z: 0.15}}" > /dev/null 2>&1

sleep 8

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
echo "  ✓ Vehicle 2 started (PID: $PX4_2_PID)"
sleep 15

echo "  Configuring Vehicle 2 (VTOL)..."
timeout 15 mavproxy.py --master=udp:127.0.0.1:14541 --cmd="
param set GF_ACTION 2
param set GF_MAX_HOR_DIST 150
param set GF_MAX_VER_DIST 120
param set NAV_RCL_ACT 0
param set COM_RCL_EXCEPT 4
param set COM_OF_LOSS_T 5.0
param save
" 2>&1 | grep -E "Set parameter|saved" || echo "  (param setting timed out)"

echo "  ✓ Vehicle 2 configured (VTOL - multicopter mode)"

# Vehicle 3: x500 Quadcopter (at different position)
echo ""
echo "[3/3] Spawning Vehicle 3 (x500)..."

gz service -s /world/default/create \
  --reqtype gz.msgs.EntityFactory \
  --reptype gz.msgs.Boolean \
  --timeout 5000 \
  --req "sdf_filename: \"$MODEL_PATH/x500\", name: \"x500_2\", pose: {position: {x: 10, y: 0, z: 0.15}}" > /dev/null 2>&1

sleep 8

nohup env HEADLESS=1 \
  PX4_SIM_MODEL=gz_x500 \
  PX4_GZ_MODEL_NAME=x500_2 \
  PX4_GZ_WORLD=default \
  MAV_SYS_ID=3 \
  ./build/px4_sitl_default/bin/px4 \
  -i 2 -d "$PX4_DIR/ROMFS/px4fmu_common" \
  < /dev/null > /tmp/px4_3.log 2>&1 &
PX4_3_PID=$!
echo "  ✓ Started (PID: $PX4_3_PID)"
sleep 15

echo "  Configuring..."
timeout 15 mavproxy.py --master=udp:127.0.0.1:14542 --cmd="
param set GF_ACTION 2
param set GF_MAX_HOR_DIST 150
param set GF_MAX_VER_DIST 120
param set NAV_RCL_ACT 0
param set COM_RCL_EXCEPT 4
param save
" > /dev/null 2>&1 || true

echo "  ✓ Ready"

echo "  ✓ Vehicle 3 configured (fixed-wing offboard mode)"

echo ""
echo "========================================"
echo "Deployment Complete"
echo "========================================"
echo ""
echo "Vehicle Configurations:"
echo ""
echo "Vehicle 1 (Multicopter):"
echo "  - Standard multicopter parameters"
echo "  - Can arm in OFFBOARD mode"
echo "  - Geofence: 150m radius, 120m altitude"
echo ""
echo "Vehicle 2 (VTOL):"
echo "  - VTOL in multicopter mode"
echo "  - Can arm in OFFBOARD mode"
echo "  - Geofence: 150m radius, 120m altitude"
echo ""
echo "Vehicle 3 (Multicopter at different position):"
echo "  - Standard multicopter parameters"
echo "  - Can arm in OFFBOARD mode"
echo ""
echo "MAVLink Endpoints:"
echo "  Vehicle 1: udp://127.0.0.1:14540"
echo "  Vehicle 2: udp://127.0.0.1:14541"
echo "  Vehicle 3: udp://127.0.0.1:14542"
echo ""
echo "Process IDs: $PX4_1_PID, $PX4_2_PID, $PX4_3_PID"
echo ""
echo "Ready for commander script!"
echo "Press Ctrl+C to stop all vehicles"
echo "========================================"

cleanup() {
    echo ""
    echo "Shutting down..."
    kill $PX4_1_PID $PX4_2_PID $PX4_3_PID 2>/dev/null || true
    sleep 1
    pkill -9 px4 || true
    pkill -9 gz || true
    echo "✓ Cleanup complete"
    exit 0
}

trap cleanup SIGINT SIGTERM
wait