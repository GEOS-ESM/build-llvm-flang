FROM ubuntu:24.04

# Needed so tzdata isn't interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
       build-essential \
       cmake \
       curl \
       gfortran \
       git \
       ninja-build \
       wget && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# We will be running a script called "build-flang-f18.sh" that will
# download and build the flang compiler. This script will be copied
# to the container and run as part of the build process.
COPY build-flang-f18.sh /opt/build-flang-f18.sh

ARG llvmversion=main

# Next we will run the script to build the flang compiler with the options:
# build-flang-f18.sh --prefix=/opt/llvm-flang --llvm-version=$llvmversion

RUN /opt/build-flang-f18.sh --prefix=/opt/llvm-flang --llvm-version=${llvmversion}

# Set the PATH to include the flang compiler
ENV PATH=/opt/llvm-flang/bin:$PATH
ENV CC=/opt/llvm-flang/bin/clang
ENV CXX=/opt/llvm-flang/bin/clang++
ENV FC=/opt/llvm-flang/bin/flang-new

ENTRYPOINT ["/bin/bash"]

# Build command
# > docker build -f Dockerfile [--build-arg llvmversion=x.y.z] -t gmao/llvm-flang:<version> .
