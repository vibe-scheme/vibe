#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"

cd "$PROJECT_ROOT"

# Determine which compiler to use
if [ -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
    COMPILER="${BUILD_DIR}/bin/vibe_kernel"
elif [ -f "${BUILD_DIR}/bin/bootstrap_compiler" ]; then
    COMPILER="${BUILD_DIR}/bin/bootstrap_compiler"
else
    echo "FAIL: No compiler found (neither vibe_kernel nor bootstrap_compiler)"
    exit 1
fi

# Compile test program directly to object file
echo "Compiling hello_world.vibe using $COMPILER..."
"${COMPILER}" test/hello_world.vibe -o test/hello_world.o

# Verify object file was generated
if [ ! -f test/hello_world.o ]; then
    echo "FAIL: Object file not generated"
    exit 1
fi

# Link executable (no llc step needed)
echo "Linking executable..."
cc test/hello_world.o -o test/hello_world.exe -lc

# Run and check output
echo "Running program..."
OUTPUT=$(./test/hello_world.exe)
EXPECTED="Hello, World!"

if [ "$OUTPUT" = "$EXPECTED" ]; then
    echo "PASS: Output matches expected '$EXPECTED'"
    exit 0
else
    echo "FAIL: Expected '$EXPECTED', got '$OUTPUT'"
    exit 1
fi
