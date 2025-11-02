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

Github workflow now set up
