#!/bin/bash

# Exit on error
set -e

# Default configuration
BUILD_TYPE="Release"
BUILD_DIR="build"
CLEAN=0
PARALLEL="-j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
CMAKE_OPTIONS=""
BOOTSTRAP=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --build-dir=*)
            BUILD_DIR="${1#*=}"
            shift
            ;;
        --sanitize)
            CMAKE_OPTIONS="$CMAKE_OPTIONS -DVIBE_ENABLE_ASAN=ON -DVIBE_ENABLE_UBSAN=ON"
            shift
            ;;
        --no-tests)
            CMAKE_OPTIONS="$CMAKE_OPTIONS -DVIBE_BUILD_TESTS=OFF"
            shift
            ;;
        --docs)
            CMAKE_OPTIONS="$CMAKE_OPTIONS -DVIBE_BUILD_DOCS=ON"
            shift
            ;;
        --bootstrap)
            BOOTSTRAP=1
            CMAKE_OPTIONS="$CMAKE_OPTIONS -DVIBE_BOOTSTRAP=ON"
            shift
            ;;
        -j*)
            PARALLEL="$1"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo
            echo "Options:"
            echo "  --debug        Build in debug mode"
            echo "  --clean        Clean build directory before building"
            echo "  --build-dir=*  Specify build directory (default: build)"
            echo "  --sanitize     Enable address and undefined behavior sanitizers"
            echo "  --no-tests     Disable building tests"
            echo "  --docs         Enable building documentation"
            echo "  --bootstrap    Build self-hosted compiler using bootstrap compiler"
            echo "  -j*           Number of parallel jobs (default: number of CPU cores)"
            echo "  --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Print build configuration
echo "=== Build Configuration ==="
echo "Build type: $BUILD_TYPE"
echo "Build directory: $BUILD_DIR"
echo "Parallel jobs: $PARALLEL"
echo "Bootstrap mode: $([[ $BOOTSTRAP -eq 1 ]] && echo "yes" || echo "no")"
echo "CMake options: $CMAKE_OPTIONS"
echo "=========================="

# Clean build directory if requested
if [ $CLEAN -eq 1 ]; then
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo "Configuring build..."
cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" $CMAKE_OPTIONS ..

# Build
echo "Building..."
if [ $BOOTSTRAP -eq 1 ]; then
    echo "Building bootstrap compiler..."
    cmake --build . --target bootstrap-vibe $PARALLEL
    echo "Building self-hosted compiler..."
    cmake --build . --target vibe $PARALLEL
else
    cmake --build . $PARALLEL
fi

# Run tests if enabled
if ! echo "$CMAKE_OPTIONS" | grep -q "VIBE_BUILD_TESTS=OFF"; then
    echo "Running tests..."
    ctest --output-on-failure
fi

# Return to root directory
cd ..

# Check if build was successful
if [ -x "$BUILD_DIR/vibe" ]; then
    echo "Build successful! The 'vibe' executable is in the $BUILD_DIR directory."
    if [ $BOOTSTRAP -eq 1 ] && [ -x "$BUILD_DIR/bootstrap-vibe" ]; then
        echo "Bootstrap compiler is also available as '$BUILD_DIR/bootstrap-vibe'."
    fi
else
    echo "Build failed: 'vibe' executable not found in $BUILD_DIR directory."
    exit 1
fi 