# MUSL Build Release Process

This guide documents how to build MUSL-based Flang binaries and push them to GitHub Releases.

Once GitHub Actions is set up, this can be automated. For now, follow these manual steps.

## Step 1: Build the MUSL Docker Image

On an Ubuntu 24 instance (or system with Docker):

```bash
cd /path/to/build-llvm-flang
git checkout add-musl-dockerfile
git pull origin add-musl-dockerfile

# Build for a specific LLVM version (example: 22.1.0-rc3)
docker build --no-cache -f Dockerfile.flang-musl \
  --build-arg llvmversion=22.1.0-rc3 \
  --build-arg procs=12 \
  --build-arg maxretries=2 \
  -t gmao/llvm-flang-musl:22.1.0-rc3 . \
  2>&1 | tee build.flang-musl-22.1.0-rc3.log

# Or for the latest main branch
docker build --no-cache -f Dockerfile.flang-musl \
  -t gmao/llvm-flang-musl:latest . \
  2>&1 | tee build.flang-musl-latest.log
```

**Expected time:** 30-60 minutes depending on your instance

**If the build fails:** Check the log for errors. Common issues:
- Parallel build race conditions: Lower the `--build-arg procs` value (try 4)
- Missing file: This is normal for some LLVM versions—the `--max-retries` should handle it automatically
- Out of disk space: Increase available disk on your instance

## Step 2: Extract the Tarball

Once the build succeeds:

```bash
# Create a temporary container and copy the tarball
docker create --name flang-musl gmao/llvm-flang-musl:22.1.0-rc3
docker cp flang-musl:/opt/llvm-flang.tar.gz ./llvm-flang-22.1.0-rc3-musl.tar.gz
docker rm flang-musl

# Verify the tarball
ls -lh llvm-flang-22.1.0-rc3-musl.tar.gz
tar tzf llvm-flang-22.1.0-rc3-musl.tar.gz | head -20
```

## Step 3: Create a GitHub Release

Go to your repository: https://github.com/GEOS-ESM/build-llvm-flang

1. Click the **Releases** tab (on the right side)
2. Click **Create a new release**

### Fill in the Release Details:

**Tag name:** `v22.1.0-rc3-musl`

Use this naming convention:
- `v<LLVM-VERSION>-musl` for versioned releases
- `musl-latest` for the bleeding-edge main branch build

**Release title:** `LLVM Flang 22.1.0-rc3 (MUSL Build)`

**Description:**

```markdown
MUSL-based build of LLVM Flang for maximum portability.

This build uses Alpine Linux with MUSL libc instead of glibc, 
allowing it to run on systems with older glibc versions.

**Included:**
- LLVM Flang 22.1.0-rc3
- Clang
- LLVM tools (lld, lldb, etc.)
- OpenMP support

**Usage:**
```bash
wget https://github.com/GEOS-ESM/build-llvm-flang/releases/download/v22.1.0-rc3-musl/llvm-flang-22.1.0-rc3-musl.tar.gz
tar xzf llvm-flang-22.1.0-rc3-musl.tar.gz
export PATH=$(pwd)/llvm-flang/bin:$PATH
flang --version
```

**Build Details:**
- Architecture: x86_64
- Base Image: Alpine Linux (MUSL libc)
- Link Compatibility: Works on systems with glibc 2.14+
```

### Upload the Tarball:

3. Scroll down to **Attach binaries by dropping them here or selecting them.**
4. Drag and drop the `llvm-flang-22.1.0-rc3-musl.tar.gz` file (or click to select)
5. Wait for the upload to complete

### Publish:

6. Click **Publish release**

## Step 4: Verify the Release

Once published, verify it's at:
https://github.com/GEOS-ESM/build-llvm-flang/releases/tag/v22.1.0-rc3-musl

And can be downloaded:
```bash
wget https://github.com/GEOS-ESM/build-llvm-flang/releases/download/v22.1.0-rc3-musl/llvm-flang-22.1.0-rc3-musl.tar.gz
```

## Step 5: (Optional) Push Docker Image to Docker Hub

If you want to make the Docker image available for direct use (without extracting tarballs):

```bash
# Tag the image for Docker Hub
docker tag gmao/llvm-flang-musl:22.1.0-rc3 gmao/llvm-flang-musl:22.1.0-rc3
docker tag gmao/llvm-flang-musl:22.1.0-rc3 gmao/llvm-flang-musl:latest

# Push to Docker Hub (requires authentication: docker login)
docker push gmao/llvm-flang-musl:22.1.0-rc3
docker push gmao/llvm-flang-musl:latest
```

This allows users to pull the image directly:
```bash
docker pull gmao/llvm-flang-musl:22.1.0-rc3
```

If you also built OpenMPI:
```bash
docker push gmao/llvm-flang-openmpi-musl:22.1.0-rc3
docker push gmao/llvm-flang-openmpi-musl:latest
```

## Step 6: (Optional) Also Build OpenMPI + Flang

If you want to include OpenMPI with the Flang build:

```bash
# Make sure the flang-musl image exists first
docker build --no-cache -f Dockerfile.openmpi-musl \
  --build-arg mpiversion=5.0.7 \
  --build-arg mpiprocs=12 \
  -t gmao/llvm-flang-openmpi-musl:22.1.0-rc3 . \
  2>&1 | tee build.openmpi-musl.log

# Extract the combined tarball
docker create --name flang-openmpi-musl gmao/llvm-flang-openmpi-musl:22.1.0-rc3
docker cp flang-openmpi-musl:/opt/llvm-flang-openmpi.tar.gz ./llvm-flang-openmpi-22.1.0-rc3-musl.tar.gz
docker rm flang-openmpi-musl
```

Then upload this tarball to a separate release: `v22.1.0-rc3-openmpi-musl`

## Tag Naming Convention

- **Flang only:** `v<LLVM-VERSION>-musl`
  - Example: `v22.1.0-rc3-musl`
  
- **Flang + OpenMPI:** `v<LLVM-VERSION>-openmpi-<MPI-VERSION>-musl`
  - Example: `v22.1.0-rc3-openmpi-5.0.7-musl`

- **Latest main branch:** `musl-latest` or `musl-latest-openmpi`

## Cleanup (Optional)

After uploading to GitHub, you can clean up the Docker images:

```bash
docker image rm gmao/llvm-flang-musl:22.1.0-rc3
docker image rm gmao/llvm-flang-openmpi-musl:22.1.0-rc3
rm llvm-flang-22.1.0-rc3-musl.tar.gz
```

## Future: GitHub Actions Automation

Once you set up a GitHub Actions workflow, these steps will happen automatically:
1. Build Docker image on push to `add-musl-dockerfile` branch
2. Extract tarball
3. Create GitHub Release
4. Upload tarball to release
5. Push Docker image to Docker Hub registry

For now, follow these manual steps!
