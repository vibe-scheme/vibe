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
    
    bootstrap)
        print_info "Building bootstrap compiler (using .ll files only)..."
        
        # Create build directory
        mkdir -p "${BUILD_DIR}"
        
        # Configure CMake for bootstrap
        print_info "Configuring CMake for bootstrap..."
        cd "${BUILD_DIR}"
        cmake "${SCRIPT_DIR}" -DBUILD_MODE=BOOTSTRAP || {
            print_error "CMake configuration failed."
            exit 1
        }
        
        # Build bootstrap compiler
        print_info "Building bootstrap compiler..."
        cmake --build . --target bootstrap_compiler || {
            print_error "Bootstrap build failed."
            exit 1
        }
        
        print_info "Bootstrap build complete!"
        print_info "Executable: ${BUILD_DIR}/bin/bootstrap_compiler"
        ;;
    
    build_kernel)
        print_info "Building Vibe kernel (using .vibe files + _no_vibe.ll files, compiled with bootstrap_compiler)..."
        
        # Ensure bootstrap compiler exists
        if [ ! -f "${BUILD_DIR}/bin/bootstrap_compiler" ]; then
            print_warn "Bootstrap compiler not found. Running bootstrap first..."
            "$0" bootstrap
        fi
        
        # Create build directory
        mkdir -p "${BUILD_DIR}"
        
        # Configure CMake for kernel build
        print_info "Configuring CMake for kernel build..."
        cd "${BUILD_DIR}"
        cmake "${SCRIPT_DIR}" -DBUILD_MODE=KERNEL || {
            print_error "CMake configuration failed."
            exit 1
        }
        
        # Build kernel
        print_info "Building kernel..."
        cmake --build . --target vibe_kernel || {
            print_error "Kernel build failed."
            exit 1
        }
        
        print_info "Kernel build complete!"
        print_info "Executable: ${BUILD_DIR}/bin/vibe_kernel"
        ;;
    
    build)
        print_info "Building Vibe kernel using vibe_kernel itself (self-hosting build)..."
        
        # Ensure vibe_kernel exists (build_kernel uses bootstrap_compiler)
        if [ ! -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
            print_warn "vibe_kernel not found. Running build_kernel first..."
            "$0" build_kernel
        fi
        
        # Create build directory
        mkdir -p "${BUILD_DIR}"
        
        # Configure CMake for self-hosting build
        print_info "Configuring CMake for self-hosting build..."
        cd "${BUILD_DIR}"
        cmake "${SCRIPT_DIR}" -DBUILD_MODE=SELF_HOST || {
            print_error "CMake configuration failed."
            exit 1
        }
        
        # Build kernel using vibe_kernel
        print_info "Building kernel using vibe_kernel..."
        cmake --build . --target vibe_kernel || {
            print_error "Self-hosting build failed."
            exit 1
        }
        
        print_info "Self-hosting build complete!"
        print_info "Executable: ${BUILD_DIR}/bin/vibe_kernel"
        ;;
    
    test)
        print_info "Running tests..."
        
        # Ensure kernel exists
        if [ ! -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
            print_warn "Kernel not found. Running build first..."
            "$0" build
        fi
        
        cd "${BUILD_DIR}"
        cmake --build . --target run_tests || {
            print_error "Tests failed."
            exit 1
        }
        print_info "All tests passed!"
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
        echo "Usage: $0 {clean|bootstrap|build_kernel|build|test|install}"
        echo ""
        echo "Commands:"
        echo "  clean       - Remove build directory"
        echo "  bootstrap   - Build bootstrap compiler using .ll files only"
        echo "  build_kernel - Build Vibe kernel using .vibe files + _no_vibe.ll files (compiled with bootstrap_compiler)"
        echo "  build       - Build Vibe kernel using vibe_kernel itself (self-hosting, default)"
        echo "  test        - Run tests using vibe_kernel"
        echo "  install     - Install the project"
        exit 1
        ;;
esac
