#!/bin/bash -xe

ulimit -n 65536

# -x: verbose
# -e: exit on error

# Ninja is recommended for best build efficiency and speed

# adapted from https://github.com/jeffhammond/HPCInfo/blob/master/buildscripts/llvm-git.sh

# use TMPDIR if not empty, else /tmp
#TMPDIR=${TMPDIR:-/tmp}
TMPDIR=/ford1/share/gmao_SIteam/llvm-flang/tmp

llvm_src=${TMPDIR}/llvm-src
llvm_build=${TMPDIR}/llvm-build
#prefix=$HOME/llvm-latest
prefix=/ford1/share/gmao_SIteam/llvm-flang/$(date +%F)
cmake_root=${llvm_src}/llvm-project-main/llvm

llvm_projects="lld;mlir;clang;flang;openmp;pstl"

echo "LLVM projects: $llvm_projects"
echo "LLVM source: $llvm_src"
echo "LLVM build: $llvm_build"
echo "LLVM install: $prefix"

mkdir -p $prefix
mkdir -p $llvm_src
mkdir -p $llvm_build


REPO=https://github.com/llvm/llvm-project.git
# ~300 MB
remote=https://github.com/llvm/llvm-project/archive/refs/heads/main.zip
archive=${TMPDIR}/llvm_main.zip

# Download/update the source
[[ -f $archive ]] || curl -L -o $archive $remote
# git clone --recursive $REPO $llvm_src  # so slow

[[ -f ${cmake_root}/CMakeLists.txt ]] || unzip -d $llvm_src $archive

[[ $(which ninja) ]] && CMAKE_GENERATOR="Ninja" || CMAKE_GENERATOR="Unix Makefiles"

case "$(uname -m)" in
  arm64|aarch64)
    llvm_arch=AArch64
    ;;
  *)
    llvm_arch=X86
    ;;
esac

# helpful system parameters

case "$OSTYPE" in
darwin*)
    macos_sysroot=-DDEFAULT_SYSROOT="$(xcrun --show-sdk-path)"
    ;;
*)
    llvm_linker=-DLLVM_USE_LINKER=gold
    ;;
esac\

# lldb busted on MacOS
# libcxx requires libcxxabi
cmake \
  -G"$CMAKE_GENERATOR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD=$llvm_arch \
  -DLLVM_ENABLE_RUNTIMES="libcxxabi;libcxx;libunwind" \
  -DLLVM_ENABLE_PROJECTS=${llvm_projects} \
  $macos_sysroot \
  $llvm_linker \
  --install-prefix=$prefix \
  -S${cmake_root} \
  -B${llvm_build}

cmake --build ${llvm_build}

cmake --install ${llvm_build}
