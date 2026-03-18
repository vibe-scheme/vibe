#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"

cd "$PROJECT_ROOT"

# Force arm64 for linking when on Darwin (vibe produces arm64; cc may run under Rosetta)
ARCH_FLAG=""
if [ "$(uname -s)" = "Darwin" ]; then
    ARCH_FLAG="-arch arm64"
fi

# Determine which compiler to use
if [ -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
    COMPILER="${BUILD_DIR}/bin/vibe_kernel"
elif [ -f "${BUILD_DIR}/bin/bootstrap_compiler" ]; then
    COMPILER="${BUILD_DIR}/bin/bootstrap_compiler"
else
    echo "FAIL: No compiler found (neither vibe_kernel nor bootstrap_compiler)"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: hello_world (must pass)
echo "=== Test: hello_world.vibe ==="
echo "Compiling hello_world.vibe using $COMPILER..."
if "${COMPILER}" test/hello_world.vibe -o test/hello_world.o 2>/dev/null; then
    if [ -f test/hello_world.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/hello_world.o -o test/hello_world.exe -lc 2>/dev/null; then
            OUTPUT=$(./test/hello_world.exe)
            if [ "$OUTPUT" = "Hello, World!" ]; then
                echo "PASS: hello_world"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "FAIL: hello_world - Expected 'Hello, World!', got '$OUTPUT'"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "FAIL: hello_world - Link failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "FAIL: hello_world - Object file not generated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "FAIL: hello_world - Compile failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 2: macro_hello (canary for unhygienic macros - fails until macros implemented)
echo ""
echo "=== Test: macro_hello.vibe (macro canary) ==="
echo "Compiling macro_hello.vibe using $COMPILER..."
if "${COMPILER}" test/macro_hello.vibe -o test/macro_hello.o 2>/dev/null; then
    if [ -f test/macro_hello.o ]; then
        echo "Linking executable..."
        if cc $ARCH_FLAG test/macro_hello.o -o test/macro_hello.exe -lc 2>/dev/null; then
            OUTPUT=$(./test/macro_hello.exe 2>/dev/null; echo $?)
            if [ "$OUTPUT" = "42" ]; then
                echo "PASS: macro_hello (macros working!)"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                echo "PENDING: macro_hello - Macros not yet implemented (exit code: $OUTPUT)"
            fi
        else
            echo "PENDING: macro_hello - Link failed (macros not yet implemented)"
        fi
    else
        echo "PENDING: macro_hello - Object file not generated (macros not yet implemented)"
    fi
else
    echo "PENDING: macro_hello - Compile failed (macros not yet implemented)"
fi

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
exit 0
