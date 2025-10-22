# Use Ubuntu 22.04 Jammy with ROS 2 Humble Desktop Full
FROM osrf/ros:humble-desktop-full

# Arguments for user creation
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install essential packages
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    wget \
    curl \
    git \
    vim \
    nano \
    build-essential \
    cmake \
    python3-pip \
    python3-dev \
    python-is-python3 \
    gdb \
    valgrind \
    locales \
    bash-completion \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages required by PX4
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir \
    empy==3.3.4 \
    pyros-genmsg \
    kconfiglib \
    jsonschema \
    jinja2 \
    pyserial \
    pyyaml \
    packaging \
    toml \
    numpy \
    pandas \
    future \
    lxml \
    cerberus

# Install Gazebo Garden
RUN wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null && \
    apt-get update && \
    apt-get install -y gz-garden && \
    rm -rf /var/lib/apt/lists/*

# Install additional ROS 2 packages
RUN apt-get update && apt-get install -y \
    ros-humble-xacro \
    ros-humble-joint-state-publisher \
    ros-humble-robot-state-publisher \
    && rm -rf /var/lib/apt/lists/*

# Install PX4 dependencies
RUN apt-get update && apt-get install -y \
    astyle \
    lcov \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libgstreamer1.0-dev \
    libgtest-dev \
    ninja-build \
    pkg-config \
    protobuf-compiler \
    libeigen3-dev \
    libopencv-dev \
    libxml2-utils \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    rsync \
    shellcheck \
    unzip \
    xsltproc \
    && rm -rf /var/lib/apt/lists/*

# Install Micro-XRCE-DDS-Agent
RUN cd /tmp && \
    git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git && \
    cd Micro-XRCE-DDS-Agent && \
    mkdir build && cd build && \
    cmake .. && \
    make && \
    make install && \
    ldconfig /usr/local/lib/ && \
    cd / && rm -rf /tmp/Micro-XRCE-DDS-Agent

# Create non-root user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo "$USERNAME:$USERNAME" | chpasswd \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Create workspace directory
RUN mkdir -p /home/$USERNAME/workspace && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME

# Copy post-create script
COPY --chown=$USERNAME:$USERNAME post-create.sh /home/$USERNAME/.devcontainer/post-create.sh
RUN chmod +x /home/$USERNAME/.devcontainer/post-create.sh

# Switch to user
USER $USERNAME
WORKDIR /home/$USERNAME

# Setup ROS 2 environment in bashrc
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc && \
    echo "source /usr/share/gazebo/setup.bash" >> ~/.bashrc && \
    echo "export GZ_SIM_RESOURCE_PATH=\$GZ_SIM_RESOURCE_PATH:/home/$USERNAME/workspace/PX4-Autopilot/Tools/simulation/gz/models" >> ~/.bashrc && \
    echo "export GZ_SIM_SYSTEM_PLUGIN_PATH=\$GZ_SIM_SYSTEM_PLUGIN_PATH:/home/$USERNAME/workspace/PX4-Autopilot/build/px4_sitl_default/build_gz-garden" >> ~/.bashrc && \
    echo 'if [ -f /home/$USERNAME/workspace/ros2_ws/install/setup.bash ]; then' >> ~/.bashrc && \
    echo '    source /home/$USERNAME/workspace/ros2_ws/install/setup.bash' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc && \
    echo 'export WORKSPACE_DIR=/home/$USERNAME/workspace' >> ~/.bashrc && \
    echo 'cd /home/$USERNAME' >> ~/.bashrc

# Set default shell
SHELL ["/bin/bash", "-c"]

# Default command
CMD ["/bin/bash"]