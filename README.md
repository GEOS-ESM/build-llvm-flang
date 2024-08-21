# LLVM Build Scripts

This repo contains a build script for LLVM Flang. It is based on a gist by
@scivision:

https://gist.github.com/scivision/33bd9e17c9520d07be0448fe61541605

with updates for use on Bucy (namely prefix, etc.)

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
