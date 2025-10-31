#!/bin/bash
# GUI Visualization for Multi-Vehicle Simulation
# Launch this AFTER spawn_three_vehicles_headless.sh is running
# This connects to the existing Gazebo server and shows the GUI

set -e

PX4_DIR="$HOME/workspace/PX4-Autopilot"
MODEL_PATH="$PX4_DIR/Tools/simulation/gz/models"

export GZ_SIM_RESOURCE_PATH=$MODEL_PATH:$GZ_SIM_RESOURCE_PATH

echo "========================================"
echo "Launching Gazebo GUI Visualization"
echo "========================================"
echo ""
echo "This will connect to your running simulation"
echo "Make sure spawn_three_vehicles_headless.sh is already running!"
echo ""
echo "Controls:"
echo "  - Mouse: Rotate view (left-click drag)"
echo "  - Mouse: Pan view (middle-click drag)"
echo "  - Mouse: Zoom (scroll wheel)"
echo "  - WASD: Move camera"
echo "  - Shift: Speed up camera movement"
echo ""
echo "Press Ctrl+C to close GUI (simulation keeps running)"
echo ""

# Check if Gazebo server is running
if ! pgrep -f "gz sim" > /dev/null; then
    echo "⚠️  Warning: Gazebo server doesn't appear to be running!"
    echo "Please start spawn_three_vehicles_headless.sh first"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Starting GUI..."
echo ""

# Launch Gazebo GUI client (connects to existing server)
gz sim -g

echo ""
echo "GUI closed. Simulation continues running in background."
echo "To stop the simulation, use Ctrl+C in the spawn script terminal."