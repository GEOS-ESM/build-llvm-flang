#!/bin/bash -e

# -e: exit on error

# Command line arguments
#  --prefix=PREFIX         install files in PREFIX/llvm-flang (default: /usr/local)
#  --llvm-version=VERSION  LLVM version to build (default: latest main tar.gz)
#  --llvm-projects=LIST    list of LLVM projects to build (default: lld;mlir;clang;flang)
#  --llvm-runtimes=LIST    list of LLVM runtimes to build (default: libcxxabi;libcxx;libunwind;compiler-rt;flang-rt;openmp)
#  --use-gold              use the gold linker
#  --use-lld               use the lld linker
#  --add-date              add the date to the install prefix
#  --rebuild               just rebuild the source but do not download again
#  --strip                 strip the binaries
#  --procs=NUM             number of build procs (default: 6)
#  --just-download         just download the source but do not build
#  --verbose               print commands before execution
#  --gcc-toolchain=PATH    GCC toolchain root (also available via env GCC_TOOLCHAIN)
#  -n | --dry-run          print commands without execution
#  -h | --help             print help
#
# Environment:
#   TMPDIR         scratch area for src/build (default: /tmp)
#   CC, CXX        required unless --just-download is used
#   GCC_TOOLCHAIN  GCC toolchain root (e.g. /ford1/local/gcc/gcc-12.5.0)

usage() {
  printf "Usage: %s [options]\n" "$0"
  printf "Options:\n"
  printf "  --prefix=PREFIX         install files in PREFIX [default: /usr/local]\n"
  printf "  --llvm-version=VERSION  LLVM version to build [default: latest main tar.gz]\n"
  printf "  --llvm-projects=LIST    list of LLVM projects to build [default: lld;mlir;clang;flang]\n"
  printf "  --llvm-runtimes=LIST    list of LLVM runtimes to build [default: libcxxabi;libcxx;libunwind;compiler-rt;flang-rt;openmp]\n"
  printf "  --use-gold              use the gold linker\n"
  printf "  --use-lld               use the lld linker\n"
  printf "  --add-date              add the date to the install prefix\n"
  printf "  --rebuild               just rebuild the source but do not download again\n"
  printf "  --strip                 strip the binaries\n"
  printf "  --procs=NUM             number of build procs [default: 6]\n"
  printf "  --just-download         just download the source but do not build\n"
  printf "  --verbose               print commands before execution\n"
  printf "  --gcc-toolchain=PATH    GCC toolchain root (or set \$GCC_TOOLCHAIN)\n"
  printf "  -n | --dry-run          print commands without execution\n"
  printf "  -h | --help             print help\n"
  printf "\n"
  printf  "NOTE: Set \$TMPDIR to change the temporary directory where the source is downloaded and built\n"
}

# Default values
LLVM_PREFIX=/usr/local
LLVM_PROJECTS="lld;mlir;clang;flang"
LLVM_RUNTIMES="libcxxabi;libcxx;libunwind;compiler-rt;flang-rt;openmp"
LLVM_VERSION=main
ADD_DATE=FALSE
DRY_RUN=FALSE
USE_GOLD=FALSE
USE_LLD=FALSE
STRIP=""
PROCS=6
DO_REBUILD=FALSE
JUST_DOWNLOAD=FALSE

# Optional GCC toolchain root (can also be set via env GCC_TOOLCHAIN)
GCC_TOOLCHAIN="${GCC_TOOLCHAIN:-}"

while [ $# -gt 0 ]; do
   case "$1" in
   --prefix=*)
      LLVM_PREFIX="${1#*=}"
      ;;
   --llvm-projects=*)
      LLVM_PROJECTS="${1#*=}"
      ;;
   --llvm-runtimes=*)
      LLVM_RUNTIMES="${1#*=}"
      ;;
   --llvm-version=*)
      LLVM_VERSION="${1#*=}"
      ;;
   --use-gold)
      USE_GOLD=TRUE
      ;;
   --use-lld)
      USE_LLD=TRUE
      ;;
   --add-date)
      ADD_DATE=TRUE
      ;;
   --rebuild)
      DO_REBUILD=TRUE
      ;;
   --just-download)
      JUST_DOWNLOAD=TRUE
      ;;
   --strip)
      STRIP="--strip"
      ;;
   --procs=*)
      PROCS="${1#*=}"
      ;;
   --verbose)
      set -x
      ;;
   --gcc-toolchain=*)
      GCC_TOOLCHAIN="${1#*=}"
      ;;
   -n | --dry-run)
      DRY_RUN=TRUE
      ;;
   -h | --help)
      usage
      exit 0
      ;;
   *)
      printf "***************************\n"
      printf "Error: Invalid argument: %s\n" "$1"
      printf "***************************\n"
      usage
      exit 1
      ;;
  esac
  shift
done

# Try to raise file descriptor limit, but don't die if we can't
ulimit -n 65536 || echo "Warning: ulimit -n 65536 failed, continuing anyway"

# LLVM tarball URL
if [ "$LLVM_VERSION" = "main" ]; then
   remote="https://github.com/llvm/llvm-project/archive/refs/heads/main.tar.gz"
else
   remote="https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${LLVM_VERSION}.tar.gz"
fi

# Use TMPDIR if set; else /tmp
TMPDIR=${TMPDIR:-/tmp}

llvm_src=${TMPDIR}/llvm-src
llvm_build=${TMPDIR}/llvm-build

# Base install prefix
prefix=${LLVM_PREFIX}/llvm-flang

# Add date or version to prefix if requested
if [ "$ADD_DATE" = "TRUE" ]; then
  prefix=${prefix}/$(date +%F)
elif [ "$LLVM_VERSION" != "main" ]; then
  prefix=${prefix}/${LLVM_VERSION}
fi

stem=$(basename ${remote} .tar.gz)
cmake_root=${llvm_src}/llvm-project-${stem}/llvm

llvm_projects=$LLVM_PROJECTS
llvm_runtimes=$LLVM_RUNTIMES

echo "LLVM projects : $llvm_projects"
echo "LLVM runtimes : $llvm_runtimes"
echo "LLVM source   : $llvm_src"
echo "LLVM build    : $llvm_build"
echo "LLVM install  : $prefix"
echo "LLVM version  : $LLVM_VERSION"
echo "LLVM remote   : $remote"
if [ -n "${GCC_TOOLCHAIN}" ]; then
  echo "GCC toolchain : ${GCC_TOOLCHAIN}"
fi

# Require CC and CXX unless we are just downloading
if [ "$JUST_DOWNLOAD" = "FALSE" ]; then
  [[ -z $CC ]] && { echo "CC not set"; exit 1; }
  [[ -z $CXX ]] && { echo "CXX not set"; exit 1; }

  echo "CC:  $CC"
  echo "CXX: $CXX"
fi

if [ "$DRY_RUN" = "TRUE" ]; then
  exit 0
fi

mkdir -p "$prefix"
mkdir -p "$llvm_src"
mkdir -p "$llvm_build"

# Prefer Ninja if available
if command -v ninja >/dev/null 2>&1; then
  CMAKE_GENERATOR="Ninja"
else
  CMAKE_GENERATOR="Unix Makefiles"
fi

case "$(uname -m)" in
  arm64|aarch64)
    llvm_arch=AArch64
    ;;
  *)
    llvm_arch=X86
    ;;
esac

# OS-specific parameters
case "$OSTYPE" in
darwin*)
   macos_sysroot=-DDEFAULT_SYSROOT="$(xcrun --show-sdk-path)"
   quadmath=
   llvm_linker=
   ;;
*)
   macos_sysroot=
   if [ "$USE_GOLD" = "TRUE" ]; then
      llvm_linker=-DLLVM_USE_LINKER=gold
   elif [ "$USE_LLD" = "TRUE" ]; then
      llvm_linker=-DLLVM_USE_LINKER=lld
   else
      llvm_linker=
   fi
   quadmath=-DFLANG_RUNTIME_F128_MATH_LIB=libquadmath
   ;;
esac

###############################################################################
# GCC toolchain wiring (for clang used in runtimes)
###############################################################################

TOOLCHAIN_C_FLAGS=""    # for top-level build (usually empty when CC=gcc)
TOOLCHAIN_CXX_FLAGS=""
RUNTIMES_ARGS=""
EXE_LDFLAGS=""
SHARED_LDFLAGS=""

if [ -n "${GCC_TOOLCHAIN}" ]; then
  # This flag is *for clang*, which the runtimes build uses.
  RUNTIME_TOOLCHAIN_FLAGS="--gcc-toolchain=${GCC_TOOLCHAIN}"

  # rpath so binaries/tests find the right libstdc++
  RUNTIME_RPATH=""
  if [ -d "${GCC_TOOLCHAIN}/lib64" ]; then
    RUNTIME_RPATH="${GCC_TOOLCHAIN}/lib64"
  elif [ -d "${GCC_TOOLCHAIN}/lib" ]; then
    RUNTIME_RPATH="${GCC_TOOLCHAIN}/lib"
  fi

  if [ -n "${RUNTIME_RPATH}" ]; then
    EXTRA_LDFLAGS="-Wl,-rpath,${RUNTIME_RPATH}"
    EXE_LDFLAGS="-DCMAKE_EXE_LINKER_FLAGS=${EXTRA_LDFLAGS}"
    SHARED_LDFLAGS="-DCMAKE_SHARED_LINKER_FLAGS=${EXTRA_LDFLAGS}"
  fi

  # IMPORTANT:
  # - We do NOT pass RUNTIME_TOOLCHAIN_FLAGS to CC=gcc / CXX=g++.
  # - We DO pass it to the runtimes sub-build, which uses the newly built clang.
  #   Each item must be a full -D CMake arg; items separated with semicolons.
  if [ -n "${RUNTIME_RPATH}" ]; then
    RUNTIMES_ARGS="-DRUNTIMES_CMAKE_ARGS=-DCMAKE_C_FLAGS=${RUNTIME_TOOLCHAIN_FLAGS};-DCMAKE_CXX_FLAGS=${RUNTIME_TOOLCHAIN_FLAGS};-DCMAKE_EXE_LINKER_FLAGS=${EXTRA_LDFLAGS};-DCMAKE_SHARED_LINKER_FLAGS=${EXTRA_LDFLAGS}"
  else
    RUNTIMES_ARGS="-DRUNTIMES_CMAKE_ARGS=-DCMAKE_C_FLAGS=${RUNTIME_TOOLCHAIN_FLAGS};-DCMAKE_CXX_FLAGS=${RUNTIME_TOOLCHAIN_FLAGS}"
  fi
fi

###############################################################################
# Download + extract + configure
###############################################################################

if [ "$DO_REBUILD" = "FALSE" ]; then
   archive=${TMPDIR}/llvm_${LLVM_VERSION}.tar.gz

   # Download/update the source
   if [[ -f $archive ]]; then
     echo "$archive already exists, skipping download"
   else
     echo "Downloading $remote to $archive"
     curl --location --output ${archive} ${remote}
   fi

   # Extract the source
   if [[ -f ${cmake_root}/CMakeLists.txt ]]; then
     echo "$cmake_root/CMakeLists.txt already exists, skipping extract"
   else
     echo "Extracting $archive to $llvm_src"
     tar -C $llvm_src -xzf $archive
   fi

   if [ "$JUST_DOWNLOAD" = "TRUE" ]; then
     echo "Just download requested, exiting"
     exit 0
   fi

   # Configure
   cmake \
   -G"$CMAKE_GENERATOR" \
   -DCMAKE_BUILD_TYPE=Release \
   -DLLVM_TARGETS_TO_BUILD=$llvm_arch \
   -DLLVM_ENABLE_RUNTIMES=${llvm_runtimes} \
   -DLLVM_ENABLE_PROJECTS=${llvm_projects} \
   $quadmath \
   $macos_sysroot \
   $llvm_linker \
   -DCMAKE_C_COMPILER="$CC" \
   -DCMAKE_CXX_COMPILER="$CXX" \
   -DCMAKE_C_FLAGS="${TOOLCHAIN_C_FLAGS}" \
   -DCMAKE_CXX_FLAGS="${TOOLCHAIN_CXX_FLAGS}" \
   ${RUNTIMES_ARGS} \
   ${EXE_LDFLAGS} \
   ${SHARED_LDFLAGS} \
   --install-prefix=$prefix \
   -S${cmake_root} \
   -B${llvm_build}
fi

###############################################################################
# Build + install
###############################################################################

TMPDIR=${TMPDIR} cmake --build ${llvm_build} -j ${PROCS}
TMPDIR=${TMPDIR} cmake --install ${llvm_build} ${STRIP}

# If flang or flang-new exists, call it good
if [[ -x ${prefix}/bin/flang ]] || [[ -x ${prefix}/bin/flang-new ]]; then
  echo "Flang appears to be installed under ${prefix}/bin"
else
  echo "flang/flang-new not found in $prefix/bin"
  exit 1
fi

