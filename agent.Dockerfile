# Verifiable Source: Official PX4 ROS 2 User Guide (Setup Micro XRCE-DDS Agent & Client)
# This Dockerfile builds the eProsima Micro XRCE-DDS Agent from source.

FROM ubuntu:22.04

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Clone, build, and install the agent, pinning to the version specified in the guide.
RUN git clone -b v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
RUN cd Micro-XRCE-DDS-Agent \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && make install \
    && ldconfig /usr/local/lib/

# The command to run when the container starts.
# It starts the agent and listens for a UDP connection from the PX4 simulator on port 8888.
CMD ["MicroXRCEAgent", "udp4", "-p", "8888"]