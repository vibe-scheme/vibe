#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"

cd "$PROJECT_ROOT"

# Compile test program directly to object file
echo "Compiling hello_world.vibe..."
"${BUILD_DIR}/bin/bootstrap_compiler" test/hello_world.vibe -o test/hello_world.o

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
