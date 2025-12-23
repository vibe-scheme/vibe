# Vibe Language

Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode. The language is designed to be self-hosting, meaning the compiler will eventually be written in Vibe itself.

## Overview

Vibe aims to provide:
- **Self-hosting**: The compiler is written in Vibe itself (after bootstrap)
- **LLVM Backend**: Compiles to LLVM bitcode for efficient native code generation
- **R7RS Compatibility**: Based on R7RS Small Scheme standard
- **Extensibility**: Core language features can be extended using `define-bitcode` primitive

## Project Structure

```
vibe/
├── bootstrap/          # Bootstrap compiler (pure LLVM bitcode)
│   ├── lexer/         # Lexer implementation
│   ├── parser/        # Parser implementation
│   ├── runtime/       # Runtime support (FFI, primitives)
│   └── compiler/      # Compiler driver and main entry point
├── src/               # Future self-hosted Vibe code
├── doc/               # Documentation repository
│   ├── design/        # Design documents and formal plans
│   ├── chats/         # Recorded development conversations
│   └── examples/      # Example programs and tutorials
├── test/              # Test files
└── build/             # Build output (gitignored)
```

## Prerequisites

- CMake 3.20 or higher
- **LLVM 21** (specifically version 21.x) - with tools (`llvm-as`, `llvm-link`, `llc`)
- C++ compiler (for linking the final executable)
- Standard C library (libc) and POSIX dynamic library loading (libdl on Linux)

**Note**: The bootstrap compiler uses LLVM tools during build time but does NOT link against LLVM libraries at runtime. Only the LLVM tools are required.

### Installing LLVM 21

**macOS** (using Homebrew):
```bash
brew install llvm
# Verify version:
llvm-config --version  # Should show 21.x
```

**Linux** (Ubuntu/Debian):
```bash
# For Ubuntu 22.04+, LLVM 21 may be available in default repos
sudo apt-get update
sudo apt-get install llvm-21 llvm-21-dev clang-21

# Or install from LLVM official repository:
# See https://apt.llvm.org/ for setup instructions
```

**Linux** (Fedora):
```bash
sudo dnf install llvm21 llvm21-devel clang
```

### Verifying LLVM Installation

After installing LLVM, verify that the required tools are available:
```bash
llvm-as --version   # Should show LLVM 21.x
llvm-link --version # Should show LLVM 21.x
llc --version       # Should show LLVM 21.x
```

If these commands are not found, you may need to add LLVM's bin directory to your PATH:
```bash
# macOS (Homebrew):
export PATH="/usr/local/opt/llvm/bin:$PATH"

# Linux (adjust path based on installation):
export PATH="/usr/lib/llvm-21/bin:$PATH"
```

### Platform-Specific Notes

**macOS (Apple Silicon)**: The bootstrap compiler is currently configured for Apple Silicon (arm64). The target triple in all `.ll` files is set to `arm64-apple-darwin` with data layout `"e-m:o-i64:64-i128:128-n32:64-S128"`.

**macOS (Intel)**: For Intel-based Macs, you'll need to update the target triple in all `.ll` files to `x86_64-apple-macosx10.15.0` (or your specific macOS version) and update the data layout accordingly.

**Linux**: For Linux builds, you'll need to update the target triple in all `.ll` files to match your Linux distribution:
- x86_64: `x86_64-unknown-linux-gnu`
- ARM64: `aarch64-unknown-linux-gnu`

**Target Initialization**: The bootstrap compiler automatically detects the target architecture at runtime and initializes the appropriate LLVM target components. This means the same code works on both arm64 and x86_64 platforms without requiring separate code paths.

**Cross-Compilation**: Cross-compilation is not currently supported. The bootstrap compiler will only work on the same architecture/OS it was built on. This is a known limitation and a future goal.

## Build Instructions

### Using the Build Script

The easiest way to build is using the provided build script:

```bash
# Build the project
./build.sh build

# Clean build directory
./build.sh clean

# Run tests (when implemented)
./build.sh test

# Install (when implemented)
./build.sh install
```

### Using CMake Directly

```bash
# Create build directory
mkdir -p build
cd build

# Configure
cmake ..

# Build
cmake --build .

# The executable will be at: build/bin/bootstrap_compiler
```

## Quick Start

Once built, the bootstrap compiler can be used to compile Vibe source files:

```bash
# Compile a Vibe source file
./build/bin/bootstrap_compiler input.vibe -o output.bc
```

(Note: The bootstrap compiler is currently under development)

## Documentation

- **[AGENTS.md](AGENTS.md)** - Guide for AI agents working on this project
- **[doc/design/bootstrap-plan.md](doc/design/bootstrap-plan.md)** - Bootstrap compiler implementation plan
- **[doc/README.md](doc/README.md)** - Documentation index

## Development Status

The bootstrap compiler is currently under active development. Current status:

- ✅ Phase 1: Project Structure
- ✅ Phase 2: Lexer
- ✅ Phase 3: Parser
- ✅ Phase 4: Runtime Foundation (including `define-bitcode` primitive)
- ✅ Phase 5: FFI System
- ✅ Phase 6: Compiler Driver

**Note**: The bootstrap compiler structure is complete, but the implementation may need refinement and testing. The build system is configured for LLVM 21.

## Known Limitations

1. **Target Triple**: All LLVM IR files hardcode the target triple to the build system's architecture. Currently configured for Apple Silicon (arm64-apple-darwin). Cross-compilation is not currently supported.

2. **Platform Support**: Currently configured for macOS. Linux support requires updating target triples in all `.ll` files.

3. **LLVM Version**: Requires LLVM 21 specifically. Other versions may not work correctly.

## Contributing

See [AGENTS.md](AGENTS.md) for guidelines on contributing to the project, including:
- Coding standards and practices
- Directory structure conventions
- Documentation requirements
- Testing strategies

## License

(To be determined)

## Acknowledgments

Vibe is inspired by R7RS Small Scheme and aims to provide a modern, self-hosting implementation that compiles to efficient native code via LLVM.
