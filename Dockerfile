ARG UBUNTU_VERSION=20.04
ARG CUDA_VERSION=11.7.1-cudnn8

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

# change the default shell to Bash
SHELL [ "/bin/bash" , "-c" ]

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && \
    apt-get install -q -y --no-install-recommends tzdata && \
    rm -rf /var/lib/apt/lists/*

# Set environment variable for non-interactive apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary tools
RUN apt-get update && \
    apt-get install -y python3-pip python-is-python3 curl gnupg2 lsb-release python3-tk && \
    rm -rf /var/lib/apt/lists/*

# add the ROS repository
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' \
    && curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -

# Update the package list and install ROS Noetic desktop
RUN apt-get update && \ 
    apt-get install -y ros-noetic-desktop && \
    rm -rf /var/lib/apt/lists/*

# Install ROS python bindings
RUN apt-get update && \ 
    apt-get install -y python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool python3-catkin-tools build-essential && \
    rm -rf /var/lib/apt/lists/*

# Init rosdep
RUN rosdep init && \
    rosdep update

# Source the ROS setup bash file
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc

# Setup environment
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV ROS_DISTRO=noetic

# Install ZED SDK
RUN apt-get update && \ 
    apt-get install zstd && \
    curl -L https://download.stereolabs.com/zedsdk/4.1/cu118/ubuntu20 -o zedsdk_installer.zstd.run && \
    chmod +x zedsdk_installer.zstd.run && \
    ./zedsdk_installer.zstd.run -- silent skip_cuda && \
    rm -r ./zedsdk_installer.zstd.run && \
    rm -rf /var/lib/apt/lists/*


# Install python packages from requirements.txt
COPY ./requirements.txt /
RUN python -m pip install -r requirements.txt && \
    rm -r ./requirements.txt

# copy robotblockset package and buid it
# robotblockset master branch
COPY ./robotblockset /robotblockset
# robotblockset panda_ros branch
# COPY ./robotblockset_python-panda_ros /robotblockset
# robotblockset old testing branch
# COPY ./robotblockset_python-old_testing /robotblockset
RUN cd /robotblockset && \
    python3 -m pip install -e .

# Set the PYTHONPATH environment variable
# ENV PYTHONPATH="/robotblockset:${PYTHONPATH}"

# create a ROS workspace
RUN mkdir -p airo_ws/ros_ws/src/

# copy ROS msgs to ROS workspace and build the workspace
COPY ./franka_ros/franka_msgs /airo_ws/ros_ws/src/franka_msgs
# copy franka_gripper package. We changed the Cmake file to remove the 
# dependency to frankalib. To revert just uncomment the commented lines
COPY ./franka_ros/franka_gripper /airo_ws/ros_ws/src/franka_gripper
COPY ./robot_module_msgs /airo_ws/ros_ws/src/robot_module_msgs
RUN source /opt/ros/noetic/setup.bash && \
    cd /airo_ws/ros_ws && \ 
    catkin_make

RUN apt-get update && \ 
    apt-get install -y ros-noetic-ros-control ros-noetic-ros-controllers && \
    rm -rf /var/lib/apt/lists/*

# Source the ROS setup bash file for the environment
RUN echo "source /airo_ws/ros_ws/devel/setup.bash" >> ~/.bashrc

# install ompl
# RUN apt-get update && \
#     apt-get install -y cmake g++ python3-dev python3-pip libboost-all-dev castxml
# RUN sudo -H pip3 install -vU pygccxml pyplusplus
# RUN git clone https://github.com/ompl/ompl.git
# RUN cd ompl && \
#     mkdir -p build/Release && \
#     cd build/Release && \
#     cmake ../.. -DPYTHON_EXECUTABLE=$(which python3) -DOMPL_BUILD_PYBINDINGS=ON && \
#     make -j 4 update_bindings
# RUN cd ompl/build/Release && \
#     make install

# install python 3.10
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt install -y python3.10 python3.10-tk && \
    rm -rf /var/lib/apt/lists/*

# create a python 3.10 virtual environment
RUN mkdir /environments && \
    cd /environments && \
    python -m pip install virtualenv &&\
    virtualenv -p python3.10 airo

# install packages in the virtual environment
COPY ./requirements_venv.txt /environments/airo
RUN source /environments/airo/bin/activate && \
    python -m pip install -r /environments/airo/requirements_venv.txt

##### install airo packages in editable mode                          #####
##### for non editable mode comment out the following package install #####
##### and uncomment lines in requirements_venv.txt                    #####

# create a directory for used airo libraries
RUN mkdir /airo_ws/airo_libraries
COPY ./airo_libraries /airo_ws/airo_libraries

# airo mono
RUN source /environments/airo/bin/activate && \
    cd /airo_ws/airo_libraries/airo-mono && \
    python -m pip install -e airo-typing -e airo-spatial-algebra -e airo-dataset-tools -e airo-camera-toolkit -e airo-robots -e airo-teleop

# airo models
RUN source /environments/airo/bin/activate && \
    cd /airo_ws/airo_libraries/airo-models && \
    python -m pip install -e .

# airo drake
RUN source /environments/airo/bin/activate && \
    cd /airo_ws/airo_libraries/airo-drake && \
    python -m pip install -e .

# airo planner
RUN source /environments/airo/bin/activate && \
    cd /airo_ws/airo_libraries/airo-planner && \
    python -m pip install -e .

# linen (dependency for cloth tools)
RUN source /environments/airo/bin/activate && \
    cd /airo_ws/airo_libraries/linen/linen && \
    python -m pip install -e .

# cloth tools
RUN source /environments/airo/bin/activate && \
    cd /airo_ws/airo_libraries/cloth-competition/cloth-tools && \
    python -m pip install -e .

# add zed sdk python to virtual environment
RUN source /environments/airo/bin/activate && \
    python /usr/local/zed/get_python_api.py
    
# ROS entrypoint
COPY ./ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
