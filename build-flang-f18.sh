#!/bin/bash -xe

ulimit -n 65536

# -x: verbose
# -e: exit on error

# Ninja is recommended for best build efficiency and speed
# always use the ".zip" source file

# adapted from https://github.com/jeffhammond/HPCInfo/blob/master/buildscripts/llvm-git.sh

remote="${1:-https://github.com/llvm/llvm-project/archive/refs/heads/main.zip}"
[[ -z $remote ]] && { echo "Usage: $0 [archive_url]" && exit 1; }

# use TMPDIR if not empty, else /tmp
TMPDIR=${TMPDIR:-/tmp}

llvm_src=${TMPDIR}/llvm-src
llvm_build=${TMPDIR}/llvm-build
prefix=/ford1/share/gmao_SIteam/llvm-flang/$(date +%F)
stem=$(basename ${remote} .zip)
cmake_root=${llvm_src}/llvm-project-${stem}/llvm

llvm_projects="lld;mlir;clang;flang;openmp;pstl"

echo "LLVM projects: $llvm_projects"
echo "LLVM source: $llvm_src"
echo "LLVM build: $llvm_build"
echo "LLVM install: $prefix"

mkdir -p $prefix
mkdir -p $llvm_src
mkdir -p $llvm_build


# Git not used as it's so slow for a huge project history like LLVM.
# git clone --recursive https://github.com/llvm/llvm-project.git $llvm_src

# ~300 MB
archive=${TMPDIR}/llvm_main.zip

# Download/update the source
[[ -f $archive ]] || curl --location --output ${archive} ${remote}


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
