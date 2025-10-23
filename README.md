# AscentVTOL - Autonomous Quad-EDF Thrust-Vectoring VTOL UAV

[![PX4](https://img.shields.io/badge/PX4-Autopilot-blue?logo=px4)](https://px4.io/)
[![ROS2](https://img.shields.io/badge/ROS2-Humble-22314E?logo=ros)](https://docs.ros.org/en/humble/)
[![Gazebo](https://img.shields.io/badge/Gazebo-Garden-orange)](https://gazebosim.org/)
[![Docker](https://img.shields.io/badge/Docker-Dev%20Container-2496ED?logo=docker)](https://code.visualstudio.com/docs/devcontainers/containers)
[![NVIDIA Jetson](https://img.shields.io/badge/NVIDIA-Jetson%20Orin%20Nano-76B900?logo=nvidia)](https://developer.nvidia.com/embedded/jetson-orin)

A comprehensive development environment and engineering platform for an advanced autonomous VTOL UAV featuring quad Electric Ducted Fans (EDFs) with thrust vectoring, integrated AI companion computer, and a complete autonomy stack.

---

## 🎯 Project Overview

AscentVTOL is a high-performance, research-grade Unmanned Aerial Vehicle designed to showcase advanced robotics, AI, and autonomous systems capabilities. The platform combines extreme propulsion performance (8 kgf thrust-to-weight ratio > 2:1) with cutting-edge computational power (NVIDIA Jetson Orin Nano with 40 TOPS) to enable state-of-the-art autonomy research.

### Key Features

- **🚀 Quad-EDF Propulsion**: Four Schubeler DS-30-AXI HDS 69mm EDFs with thrust vectoring
- **🧠 Dual Processing Architecture**: 
  - ARK V6X Flight Controller (STM32H743 @ 480 MHz)
  - NVIDIA Jetson Orin Nano 4GB (40 TOPS AI performance)
- **📡 Advanced Sensors**:
  - Luxonis OAK-D-Lite (Stereo depth + 4K RGB + IMU)
  - ArduSimple RTK GNSS Dual-Antenna Heading Kit (cm-level accuracy)
  - Holybro Digital Airspeed Sensor
- **🔗 Modern Software Stack**: PX4 + ROS 2 Humble + micro-XRCE-DDS bridge
- **🛡️ NDAA Compliant**: Professional-grade, US-built components

---

## 🏗️ Project Phases

This project follows a systematic, phased development approach derived from professional aerospace practices:

### Phase 1: Foundation & Simulation ✅
**Status**: Complete
- [x] Dev Container environment setup
- [x] PX4 firmware build and configuration
- [x] Custom airframe and mixer development
- [x] Software-in-the-Loop (SITL) verification
- [x] Hardware-in-the-Loop (HIL) testing

### Phase 2: Hardware Integration & Ground Testing 🔄
**Status**: In Progress
- [x] Airframe fabrication (carbon fiber)
- [ ] Propulsion system assembly
- [ ] Avionics and power system integration
- [ ] Vibration isolation optimization
- [ ] Ground verification protocol execution

### Phase 3: Flight Testing 🔜
**Status**: Upcoming
- [ ] Tethered hover testing
- [ ] Untethered hover and low-altitude maneuvers
- [ ] VTOL transition testing
- [ ] Forward flight envelope expansion
- [ ] Autonomous mission validation

### Phase 4: Advanced Autonomy 🎯
**Status**: Roadmap
- [ ] Visual-SLAM in GPS-denied environments (Isaac ROS)
- [ ] Vision-based precision landing (AprilTag)
- [ ] Real-time object detection and tracking (YOLOv8)
- [ ] Dynamic obstacle avoidance with depth sensing
- [ ] Multi-sensor fusion and advanced path planning

---

## 🚀 Quick Start

### Prerequisites

1. **Docker**: [Install Docker Desktop](https://www.docker.com/products/docker-desktop/) or [Docker Engine](https://docs.docker.com/engine/install/ubuntu/)
2. **VS Code**: [Download Visual Studio Code](https://code.visualstudio.com/)
3. **Dev Containers Extension**: Install from [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
4. **X11 Display** (for GUI applications):
   - Linux: `xhost +local:docker`
   - Windows: [VcXsrv](https://sourceforge.net/projects/vcxsrv/)
   - Mac: [XQuartz](https://www.xquartz.org/)

### Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone https://github.com/jamesodukoya/AscentVTOL.git
   cd AscentVTOL
   ```

2. **Open in VS Code**:
   ```bash
   code .
   ```

3. **Reopen in Dev Container**:
   - Press `F1` → `Dev Containers: Reopen in Container`
   - Wait for initial build (~10-15 minutes first time)

4. **Install Python dependencies** (one-time):
   ```bash
   pip3 install future lxml cerberus
   ```

5. **Build the workspace**:
   ```bash
   # Build PX4 firmware
   /home/user/scripts/build_px4.sh
   
   # Build ROS 2 workspace
   /home/user/scripts/build_ros2_ws.sh
   ```

### Running Simulations

You'll need **three terminals** in VS Code:

#### Terminal 1 - PX4 SITL:
```bash
/home/user/scripts/run_px4_sitl.sh
```

#### Terminal 2 - XRCE-DDS Agent:
```bash
/home/user/scripts/run_xrce_agent.sh
```

#### Terminal 3 - ROS 2 Nodes:
```bash
source /home/user/workspace/ros2_ws/install/setup.bash
ros2 topic list
ros2 topic echo /fmu/out/vehicle_status
```

---

## 📁 Project Structure

```
AscentVTOL/
├── .devcontainer/
│   ├── devcontainer.json      # Dev Container configuration
│   ├── Dockerfile              # Ubuntu 22.04 + ROS2 + PX4 environment
│   └── post-create.sh          # Automatic workspace setup
├── workspace/                  # Persistent development workspace
│   ├── PX4-Autopilot/         # PX4 firmware (auto-cloned)
│   ├── ros2_ws/               # ROS 2 workspace
│   │   └── src/
│   │       ├── px4_msgs/      # PX4 message definitions
│   │       └── px4_ros_com/   # PX4-ROS2 communication bridge
│   └── README.md              # Workspace documentation
├── .gitignore
└── README.md                   # This file
```

---

## 🔧 System Architecture

### Computational Core
- **Flight Controller**: ARK V6X (FMUv6X standard)
  - Triple-redundant IMU array
  - 1W onboard heater for cold-weather ops
  - PAB form factor for seamless integration
- **Companion Computer**: NVIDIA Jetson Orin Nano 4GB
  - 40 TOPS AI inference performance
  - CUDA-accelerated libraries
  - TensorRT for optimized neural networks

### Propulsion System (280A+ Total)
- **Motors**: 4x Schubeler HET 2W-23 + DS-30-AXI HDS (69mm)
  - 2.0 kgf thrust per unit @ 70A (5S)
  - Total: 8.0 kgf static thrust
- **ESCs**: 4x Graupner +T 100A (OPTO-isolated)
  - Telemetry support (RPM, voltage, current, temp)
- **Servos**: 16x 55kg-cm brushless digital servos
  - Extreme torque for precise thrust vectoring

### Power Distribution
- **Batteries**: 2x CNHL 5200mAh 5S 90C LiPo (parallel per vehicle)
  - 10.4Ah capacity, 936A theoretical discharge
- **PDB**: EFT 480A High Current Power Distribution Board
- **Avionics Power**: ARK PAB Power Module (5V/6A, isolated)
- **Servo Power**: External 20A+ switching BEC (brownout prevention)

### Sensor Suite
- **Vision**: Luxonis OAK-D-Lite (hardware-synchronized stereo + 4K RGB + IMU)
- **GNSS**: ArduSimple simpleRTK2B Dual ZED-F9P (RTK heading, no magnetometer)
- **Airspeed**: Holybro Digital I2C sensor

### Communications
- **RC Control**: RadioMaster Pocket (EdgeTX) + RP3 ELRS Receiver
- **Telemetry**: Integrated via ROS 2 DDS network

---

## 🛠️ Development Workflow

### 1. Simulation-First Approach
All control logic is developed and tested in high-fidelity simulation before physical deployment:
- **SITL**: Complete software simulation with Gazebo Garden
- **HIL**: Hardware-in-the-Loop with real flight controller
- **Custom Airframe**: Quad-EDF thrust-vectoring model

### 2. Model-Based Design
Empirical characterization of propulsion system via multi-axis load cell test stand:
- Static thrust mapping (throttle + servo positions)
- Dynamic response identification
- System ID for high-fidelity digital twin

### 3. ROS 2 Integration
Native PX4-ROS2 bridge via micro-XRCE-DDS:
- Low-latency, high-bandwidth communication
- Direct access to internal PX4 uORB topics
- Modular autonomy development

### 4. Phased Flight Testing
Systematic envelope expansion:
1. Tethered hover → 2. Free hover → 3. Transitions → 4. Forward flight → 5. Autonomous missions

---

## 🧪 Autonomy Roadmap

### Project 1: Visual-SLAM (GPS-Denied Navigation)
- **Implementation**: NVIDIA Isaac ROS VSLAM
- **Hardware**: OAK-D-Lite stereo + IMU
- **Goal**: Stable indoor flight without GPS

### Project 2: Precision Landing
- **Implementation**: AprilTag detection + closed-loop control
- **Hardware**: OAK-D-Lite RGB camera
- **Goal**: Centimeter-level autonomous landing accuracy

### Project 3: Object Detection & Tracking
- **Implementation**: YOLOv8 + TensorRT optimization
- **Hardware**: Jetson Orin Nano GPU
- **Goal**: Real-time search and identify missions

### Project 4: Obstacle Avoidance
- **Implementation**: VFH/DWA local planning with depth maps
- **Hardware**: OAK-D-Lite stereo depth
- **Goal**: Safe navigation in cluttered environments

---

## 📚 Publicatations

- **Coming soon**

### Helpful Scripts

Located in `/home/user/scripts/`:
- `build_px4.sh` - Build PX4 firmware
- `run_px4_sitl.sh` - Launch PX4 SITL simulation
- `run_xrce_agent.sh` - Start XRCE-DDS Agent
- `build_ros2_ws.sh` - Build ROS 2 workspace

---

## 🔍 Key Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **OS** | Ubuntu 22.04 LTS | Development platform |
| **Flight Stack** | PX4 Autopilot | Real-time flight control |
| **Middleware** | ROS 2 Humble | Robotics framework |
| **Simulator** | Gazebo Garden | Physics-based testing |
| **AI Framework** | CUDA, TensorRT | GPU-accelerated inference |
| **Bridge Protocol** | micro-XRCE-DDS | PX4-ROS2 communication |
| **Computer Vision** | OpenCV, DepthAI | Perception pipeline |
| **Ground Station** | QGroundControl | Mission planning & monitoring |

---

## 🛡️ Safety & Best Practices

### Ground Testing Protocol
- ✅ All actuator tests performed with rotors removed
- ✅ Comprehensive pre-flight checklist mandatory
- ✅ ESC calibration verification
- ✅ Control surface direction verification
- ✅ RTK GPS lock required for outdoor flights

### EMI Mitigation
- Shielded signal cables
- OPTO-isolated ESCs (prevents motor noise coupling)
- Separate power domains (avionics, servos, propulsion)
- RTK GNSS mounted on mast (away from high-current lines)

### Vibration Management
- Soft-mount avionics stack on damping grommets
- High-quality carbon fiber construction
- Balanced propellers and motors

---

## 🤝 Contributing

This is a personal portfolio project, but suggestions and improvements are welcome! Please open an issue to discuss proposed changes.

---

## 📄 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgments

- **PX4 Development Team**: Open-source flight stack
- **ARK Electronics**: NDAA-compliant hardware ecosystem
- **NVIDIA**: Jetson platform and Isaac ROS
- **ROS 2 Community**: Robotics middleware
- **Schubeler**: High-performance EDF units
- **Original Docker configuration**: [mzahana/px4_ros2_humble](https://github.com/mzahana/px4_ros2_humble)

---

## 📞 Contact

**James Odukoya**  
GitHub: [@jamesodukoya](https://github.com/jamesodukoya)
Email: [odukoyajames@gmail.com](mailto:odukoyajames@gmail.com)
LinkedIn: [linkedin.com/in/thejamesodukoya/](https://www.linkedin.com/in/thejamesodukoya/)

---

## 🚦 Project Status

**Current Phase**: Hardware Integration & Ground Testing  
**Last Updated**: October 2025

| Milestone | Status |
|-----------|--------|
| Dev Environment | ✅ Complete |
| SITL Simulation | ✅ Complete |
| HIL Testing | ✅ Complete |
| Hardware Assembly | 🔄 In Progress |
| Flight Testing | ⏳ Pending |
| Autonomy Stack | 📋 Planned |

---

*Building the future of autonomous aerial systems, one commit at a time.* 🚁✨