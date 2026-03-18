#!/bin/bash

# Vibe Compiler Build Script (Self-Hosted)
# The compiler builds itself from .vibe source using an existing vibe_kernel binary.
# If no binary exists, a seed compiler is downloaded from the GitHub release.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
SEED_URL="https://github.com/vibe-scheme/vibe/releases/download/v0.0.1-seed/vibe_kernel_seed"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Download seed compiler from GitHub release if no vibe_kernel binary exists
download_seed() {
    print_info "No vibe_kernel binary found. Downloading seed compiler..."
    mkdir -p "${BUILD_DIR}/bin"
    
    if command -v gh &> /dev/null; then
        gh release download v0.0.1-seed --repo vibe-scheme/vibe \
            -p "vibe_kernel_seed" -D "${BUILD_DIR}/bin" || {
            print_error "Failed to download seed compiler via gh CLI"
            print_error "You can manually download it from:"
            print_error "  ${SEED_URL}"
            print_error "and place it at ${BUILD_DIR}/bin/vibe_kernel"
            exit 1
        }
        mv "${BUILD_DIR}/bin/vibe_kernel_seed" "${BUILD_DIR}/bin/vibe_kernel"
    elif command -v curl &> /dev/null; then
        curl -L --fail -o "${BUILD_DIR}/bin/vibe_kernel" "${SEED_URL}" || {
            print_error "Failed to download seed compiler from ${SEED_URL}"
            print_error "You can manually download it and place it at ${BUILD_DIR}/bin/vibe_kernel"
            exit 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "${BUILD_DIR}/bin/vibe_kernel" "${SEED_URL}" || {
            print_error "Failed to download seed compiler from ${SEED_URL}"
            exit 1
        }
    else
        print_error "Neither gh, curl, nor wget found. Please install one and retry."
        exit 1
    fi
    
    chmod +x "${BUILD_DIR}/bin/vibe_kernel"
    print_info "Seed compiler downloaded to ${BUILD_DIR}/bin/vibe_kernel"
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
        print_info "Building Vibe compiler (self-hosted)..."
        
        # Ensure vibe_kernel binary exists
        if [ ! -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
            download_seed
        fi
        
        # Create build directory
        mkdir -p "${BUILD_DIR}"
        
        # Configure CMake
        print_info "Configuring CMake..."
        cd "${BUILD_DIR}"
        cmake "${SCRIPT_DIR}" || {
            print_error "CMake configuration failed."
            exit 1
        }
        
        # Build kernel using vibe_kernel
        print_info "Building compiler..."
        cmake --build . --target vibe_kernel || {
            print_error "Build failed."
            exit 1
        }
        
        print_info "Build complete!"
        print_info "Executable: ${BUILD_DIR}/bin/vibe_kernel"
        ;;
    
    test)
        print_info "Running tests..."
        
        # Ensure kernel exists
        if [ ! -f "${BUILD_DIR}/bin/vibe_kernel" ]; then
            print_warn "Compiler not found. Running build first..."
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
        echo "Usage: $0 {clean|build|test|install}"
        echo ""
        echo "Commands:"
        echo "  clean   - Remove build directory"
        echo "  build   - Build Vibe compiler (self-hosted, default)"
        echo "  test    - Run tests"
        echo "  install - Install the project"
        exit 1
        ;;
esac
