#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"

cd "$PROJECT_ROOT"

# Compile test program to bitcode
echo "Compiling hello_world.vibe..."
"${BUILD_DIR}/bin/bootstrap_compiler" test/hello_world.vibe -o test/hello_world.bc

# Verify bitcode was generated
if [ ! -f test/hello_world.bc ]; then
    echo "FAIL: Bitcode file not generated"
    exit 1
fi

# Compile bitcode to object
echo "Compiling to object..."
llc -filetype=obj test/hello_world.bc -o test/hello_world.o

# Link executable
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
