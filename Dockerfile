# Use the official ROS2 Humble image as a base
FROM osrf/ros:humble-desktop-full

# Add alias to the .bashrc for ROS2 setup
RUN echo "alias s='source /opt/ros/humble/setup.bash'" >> /root/.bashrc

# Optional: Ensure bash is used as the default shell
SHELL ["/bin/bash", "-c"]

# Additional setup (if needed)
