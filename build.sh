#!/bin/bash

# Vibe Bootstrap Compiler Build Script
# Convenience script for building the project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
COMMAND="${1:-build}"

case "$COMMAND" in
    clean)
        print_info "Cleaning build directory..."
        rm -rf "${BUILD_DIR}"
        print_info "Clean complete."
        ;;
    
    build)
        print_info "Building Vibe bootstrap compiler..."
        
        # Create build directory
        mkdir -p "${BUILD_DIR}"
        
        # Configure CMake
        print_info "Configuring CMake..."
        cd "${BUILD_DIR}"
        cmake "${SCRIPT_DIR}" || {
            print_error "CMake configuration failed."
            exit 1
        }
        
        # Build
        print_info "Building..."
        cmake --build . || {
            print_error "Build failed."
            exit 1
        }
        
        print_info "Build complete!"
        print_info "Executable: ${BUILD_DIR}/bin/bootstrap_compiler"
        ;;
    
    test)
        print_info "Running tests..."
        # TODO: Implement test runner
        print_warn "Test runner not yet implemented."
        ;;
    
    install)
        print_info "Installing..."
        cd "${BUILD_DIR}"
        cmake --install . || {
            print_error "Installation failed."
            exit 1
        }
        print_info "Installation complete."
        ;;
    
    *)
        echo "Usage: $0 {clean|build|test|install}"
        echo ""
        echo "Commands:"
        echo "  clean   - Remove build directory"
        echo "  build   - Build the project (default)"
        echo "  test    - Run tests"
        echo "  install - Install the project"
        exit 1
        ;;
esac
