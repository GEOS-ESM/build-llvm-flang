#!/bin/bash

DATE=$(date '+%F')

## Flang ##

docker build --no-cache --progress=plain -f Dockerfile.flang -t gmao/llvm-flang:$DATE -t gmao/llvm-flang:latest . 2>&1 | tee build.flang.$DATE.log

docker tag gmao/llvm-flang:$DATE gmao/llvm-flang

docker push gmao/llvm-flang:$DATE
docker push gmao/llvm-flang:latest

## Open MPI ##

docker build --no-cache --progress=plain -f Dockerfile.openmpi -t gmao/llvm-flang-openmpi . 2>&1 | tee build.openmpi.$DATE.log

docker push gmao/llvm-flang-openmpi:latest
