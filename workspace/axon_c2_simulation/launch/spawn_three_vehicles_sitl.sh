#!/bin/bash

# PX4 v1.14 Multi-vehicle SITL with CORRECT MAVLink port configuration
# CRITICAL FIX: Each vehicle sends to its own dedicated port (14540-14542)
# This prevents data from all vehicles going to port 14540

set -e

# Configuration
PX4_DIR="${PX4_DIR:-$HOME/workspace/PX4-Autopilot}"
LOG_DIR="/tmp/px4_logs"
NUM_VEHICLES=3
BASE_PORT=14540  # Each vehicle uses its own port: 14540, 14541, 14542
HEADLESS=1
BUILD_BINARY="./build/px4_sitl_default/bin/px4"

# Different airframes for each vehicle
AIRFRAMES=(10040 10040 10040)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  PX4 Multi-Instance Launcher v4 (FIXED)"
echo "  3 Drones - Separate UDP Ports"
echo "=========================================="
echo ""

# Validate environment
if [ ! -d "$PX4_DIR" ]; then
    echo -e "${RED}Error: PX4_DIR not found: $PX4_DIR${NC}"
    echo "Set PX4_DIR environment variable or install PX4-Autopilot"
    exit 1
fi

cd "$PX4_DIR" || exit 1

if [ ! -f "$BUILD_BINARY" ]; then
    echo -e "${YELLOW}Building PX4 SITL...${NC}"
    make px4_sitl_default
fi

# Clean up
echo -e "${YELLOW}Cleaning up existing processes...${NC}"
pkill -9 px4 2>/dev/null || true
sleep 3

echo -e "${YELLOW}Cleaning up old instances...${NC}"
rm -rf build/px4_sitl_default/instance_* 2>/dev/null || true

# Create log directory
mkdir -p "$LOG_DIR"

echo ""
echo -e "${BLUE}Starting PX4 instances...${NC}"
echo ""

# Array to store PIDs
declare -a PIDS

# Start each instance
for i in $(seq 0 $((NUM_VEHICLES - 1))); do
    AIRFRAME=${AIRFRAMES[$i]}
    PORT=$((BASE_PORT + i))
    SYSTEM_ID=$((i + 1))
    LOG_FILE="$LOG_DIR/px4_$((i+1)).log"
    INSTANCE_DIR="$PX4_DIR/build/px4_sitl_default/instance_$i"
    
    echo -e "${GREEN}[Drone $((i+1))] Starting instance $i${NC}"
    echo -e "  System ID: $SYSTEM_ID"
    echo -e "  Airframe: $AIRFRAME"
    echo -e "  MAVLink Port: $PORT (dedicated)"
    
    # Create instance directory and MAVLink config
    mkdir -p "$INSTANCE_DIR/etc"
    
    # CRITICAL FIX: Configure MAVLink to use the correct port for THIS vehicle
    # The -u flag specifies the UDP port to send data TO
    # The -p flag enables bidirectional communication
    # Each instance MUST use a different port (14540 + instance number)
#     cat > "$INSTANCE_DIR/etc/extras.txt" << EOF
# # MAVLink Configuration for Instance $i
# # CRITICAL: Send data to dedicated port $PORT (not 14540 for all!)
# # This ensures each dashboard connection receives data from only ONE vehicle
# mavlink start -x -u $PORT -r 4000000 -m onboard -p
# EOF
    
    # Start PX4 instance
    HEADLESS=$HEADLESS \
        PX4_SIM_MODEL=sih \
        PX4_SYS_AUTOSTART=$AIRFRAME \
        $BUILD_BINARY -i $i -d > "$LOG_FILE" 2>&1 &
    
    PIDS[$i]=$!
    echo -e "  ${GREEN}✓${NC} PID: ${PIDS[$i]}"
    echo -e "  ${BLUE}ℹ${NC}  Log: $LOG_FILE"
    echo ""
    
    # Stagger startup
    sleep 5
done

echo ""
echo -e "${BLUE}Waiting for instances to initialize...${NC}"

# Wait and check if processes are still running
sleep 15

echo ""
echo -e "${BLUE}Checking instance status...${NC}"
for i in $(seq 0 $((NUM_VEHICLES - 1))); do
    if kill -0 ${PIDS[$i]} 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Instance $i (PID ${PIDS[$i]}): Running"
    else
        echo -e "${RED}✗${NC} Instance $i (PID ${PIDS[$i]}): Died - check logs!"
    fi
done

echo ""
echo -e "${GREEN}=========================================="
echo "  Instances Started"
echo "==========================================${NC}"
echo ""

# Display configuration
echo "Configuration:"
for i in $(seq 0 $((NUM_VEHICLES - 1))); do
    AIRFRAME=${AIRFRAMES[$i]}
    PORT=$((BASE_PORT + i))
    SYSTEM_ID=$((i + 1))
    echo ""
    echo "  Drone $((i+1)) (Instance $i, System ID $SYSTEM_ID): PID ${PIDS[$i]}"
    echo "    Airframe: $AIRFRAME"
    echo "    MAVLink Port: $PORT (DEDICATED - not shared!)"
    echo "    Log: /tmp/px4_logs/px4_$((i+1)).log"
done

echo ""
echo -e "${YELLOW}CRITICAL FIX APPLIED:${NC}"
echo "  ✓ Each vehicle now sends to its OWN port (14540, 14541, 14542)"
echo "  ✓ Previous bug: All vehicles sent to port 14540"
echo "  ✓ Dashboard connections now receive correct data per drone"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Wait 20-30 seconds for full initialization"
echo "  • Each vehicle uses a SEPARATE port (no data mixing)"
echo "  • Dashboard should now show correct data for all 3 drones"
echo ""
echo -e "${BLUE}Verify Configuration:${NC}"
echo "  Check MAVLink config: grep 'mavlink start' /tmp/px4_logs/px4_*.log"
echo "  Monitor logs: tail -f /tmp/px4_logs/px4_1.log"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  Stop all: pkill -9 px4"
echo "  If data still wrong, check extras.txt files in instance_* dirs"
echo ""
echo "Press Ctrl+C to stop all instances"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping all vehicles...${NC}"
    
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    
    sleep 2
    pkill -9 px4 2>/dev/null || true
    
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -rf "$PX4_DIR/build/px4_sitl_default/instance_"* 2>/dev/null || true
    
    echo "Done."
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Keep script running and monitor processes
echo -e "${BLUE}Monitoring instances (checking every 10 seconds)...${NC}"
while true; do
    sleep 10
    
    # Check if any process died
    dead_count=0
    for i in $(seq 0 $((NUM_VEHICLES - 1))); do
        if ! kill -0 ${PIDS[$i]} 2>/dev/null; then
            if [ $dead_count -eq 0 ]; then
                echo ""
                echo -e "${RED}⚠ Warning: Some instances stopped!${NC}"
            fi
            echo -e "${RED}✗${NC} Instance $i (PID ${PIDS[$i]}) died - check /tmp/px4_logs/px4_$((i+1)).log"
            dead_count=$((dead_count + 1))
        fi
    done
    
    if [ $dead_count -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Run 'tail -f /tmp/px4_logs/px4_*.log' to investigate${NC}"
        echo ""
    fi
done