# Vibe Language

Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode. The language is **fully self-hosted**: the compiler (`vibe_kernel`) compiles itself from `.vibe` source files in the `kernel/` directory.

## Overview

Vibe aims to provide:
- **Self-hosting**: The compiler is written in Vibe itself. A seed binary (from a GitHub release) is used only for initial bootstrapping on a clean checkout.
- **LLVM Backend**: Compiles to LLVM bitcode for efficient native code generation
- **R7RS Compatibility**: Based on R7RS Small Scheme standard
- **Extensibility**: Kernel DSL primitives (`llvm:define-function`, `llvm:define-type`, `llvm:declare-function`, etc.) enable the compiler to be written in Vibe

Vibe's mission is to build a language where humans and AI reason *together* about programs — through macro transparency (any expression expandable to primitives) and a future binding registry with human-language descriptions.

## Project Structure

```
vibe/
├── kernel/           # Compiler source (.vibe files)
│   ├── lexer.vibe
│   ├── parser.vibe
│   ├── codegen.vibe
│   ├── main.vibe
│   ├── ffi.vibe
│   ├── dsl.vibe
│   ├── util.vibe
│   └── expander.vibe
├── src/              # Future standard library
├── docs/
│   ├── design/       # Design documents
│   ├── chats/        # Development conversations
│   ├── pages/        # GitHub Pages site
│   └── examples/
├── test/
└── build/            # Build output (gitignored)
```

## Prerequisites

- CMake 3.20 or higher
- **LLVM 21+** — with tools (`llvm-as`, `llvm-link`, `llc`) and libraries for linking
- C compiler (for linking the final executable)
- Standard C library (libc) and POSIX dynamic library loading (libdl on Linux)

The compiler links against LLVM C API libraries (Core, BitWriter, Support, Target, MC, Linker) for bitcode generation. LLVM tools are used during the build pipeline.

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

**macOS (Apple Silicon)**: The compiler is currently configured for Apple Silicon (arm64). The target triple in `kernel/codegen.vibe` is set to `arm64-apple-darwin` with data layout `"e-m:o-i64:64-i128:128-n32:64-S128"`.

**macOS (Intel)**: For Intel-based Macs, you'll need to update the target triple in `kernel/codegen.vibe` to `x86_64-apple-macosx10.15.0` (or your specific macOS version) and update the data layout accordingly.

**Linux**: For Linux builds, update the target triple in `kernel/codegen.vibe` to match your Linux distribution:
- x86_64: `x86_64-unknown-linux-gnu`
- ARM64: `aarch64-unknown-linux-gnu`

**Target Initialization**: The compiler detects the target architecture at runtime and initializes the appropriate LLVM target components. See `docs/design/cross-compilation-plan.md` for multi-architecture support plans.

**Cross-Compilation**: Cross-compilation is not currently supported. The compiler will only work on the same architecture/OS it was built on.

## Build Instructions

### Using the Build Script

The easiest way to build is using the provided build script:

```bash
# Build the project
./build.sh build

# Clean build directory
./build.sh clean

# Run tests
./build.sh test

# Install
./build.sh install
```

On a clean checkout with no existing `vibe_kernel` binary, `build.sh` downloads a seed compiler from the [GitHub release](https://github.com/vibe-scheme/vibe/releases/tag/v0.0.4-seed) (asset `vibe_kernel_seed`) and uses it to compile the `.vibe` source. Subsequent builds use the just-built `vibe_kernel`. Older seeds ([`v0.0.3-seed`](https://github.com/vibe-scheme/vibe/releases/tag/v0.0.3-seed), [`v0.0.2-seed`](https://github.com/vibe-scheme/vibe/releases/tag/v0.0.2-seed), [`v0.0.1-seed`](https://github.com/vibe-scheme/vibe/releases/tag/v0.0.1-seed)) are available via `VIBE_SEED_TAG` for historical commits. Maintainer publishing: `./build.sh release-seed` and [`RELEASING.md`](RELEASING.md).

**Build pipeline**: `vibe_kernel` compiles each `.vibe` file to LLVM bitcode (`.bc`) → `llvm-link` links all modules → `llc` compiles to native object → system linker produces the `vibe_kernel` executable.

### Using CMake Directly

```bash
# Create build directory
mkdir -p build
cd build

# Configure
cmake ..

# Build
cmake --build .

# The executable will be at: build/bin/vibe_kernel
```

**Note**: You need an existing `vibe_kernel` binary (or run `./build.sh build` first) for the compiler to build itself.

## Quick Start

Once built, the compiler can be used to compile Vibe source files:

```bash
# Compile a Vibe source file to LLVM bitcode
./build/bin/vibe_kernel input.vibe -o output.bc

# Or output human-readable LLVM IR
./build/bin/vibe_kernel input.vibe -o output.ll
```

## Documentation

- **[AGENTS.md](AGENTS.md)** — Guide for AI agents working on this project
- **[docs/design/vision.md](docs/design/vision.md)** — Mission, goals, architecture
- **[docs/design/macro-system.md](docs/design/macro-system.md)** — Macro implementation roadmap
- **[docs/design/primitive-forms.md](docs/design/primitive-forms.md)** — Primitive vs derived forms
- **[docs/design/r7rs-compliance.md](docs/design/r7rs-compliance.md)** — R7RS compliance tracker
- **[docs/README.md](docs/README.md)** — Documentation index

## Development Status

- **Done**: Self-hosted compiler
- **Next**: Macro system (unhygienic)
- **Planned**: Kernel rewrite using macros
- **Planned**: Macro system (hygienic)
- **Not started**: R7RS primitive forms (`define`, `lambda`, `if`, `set!`, `quote`)
- **Not started**: R7RS derived forms (`let`, `cond`, `and`, `or`, etc.)
- **Not started**: Standard library
- **Not started**: Binding registry

## Known Limitations

1. **Target Triple**: Hardcoded to `arm64-apple-darwin` in `kernel/codegen.vibe`. See `docs/design/cross-compilation-plan.md` for multi-architecture plans.

2. **Platform Support**: Currently configured for macOS. Linux support requires updating the target triple in `kernel/codegen.vibe`.

3. **LLVM Version**: Requires LLVM 21+. Run `./build.sh clean` after upgrading LLVM so CMake reconfigures.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contributor workflow and [AGENTS.md](AGENTS.md) for:
- Coding standards and practices
- Directory structure conventions
- Documentation requirements
- Testing strategies

## License

(To be determined)

## Acknowledgments

Vibe is inspired by R7RS Small Scheme and aims to provide a modern, self-hosting implementation that compiles to efficient native code via LLVM.
