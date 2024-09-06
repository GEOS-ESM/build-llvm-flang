#!/bin/bash -e

# -e: exit on error

# Command line arguments
#  --prefix=PREFIX         install files in PREFIX/llvm-flang (default: /usr/local)
#  --llvm-version=VERSION  LLVM version to build (default: latest main tar.gz)
#  --llvm-projects=LIST    list of LLVM projects to build (default: lld;mlir;clang;flang;openmp;pstl)
#  --no-gold               do not use the gold linker (useful on Docker)
#  --add-date              add the date to the install prefix
#  --rebuild               just rebuild the source but do not download again
#  --strip                 strip the binaries
#  --verbose               print commands before execution
#  -n | --dry-run          print commands without execution
#  -h | --help             print help

usage() {
  printf "Usage: %s [options]\n" "$0"
  printf "Options:\n"
  printf "  --prefix=PREFIX         install files in PREFIX [/usr/local]\n"
  printf "  --llvm-version=VERSION  LLVM version to build [latest main tar.gz]\n"
  printf "  --llvm-projects=LIST    list of LLVM projects to build [lld;mlir;clang;flang;openmp;pstl]\n"
  printf "  --no-gold               do not use the gold linker\n"
  printf "  --add-date              add the date to the install prefix\n"
  printf "  --rebuild               just rebuild the source but do not download again\n"
  printf "  --strip                 strip the binaries\n"
  printf "  --verbose               print commands before execution\n"
  printf "  -n | --dry-run          print commands without execution\n"
  printf "  -h | --help             print help\n"
  printf "\n"
  printf  "NOTE: Set \$TMPDIR to change the temporary directory where the source is downloaded and built\n"
}

# Default values
LLVM_PREFIX=/usr/local
LLVM_PROJECTS="lld;mlir;clang;flang;openmp;pstl"
LLVM_VERSION=main
ADD_DATE=FALSE
DRY_RUN=FALSE
USE_GOLD=TRUE
STRIP=""
DO_REBUILD=FALSE

while [ $# -gt 0 ]; do
   case "$1" in
   --prefix=*)
      LLVM_PREFIX="${1#*=}"
      ;;
   --llvm-projects=*)
      LLVM_PROJECTS="${1#*=}"
      ;;
   --llvm-version=*)
      LLVM_VERSION="${1#*=}"
      ;;
   --no-gold)
      USE_GOLD=FALSE
      ;;
   --add-date)
      ADD_DATE=TRUE
      ;;
   --rebuild)
      DO_REBUILD=TRUE
      ;;
   --strip)
      STRIP="--strip"
      ;;
   --verbose)
      set -x
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
      printf "Error: Invalid argument\n"
      printf "***************************\n"
      usage
      exit 1
      ;;
  esac
  shift
done

# Set the number of open files to a large number
ulimit -n 65536

# Ninja is recommended for best build efficiency and speed
# always use the ".tar.gz" source file

# adapted from https://github.com/jeffhammond/HPCInfo/blob/master/buildscripts/llvm-git.sh

# if LLVM_VERSION is set to main, then use the latest main.tar.gz
# if it is, base it off of https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${LLVM_VERSION}.tar.gz
if [ "$LLVM_VERSION" = "main" ]; then
   remote="https://github.com/llvm/llvm-project/archive/refs/heads/main.tar.gz"
else
   remote="https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${LLVM_VERSION}.tar.gz"
fi

# use TMPDIR if not empty, else /tmp
TMPDIR=${TMPDIR:-/tmp}

llvm_src=${TMPDIR}/llvm-src
llvm_build=${TMPDIR}/llvm-build

# Let's go off of LLVM_PREFIX
prefix=${LLVM_PREFIX}/llvm-flang

# Now add the date to the prefix if requested
if [ "$ADD_DATE" = "TRUE" ]; then
  prefix=${prefix}/$(date +%F)
fi

stem=$(basename ${remote} .tar.gz)
cmake_root=${llvm_src}/llvm-project-${stem}/llvm

# The LLVM projects to build
llvm_projects=$LLVM_PROJECTS

echo "LLVM projects: $llvm_projects"
echo "LLVM source: $llvm_src"
echo "LLVM build: $llvm_build"
echo "LLVM install: $prefix"
echo "LLVM version: $LLVM_VERSION"
echo "LLVM remote: $remote"

# Require that CC and CXX are set
[[ -z $CC ]] && { echo "CC not set" && exit 1; }
[[ -z $CXX ]] && { echo "CXX not set" && exit 1; }

echo "CC: $CC"
echo "CXX: $CXX"

if [ "$DRY_RUN" = "TRUE" ]; then
  exit 0
fi

mkdir -p $prefix
mkdir -p $llvm_src
mkdir -p $llvm_build

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
   # Quadmath not available on MacOS
   quadmath=
   ;;
*)
   if [ "$USE_GOLD" = "TRUE" ]; then
      llvm_linker=-DLLVM_USE_LINKER=gold
   else
      llvm_linker=
   fi
   quadmath=-DFLANG_RUNTIME_F128_MATH_LIB=libquadmath
   ;;
esac\

if [ "$DO_REBUILD" = "FALSE" ]; then
   # Git not used as it's so slow for a huge project history like LLVM.
   # git clone --recursive https://github.com/llvm/llvm-project.git $llvm_src

   # ~300 MB
   archive=${TMPDIR}/llvm_main.tar.gz

   # Download/update the source
   [[ -f $archive ]] || curl --location --output ${archive} ${remote}

   [[ -f ${cmake_root}/CMakeLists.txt ]] || tar -C $llvm_src -xzf $archive

   # lldb busted on MacOS
   # libcxx requires libcxxabi
   cmake \
   -G"$CMAKE_GENERATOR" \
   -DCMAKE_BUILD_TYPE=Release \
   -DLLVM_TARGETS_TO_BUILD=$llvm_arch \
   -DLLVM_ENABLE_RUNTIMES="libcxxabi;libcxx;libunwind" \
   -DLLVM_ENABLE_PROJECTS=${llvm_projects} \
   $quadmath \
   $macos_sysroot \
   $llvm_linker \
   --install-prefix=$prefix \
   -S${cmake_root} \
   -B${llvm_build}
fi

cmake --build ${llvm_build} -j 6

cmake --install ${llvm_build} ${STRIP}

# If flang-new runs, then the build is successful
# and we can remove the build and source directories

if [[ -x ${prefix}/bin/flang-new ]]; then
  rm -rf $llvm_build $llvm_src $archive
else
  echo "flang-new not found in $prefix/bin"
  exit 1
fi
