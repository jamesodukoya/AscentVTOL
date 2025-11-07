#!/bin/bash

# PX4 v1.14 Multi-vehicle SITL with different SIH airframes
# Simplified approach: Uses PX4's default MAVLink configuration

set -e

# Configuration
PX4_DIR="${PX4_DIR:-$HOME/workspace/PX4-Autopilot}"
LOG_DIR="/tmp/px4_logs"
NUM_VEHICLES=3
BASE_PORT=14540
HEADLESS=1
BUILD_BINARY="./build/px4_sitl_default/bin/px4"

# Different airframes for each vehicle
AIRFRAMES=(10040 10041 10042)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  PX4 Multi-Instance Launcher v2"
echo "  3 Drones - Different Airframes"
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
    LOG_FILE="$LOG_DIR/px4_$((i+1)).log"
    
    echo -e "${GREEN}[Drone $((i+1))] Starting instance $i${NC}"
    echo -e "  Airframe: $AIRFRAME"
    echo -e "  Port: $PORT"
    
    # Start PX4 instance
    # PX4 will automatically create MAVLink on port BASE_PORT + i
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
    echo ""
    echo "  Drone $((i+1)) (Instance $i): PID ${PIDS[$i]}"
    echo "    Airframe: $AIRFRAME"
    echo "    MAVLink: udp://127.0.0.1:$PORT"
    echo "    Log: /tmp/px4_logs/px4_$((i+1)).log"
done

echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Wait 20-30 seconds for full initialization"
echo "  • MAVLink servers run on ports 14540-14542"
echo "  • Connect using: udp:127.0.0.1:14540 (not udpin!)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Wait 20 more seconds"
echo "  2. Test: python3 test_connections.py"
echo "  3. Run: python3 autonomous_flight_fixed.py"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  Monitor logs: tail -f /tmp/px4_logs/px4_1.log"
echo "  Stop all: pkill -9 px4"
echo "  Check MAVLink: grep -i mavlink /tmp/px4_logs/px4_1.log"
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