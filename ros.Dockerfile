# Verifiable Source: Official ROS 2 Humble Installation Guide
# This Dockerfile sets up a development environment for ROS 2 Humble Hawksbill.

# Use the official ROS 2 Humble base image, which is built on Ubuntu 22.04.
FROM ros:humble

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Create a non-root user
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV HOME /home/$USERNAME
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install ROS 2 tools and Gazebo integration packages.
RUN apt-get update && apt-get install -y \
    python3-colcon-common-extensions \
    ros-dev-tools \
    ros-humble-ros-gz \
    && rm -rf /var/lib/apt/lists/*

USER $USERNAME
WORKDIR $HOME

# Automatically source ROS 2 setup in new shells
RUN echo "source /opt/ros/humble/setup.bash" >> $HOME/.bashrc

# Create the ROS 2 workspace directory
RUN mkdir -p $HOME/ros2_ws/src

WORKDIR $HOME/ros2_ws

# Default command to keep the container interactive
CMD ["bash"]

