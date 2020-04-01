#Download base image ubuntu 16.04 for vSensor

FROM ubuntu:16.04

# Setting environment variable to use during build process

ARG DEBIAN_FRONTEND=noninteractive

# Used to install reolvconf inside a container

RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

# Update software repository

RUN apt-get autoclean && apt-get autoremove && apt-get clean \
  && apt-get update -y \
  && apt-get full-upgrade -y \
  && apt-get upgrade --fix-missing \
  && apt-get install sudo -y \
  && apt-get install lib32readline6 -y \
  && apt-get install lib32readline6-dev -y \
  && apt-get --allow-change-held-packages install resolvconf -y \
  # && sudo dpkg --configure resolvconf \
  && apt-get install console-setup -y \
  && apt-get install kbd -y \
  && apt-get install console-setup-linux -y \
  && apt-get install ubuntu-minimal -y 

# Set working directory

WORKDIR /Desktop/

# Copy vSensor install script from host to container file system

COPY install.sh .

# Run the vSensor install script when the container launches

CMD echo ${test} | /Desktop/install.sh 





