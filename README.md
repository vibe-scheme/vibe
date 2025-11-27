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
- LLVM (with development headers and tools)
- C++ compiler (for linking LLVM libraries)

### Installing LLVM

**macOS** (using Homebrew):
```bash
brew install llvm
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt-get install llvm-dev clang
```

**Linux** (Fedora):
```bash
sudo dnf install llvm-devel clang
```

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
- 🔄 Phase 2: Lexer (in progress)
- ⏳ Phase 3: Parser
- ⏳ Phase 4: Runtime Foundation
- ⏳ Phase 5: FFI System
- ⏳ Phase 6: Compiler Driver

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
