# Dockerfile may have following Arguments:
# tag - tag for the Base image, (e.g. 2.9.1 for tensorflow)
# branch - user repository branch to clone, i.e. test (default: main)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .
#
# Be Aware! For the Jenkins CI/CD pipeline, 
# input args are defined inside the JenkinsConstants.groovy, not here!

ARG tag=1.13.1-cuda11.6-cudnn8-runtime

# Base image, e.g. tensorflow/tensorflow:2.x.x-gpu
FROM pytorch/pytorch:${tag}

LABEL maintainer='Fahimeh Alibabaei '
LABEL version='0.0.1'
# Support for inference of the AI4LIFE model on the marketplace.

# What user branch to clone [!]
ARG branch=main

# Install Ubuntu packages
# - gcc is needed in Pytorch images because deepaas installation might break otherwise (see docs)
#   (it is already installed in tensorflow images)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Update python packages
# [!] Remember: DEEP API V2 only works with python>=3.6
RUN python3 --version && \
    pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

# Initialization scripts
# deep-start can install JupyterLab or VSCode if requested
RUN git clone https://github.com/ai4os/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Necessary for the Jupyter Lab terminal
ENV SHELL /bin/bash

# Install Data Version Control
RUN pip3 install --no-cache-dir dvc dvc-webdav

# Install rclone (needed if syncing with NextCloud for training; otherwise remove)
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && \
    touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    rm -rf /var/lib/apt/lists/*
ENV RCLONE_CONFIG=/srv/.rclone/rclone.conf

RUN curl -o all_versions.json https://uk1s3.embassy.ebi.ac.uk/public-datasets/bioimage.io/all_versions.json
# Install user app
RUN git clone -b $branch --depth 1 https://github.com/ai4os-hub/ai4life && \
    cd ai4life && \
    pip3 install --no-cache-dir -e . && \
    curl -o ./models/all_versions.json https://uk1s3.embassy.ebi.ac.uk/public-datasets/bioimage.io/all_versions.json

# Open ports: DEEPaaS (5000), Monitoring (6006), Jupyter (8888)
EXPOSE 5000 6006 8888

# Launch deepaas
ENTRYPOINT [ "deep-start" ]
CMD ["--deepaas"]
