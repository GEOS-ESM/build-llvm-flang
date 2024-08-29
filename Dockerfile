FROM ubuntu:24.04

# Needed so tzdata isn't interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
       build-essential \
       cmake \
       curl \
       git \
       m4 \
       ninja-build \
       python3 \
       wget && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash"]

# We will be running a script called "build-flang-f18.sh" that will
# download and build the flang compiler. This script will be copied
# to the container and run as part of the build process.
COPY build-flang-f18.sh /opt/build-flang-f18.sh

ARG llvmversion=main

# Next we will run the script to build the flang compiler with the options

RUN CC=gcc CXX=g++ /opt/build-flang-f18.sh --prefix=/opt --llvm-version=${llvmversion} --no-gold

# Set the PATH to include the flang compiler
ENV PATH=/opt/llvm-flang/bin:$PATH
ENV CC=/opt/llvm-flang/bin/clang
ENV CXX=/opt/llvm-flang/bin/clang++
ENV FC=/opt/llvm-flang/bin/flang-new


# Build command for main tarfile
#   docker build --no-cache --progress=plain -f Dockerfile -t gmao/llvm-flang:<version> . 2>&1 | tee build.log
# Build command with a specific version of LLVM
#   docker build --no-cache --progress=plain -f Dockerfile --build-arg llvmversion=19.1.0-rc3 -t gmao/llvm-flang:19.1.0-rc3 . 2>&1 | tee build.log
