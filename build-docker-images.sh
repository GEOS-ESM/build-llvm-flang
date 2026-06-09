#!/bin/bash

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Builds and pushes the Ubuntu-based LLVM Flang and OpenMPI Docker images."
    echo ""
    echo "Options:"
    echo "  -l VERSION   LLVM major version to install via apt.llvm.org (default: 22)"
    echo "  -m VERSION   OpenMPI version to build (default: 5.0.10)"
    echo "  -n           Dry run: print docker commands without executing them"
    echo "  -h           Print this help message"
    echo ""
    echo "Images built and pushed:"
    echo "  gmao/llvm-flang:\$LLVM_VERSION   (also tagged :latest)"
    echo "  gmao/llvm-flang-openmpi:\$LLVM_VERSION   (also tagged :latest)"
    echo ""
    echo "Examples:"
    echo "  $0                        # build with defaults (LLVM 22, OpenMPI 5.0.10)"
    echo "  $0 -l 21                  # use LLVM 21"
    echo "  $0 -m 5.0.9               # use OpenMPI 5.0.9"
    echo "  $0 -l 21 -m 5.0.9         # combine both"
    echo "  $0 -n                     # dry run"
    exit 0
}

LLVM_VERSION=22
MPI_VERSION=5.0.10
DRY_RUN=0

while getopts ":l:m:nh" opt; do
    case $opt in
        l) LLVM_VERSION=$OPTARG ;;
        m) MPI_VERSION=$OPTARG ;;
        n) DRY_RUN=1 ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; exit 1 ;;
        \?) echo "Error: unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

DATE=$(date '+%F')

## Flang ##

run docker build --no-cache --progress=plain \
    -f Dockerfile.flang \
    --build-arg llvmversion=${LLVM_VERSION} \
    -t gmao/llvm-flang:${LLVM_VERSION} \
    -t gmao/llvm-flang:latest \
    . 2>&1 | tee build.flang.${LLVM_VERSION}.log

run docker push gmao/llvm-flang:${LLVM_VERSION}
run docker push gmao/llvm-flang:latest

## Open MPI ##

run docker build --no-cache --progress=plain \
    -f Dockerfile.openmpi \
    --build-arg mpiversion=${MPI_VERSION} \
    -t gmao/llvm-flang-openmpi:${LLVM_VERSION} \
    -t gmao/llvm-flang-openmpi:latest \
    . 2>&1 | tee build.openmpi.${LLVM_VERSION}.log

run docker push gmao/llvm-flang-openmpi:${LLVM_VERSION}
run docker push gmao/llvm-flang-openmpi:latest
