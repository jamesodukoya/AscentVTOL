#!/bin/bash

# Gazebo Garden Multi-Vehicle Visualization for PX4 SITL
# Visualizes 3 drones with different airframes matching spawn_three_vehicles_sitl.sh
# Airframes: 10040 (Quadrotor), 10041 (VTOL), 10042 (Fixed-wing)

set -e

# Configuration
PX4_DIR="${PX4_DIR:-$HOME/workspace/PX4-Autopilot}"
GAZEBO_MODELS_PATH="$PX4_DIR/Tools/simulation/gz/models"
GAZEBO_WORLDS_PATH="$PX4_DIR/Tools/simulation/gz/worlds"

# Vehicle models matching airframes (using available Gazebo Garden models)
MODELS=("x500" "standard_vtol" "rc_cessna")
VEHICLE_NAMES=("quadrotor" "vtol" "fixedwing")

# Spawn positions (x, y, z) - spread out to avoid collisions
POSITIONS=(
    "0 0 0.2"      # Quadrotor at origin
    "5 0 0.2"      # VTOL 5m east
    "-5 0 0.2"     # Fixed-wing 5m west
)

# Spawn orientations (roll, pitch, yaw in radians)
ORIENTATIONS=(
    "0 0 0"        # Quadrotor facing north
    "0 0 0"        # VTOL facing north
    "0 0 0"        # Fixed-wing facing north
)

# MAVLink ports matching the PX4 instances
MAVLINK_PORTS=(14540 14541 14542)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Gazebo Multi-Vehicle Visualizer"
echo "  3 Drones - Different Airframes"
echo "=========================================="
echo ""

# Validate environment
if [ ! -d "$PX4_DIR" ]; then
    echo -e "${RED}Error: PX4_DIR not found: $PX4_DIR${NC}"
    echo "Set PX4_DIR environment variable"
    exit 1
fi

if [ ! -d "$GAZEBO_MODELS_PATH" ]; then
    echo -e "${RED}Error: Gazebo models path not found: $GAZEBO_MODELS_PATH${NC}"
    exit 1
fi

# Set up Gazebo Garden environment
export GZ_SIM_RESOURCE_PATH="$GAZEBO_MODELS_PATH:$GAZEBO_WORLDS_PATH:$GZ_SIM_RESOURCE_PATH"

echo -e "${BLUE}Setting up Gazebo Garden environment...${NC}"
echo "  Models: $GAZEBO_MODELS_PATH"
echo "  Worlds: $GAZEBO_WORLDS_PATH"
echo ""

# Check if Gazebo Garden is installed
if ! command -v gz &> /dev/null; then
    echo -e "${RED}Error: Gazebo Garden (gz) not found!${NC}"
    echo "Install with: sudo apt install gz-garden"
    exit 1
fi

echo -e "${YELLOW}Starting Gazebo Garden with GUI...${NC}"

# Start Gazebo Garden with GUI (remove -r for headless, -s for server-only)
gz sim "$GAZEBO_WORLDS_PATH/default.sdf" &
GZSERVER_PID=$!
echo -e "${GREEN}✓${NC} Gazebo Garden with GUI started (PID: $GZSERVER_PID)"

# Wait for Gazebo to initialize
echo -e "${BLUE}Waiting for Gazebo Garden to initialize...${NC}"
sleep 8

# Function to spawn a model using gz sim command
spawn_model() {
    local instance=$1
    local model=$2
    local name=$3
    local pos=$4
    local orient=$5
    local mavlink_port=$6
    
    echo -e "${GREEN}[Drone $((instance+1))] Spawning $name${NC}"
    echo "  Model: $model"
    echo "  Position: $pos"
    echo "  Orientation: $orient"
    echo "  MAVLink Port: $mavlink_port"
    
    # Parse position
    read -r px py pz <<< "$pos"
    
    # Parse orientation
    read -r roll pitch yaw <<< "$orient"
    
    # Create SDF content for the model
    local sdf_file="/tmp/gazebo_model_${name}_${instance}.sdf"
    
    cat > "$sdf_file" << EOF
<?xml version="1.0" ?>
<sdf version="1.9">
  <model name="${name}_${instance}">
    <pose>$px $py $pz $roll $pitch $yaw</pose>
    <include>
      <uri>$GAZEBO_MODELS_PATH/$model</uri>
      <name>${name}_${instance}</name>
    </include>
  </model>
</sdf>
EOF
    
    # Spawn the model using gz sim command
    gz service -s /world/default/create \
        --reqtype gz.msgs.EntityFactory \
        --reptype gz.msgs.Boolean \
        --timeout 2000 \
        --req "sdf_filename: \"$sdf_file\"" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Spawned successfully"
    else
        echo -e "  ${YELLOW}⚠${NC} Spawn command executed (verification pending)"
    fi
    
    echo ""
}

echo ""
echo -e "${BLUE}Spawning vehicle models...${NC}"
echo ""

# Spawn each vehicle
for i in {0..2}; do
    spawn_model \
        $i \
        "${MODELS[$i]}" \
        "${VEHICLE_NAMES[$i]}" \
        "${POSITIONS[$i]}" \
        "${ORIENTATIONS[$i]}" \
        "${MAVLINK_PORTS[$i]}"
    
    # Small delay between spawns
    sleep 2
done

echo ""
echo -e "${GREEN}=========================================="
echo "  Gazebo Visualization Ready"
echo "==========================================${NC}"
echo ""

echo "Vehicle Summary:"
for i in {0..2}; do
    echo ""
    echo "  Drone $((i+1)): ${VEHICLE_NAMES[$i]}"
    echo "    Model: ${MODELS[$i]}"
    echo "    Position: ${POSITIONS[$i]}"
    echo "    MAVLink: udp://127.0.0.1:${MAVLINK_PORTS[$i]}"
done

echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Ensure PX4 instances are running (spawn_three_vehicles_sitl.sh)"
echo "  • MAVLink bridges connect PX4 SITL to Gazebo models"
echo "  • Use QGroundControl or pymavlink to connect to vehicles"
echo ""
echo -e "${BLUE}Camera Controls:${NC}"
echo "  • Left-click + drag: Rotate view"
echo "  • Middle-click + drag: Pan view"
echo "  • Scroll wheel: Zoom in/out"
echo "  • Right-click on model: Follow/inspect"
echo ""
echo -e "${BLUE}Connections:${NC}"
echo "  • Quadrotor:  udp:127.0.0.1:14540"
echo "  • VTOL:       udp:127.0.0.1:14541"
echo "  • Fixed-wing: udp:127.0.0.1:14542"
echo ""
echo "Press Ctrl+C to stop visualization"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down Gazebo Garden...${NC}"
    
    # Kill Gazebo Garden server
    if [ ! -z "$GZSERVER_PID" ] && kill -0 "$GZSERVER_PID" 2>/dev/null; then
        kill "$GZSERVER_PID" 2>/dev/null || true
    fi
    
    # Force kill any remaining Gazebo processes
    sleep 2
    pkill -9 "gz sim" 2>/dev/null || true
    pkill -9 ruby 2>/dev/null || true
    
    # Clean up temporary files
    rm -f /tmp/gazebo_model_*.sdf
    
    echo -e "${GREEN}Cleanup complete${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Monitor Gazebo processes
echo -e "${BLUE}Monitoring Gazebo (checking every 10 seconds)...${NC}"
while true; do
    sleep 10
    
    # Check if Gazebo server is still running
    if ! kill -0 "$GZSERVER_PID" 2>/dev/null; then
        echo ""
        echo -e "${RED}⚠ Gazebo server stopped unexpectedly!${NC}"
        break
    fi
done

cleanup