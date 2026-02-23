#!/bin/bash

set -e  # Exit on error

# Default to date-based versioning
VERSION=$(date '+%F')
DRY_RUN=false

# Function to display help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build and push Docker images for LLVM Flang and OpenMPI.

Options:
    -v, --version VERSION   Use specified version tag (e.g., 22.1.0-rc3)
                           Default: current date (YYYY-MM-DD)
    -n, --dry-run          Show what would be done without executing
    -h, --help             Show this help message

Examples:
    $(basename "$0")                    # Build with date tag (e.g., 2026-02-23)
    $(basename "$0") -v 22.1.0-rc3     # Build with version tag 22.1.0-rc3
    $(basename "$0") --version 1.0.0   # Build with version tag 1.0.0
    $(basename "$0") -n -v 22.1.0-rc3  # Dry-run with version tag

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: -v/--version requires a version argument"
                exit 1
            fi
            VERSION="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check for required Dockerfiles
if [ ! -f "Dockerfile.flang" ]; then
    echo "Error: Dockerfile.flang not found in current directory"
    exit 1
fi

if [ ! -f "Dockerfile.openmpi" ]; then
    echo "Error: Dockerfile.openmpi not found in current directory"
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    echo "=== DRY RUN MODE ==="
fi

echo "Building with version tag: $VERSION"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "Would build Flang with LLVM version: $VERSION"
    echo ""
    echo "Would create the following images:"
    echo "  - gmao/llvm-flang:$VERSION"
    echo "  - gmao/llvm-flang:latest"
    echo "  - gmao/llvm-flang-openmpi:$VERSION"
    echo "  - gmao/llvm-flang-openmpi:latest"
    echo ""
    echo "Would create log files:"
    echo "  - build.flang.$VERSION.log"
    echo "  - build.openmpi.$VERSION.log"
    echo ""
    echo "Would push all images to registry"
    echo ""
    echo "=== DRY RUN COMPLETE ==="
    exit 0
fi

## Flang ##

echo "Building Flang image..."
docker build --no-cache --progress=plain --build-arg llvmversion=$VERSION -f Dockerfile.flang -t gmao/llvm-flang:$VERSION -t gmao/llvm-flang:latest . 2>&1 | tee build.flang.$VERSION.log

echo "Pushing Flang images..."
docker push gmao/llvm-flang:$VERSION
docker push gmao/llvm-flang:latest

## Open MPI ##

echo "Building OpenMPI image..."
docker build --no-cache --progress=plain -f Dockerfile.openmpi -t gmao/llvm-flang-openmpi:$VERSION -t gmao/llvm-flang-openmpi:latest . 2>&1 | tee build.openmpi.$VERSION.log

echo "Pushing OpenMPI images..."
docker push gmao/llvm-flang-openmpi:$VERSION
docker push gmao/llvm-flang-openmpi:latest

echo "Successfully built and pushed all images with version: $VERSION"
