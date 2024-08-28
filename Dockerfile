FROM ubuntu:24.04

# Needed so tzdata isn't interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
       build-essential \
       cmake \
       git \
       ninja-build \
       wget && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*


# Build command
# > docker build --build-arg cmakeversion=x.y.z -f Dockerfile -t gmao/llvm-flang:<version> .
