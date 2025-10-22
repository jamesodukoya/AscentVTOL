#!/bin/bash
set -e

echo "Running post-create setup..."

# Navigate to workspace
cd /home/user/workspace

# Create workspace structure if it doesn't exist
mkdir -p /home/user/workspace

# Clone PX4-Autopilot if it doesn't exist
if [ ! -d "/home/user/workspace/PX4-Autopilot" ]; then
    echo "Cloning PX4-Autopilot..."
    git clone -b release/1.14 https://github.com/PX4/PX4-Autopilot.git --recursive
    echo "PX4-Autopilot cloned successfully"
else
    echo "PX4-Autopilot already exists, skipping clone"
fi

# Create ROS 2 workspace if it doesn't exist
if [ ! -d "/home/user/workspace/ros2_ws" ]; then
    echo "Creating ROS 2 workspace..."
    mkdir -p /home/user/workspace/ros2_ws/src
    echo "ROS 2 workspace created"
else
    echo "ROS 2 workspace already exists"
fi

# Clone px4_msgs if it doesn't exist
if [ ! -d "/home/user/workspace/ros2_ws/src/px4_msgs" ]; then
    echo "Cloning px4_msgs..."
    cd /home/user/workspace/ros2_ws/src
    git clone -b release/1.14 https://github.com/PX4/px4_msgs.git
    echo "px4_msgs cloned successfully"
else
    echo "px4_msgs already exists"
fi

# Clone px4_ros_com if it doesn't exist
if [ ! -d "/home/user/workspace/ros2_ws/src/px4_ros_com" ]; then
    echo "Cloning px4_ros_com..."
    cd /home/user/workspace/ros2_ws/src
    git clone -b release/v1.14 https://github.com/PX4/px4_ros_com.git
    echo "px4_ros_com cloned successfully"
else
    echo "px4_ros_com already exists"
fi

# Create helpful scripts directory
mkdir -p /home/user/scripts

# Create a script to build PX4
cat > /home/user/scripts/build_px4.sh << 'EOF'
#!/bin/bash
cd /home/user/workspace/PX4-Autopilot
make clean
make px4_sitl gz_x500
EOF
chmod +x /home/user/scripts/build_px4.sh

# Create a script to run PX4 SITL
cat > /home/user/scripts/run_px4_sitl.sh << 'EOF'
#!/bin/bash
cd /home/user/workspace/PX4-Autopilot
make px4_sitl gz_x500
EOF
chmod +x /home/user/scripts/run_px4_sitl.sh

# Create a script to run XRCE-DDS Agent
cat > /home/user/scripts/run_xrce_agent.sh << 'EOF'
#!/bin/bash
MicroXRCEAgent udp4 -p 8888
EOF
chmod +x /home/user/scripts/run_xrce_agent.sh

# Create a script to build ROS 2 workspace
cat > /home/user/scripts/build_ros2_ws.sh << 'EOF'
#!/bin/bash
source /opt/ros/humble/setup.bash
cd /home/user/workspace/ros2_ws
colcon build --symlink-install
source install/setup.bash
EOF
chmod +x /home/user/scripts/build_ros2_ws.sh

# Create README in workspace
cat > /home/user/workspace/README.md << 'EOF'
# PX4 ROS2 Humble Development Environment

This workspace contains your PX4 and ROS 2 development files.

## Directory Structure

- `PX4-Autopilot/` - PX4 firmware source code
- `ros2_ws/` - ROS 2 workspace
  - `src/px4_msgs/` - PX4 message definitions
  - `src/px4_ros_com/` - PX4 ROS 2 communication package

## Quick Start Scripts

Scripts are located in `/home/user/scripts/`:

- `build_px4.sh` - Build PX4 firmware
- `run_px4_sitl.sh` - Run PX4 SITL simulation with Gazebo
- `run_xrce_agent.sh` - Run Micro-XRCE-DDS Agent
- `build_ros2_ws.sh` - Build ROS 2 workspace

## Workflow

### First Time Setup

1. Build PX4:
   ```bash
   /home/user/scripts/build_px4.sh
   ```

2. Build ROS 2 workspace:
   ```bash
   /home/user/scripts/build_ros2_ws.sh
   ```

### Running Simulation

1. Terminal 1 - Run PX4 SITL:
   ```bash
   /home/user/scripts/run_px4_sitl.sh
   ```

2. Terminal 2 - Run XRCE-DDS Agent:
   ```bash
   /home/user/scripts/run_xrce_agent.sh
   ```

3. Terminal 3 - Run ROS 2 nodes:
   ```bash
   source /home/user/workspace/ros2_ws/install/setup.bash
   ros2 launch px4_ros_com sensor_combined_listener.launch.py
   ```

## Notes

- All files in `/home/user/workspace/` persist between container rebuilds
- ROS 2 Humble is pre-installed
- Gazebo Garden is pre-installed
- Micro-XRCE-DDS Agent is pre-installed
EOF

echo "Post-create setup completed successfully!"
echo "Workspace is ready at /home/user/workspace"
