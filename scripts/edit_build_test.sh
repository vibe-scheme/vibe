#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

VERBOSE=false
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
    VERBOSE=true
fi

if [ "$VERBOSE" = true ]; then
    set -x
fi

echo "=========================================="
echo "Building bootstrap compiler..."
echo "=========================================="
./build.sh build || {
    echo "Build failed!"
    exit 1
}

echo ""
echo "=========================================="
echo "Running tests..."
echo "=========================================="
./build.sh test || {
    echo "Tests failed!"
    exit 1
}

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="
