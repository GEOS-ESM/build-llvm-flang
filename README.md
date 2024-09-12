# LLVM Build Scripts

This repo contains a build script for LLVM Flang. It is based on a gist by
@scivision:

https://gist.github.com/scivision/33bd9e17c9520d07be0448fe61541605

with updates for use on Bucy (namely prefix, etc.).

## Current Usage

```
Usage: ./build-flang-f18.sh [options]
Options:
  --prefix=PREFIX         install files in PREFIX [/usr/local]
  --llvm-version=VERSION  LLVM version to build [latest main tar.gz]
  --llvm-projects=LIST    list of LLVM projects to build [lld;mlir;clang;flang;openmp;pstl]
  --no-gold               do not use the gold linker
  --add-date              add the date to the install prefix
  --rebuild               just rebuild the source but do not download again
  --strip                 strip the binaries
  --verbose               print commands before execution
  -n | --dry-run          print commands without execution
  -h | --help             print help

NOTE: Set $TMPDIR to change the temporary directory where the source is downloaded and built
```

## 128 bit support

We also update the script to add:

```cmake
-DFLANG_RUNTIME_F128_MATH_LIB=libquadmath
```

## Docker Images

This repo has Dockerfiles that are used to build the a couple of images hosted on Docker Hub:

- [`gmao/llvm-flang`](https://hub.docker.com/r/gmao/llvm-flang/tags): This has a minimal Ubuntu 24.04 base with an install of
  llvm-flang.
- [`gmao/llvm-flang-openmpi`](https://hub.docker.com/r/gmao/llvm-flang-openmpi/tags): This is based on the above image and adds
  OpenMPI.

---

## Original Instructions

This is a Bash script (macOS, Linux, ...) for building Flang-f18 and LLVM from source.
It is adapted from [Jeff Hammond](https://github.com/jeffhammond/HPCInfo/blob/master/buildscripts/llvm-git.sh)

Ninja: recommended for best build efficiency and speed.

In general, a recent GCC would work.
On macOS, system AppleClang compiler can be used as well.

```sh
bash build-flang-f18.sh
```

To specify the source URL, for example to build the latest LLVM 19.x release:

```sh
bash build-flang-f18.sh https://github.com/llvm/llvm-project/archive/refs/heads/release/19.x.zip
```

For a specific version of LLVM:

```sh
bash build-flang-f18.sh https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-19.1.0-rc1.zip
```

The source download is about 300 MB.
LLVM takes about a half-hour to build on a powerful laptop or workstation.

To use the compiler after install:

### Troubleshooting

See [ulimit settings](https://gist.github.com/scivision/33bd9e17c9520d07be0448fe61541605?permalink_comment_id=5048103#gistcomment-5048103) if link failures occur.

### Disk usage

The installed binaries take a few gigabytes of disk space.

```sh
du -sh ~/llvm-latest  # the install prefix
```

> 3.3G

The source directory can be deleted after the build / install is complete.

```sh
du -sh $TMPDIR/llvm-src
```

> 1.8G

The build directory can be deleted after the build / install is complete.

```sh
du -sh $TMPDIR/llvm-build
```

> 5.0G
