#Download base image ubuntu 16.04 for vSensor

FROM ubuntu:16.04

# Update software repository

RUN apt-get update -y && apt-get upgrade -y && apt-get install sudo -y

# Set working directory

WORKDIR /Desktop/

# Copy vSensor install script from host to container file system

COPY install.sh .

# Run the vSensor install script when the container launches

CMD echo ${test} | /Desktop/install.sh 





