# Guide for AI Agents Working on Vibe

## Overview

This document provides guidance for AI agents contributing to the Vibe language project. Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode, with a focus on self-hosting and extensibility.

## Vibe Coding Strategy and Philosophy

### Core Principles

1. **Self-Hosting**: The goal is to write Vibe in Vibe itself. The bootstrap compiler is written in LLVM IR, but the eventual goal is to have the entire compiler written in Vibe.

2. **Human-Language Descriptions**: All functions should be documented with clear, human-language descriptions explaining what they do and why. This is part of Vibe's philosophy of making code readable and understandable.

3. **Minimal Bootstrap**: The bootstrap compiler should be minimal - only what's absolutely necessary to bootstrap the language. Once we can write Vibe in Vibe, we can expand functionality.

4. **`define-bitcode` Primitive**: This is the central primitive that enables the Vibe kernel to be written in Vibe itself. It allows binding LLVM modules to names, enabling core language features (like `lambda`) to be implemented in Vibe.

### Code Style

- **Naming Conventions**: Use `snake_case` for LLVM functions and variables
- **Documentation**: Every function should have a comment explaining its purpose
- **Error Handling**: Handle errors gracefully with informative error messages
- **Modularity**: Keep components separate and well-defined (lexer, parser, runtime, etc.)

## Directory Structure

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

## Development Chat Documentation

**IMPORTANT**: All development conversations must be memorialized in the `doc/chats/` directory. Each conversation should be saved as a numbered markdown file (e.g., `0001-initial-setup.md`, `0002-lexer-implementation.md`, etc.).

### Chat Documentation Format

Each chat document should include:
- Date and context of the conversation
- Key decisions made
- Implementation details discussed
- Any important notes or considerations
- Links to related design documents or code

## Coding Standards and Practices

### LLVM IR Code

- Use LLVM IR directly (not C/C++) for all bootstrap code
- Ensure all code compiles to bitcode that can be linked together
- Use consistent type definitions across modules
- Document all functions with their purpose and parameters

### Error Handling

- Always provide informative error messages
- Include context (line numbers, file names, etc.) in error messages
- Use consistent error reporting mechanisms across modules

### Testing

- Create test files in the `test/` directory
- Test components individually before integration
- Test edge cases and error conditions
- Document test cases and expected behavior

## How to Contribute

1. **Understand the Architecture**: Read the design documents in `doc/design/` to understand the overall architecture and goals.

2. **Follow the Implementation Order**: The bootstrap compiler should be implemented in phases:
   - Phase 1: Project Structure
   - Phase 2: Lexer
   - Phase 3: Parser
   - Phase 4: Runtime Foundation (including `define-bitcode`)
   - Phase 5: FFI System
   - Phase 6: Compiler Driver

3. **Document Your Work**: 
   - Add comments to code explaining functionality
   - Update relevant design documents if architecture changes
   - Create chat documentation for significant conversations

4. **Test Thoroughly**: 
   - Test each component as you implement it
   - Test integration between components
   - Test error conditions

5. **Keep It Minimal**: Remember that the bootstrap compiler should be minimal. Don't add features that aren't necessary for bootstrapping.

## Documentation Structure

### Design Documents (`doc/design/`)

Formal plans and architectural decisions. Examples:
- `bootstrap-plan.md` - Plan for bootstrap compiler
- `runtime-design.md` - Runtime system design
- `ffi-design.md` - FFI system design

### Chat Documentation (`doc/chats/`)

Recorded development conversations, numbered sequentially:
- `0001-initial-setup.md`
- `0002-lexer-implementation.md`
- etc.

### Examples (`doc/examples/`)

Example programs and tutorials demonstrating Vibe features.

## Technical Considerations

### LLVM Version Requirements

- **LLVM 21** is required (specifically version 21.x)
- The bootstrap compiler uses LLVM tools (`llvm-as`, `llvm-link`, `llc`) but does NOT link against LLVM libraries at runtime
- Only the LLVM tools are needed during build time
- Verify installation with: `llvm-as --version`, `llvm-link --version`, `llc --version`

### Target Triple Restriction

**IMPORTANT**: All LLVM IR files currently hardcode the target triple to the build system's architecture (e.g., `x86_64-apple-macosx10.15.0`). This means:

- The bootstrap compiler will only work on the same architecture/OS it was built on
- Cross-compilation is not currently supported (this is a future goal)
- Developers should be aware that target triples in `.ll` files match their development machine

When adding new `.ll` files, use the same target triple as existing files. The target triple can be found at the top of any `.ll` file:
```
target triple = "x86_64-apple-macosx10.15.0"
```

For Linux builds, update the target triple to match your distribution (e.g., `x86_64-unknown-linux-gnu`).

### Build System Notes

- The CMake build system finds LLVM tools but does not require LLVM libraries for linking
- The bootstrap compiler executable only needs standard C libraries (libc) and POSIX dynamic library loading (libdl on Linux)
- macOS doesn't need a separate `dl` library (dlopen is in libc)

## Key Concepts

### `define-bitcode` Primitive

This is the core primitive that enables self-hosting. It allows binding LLVM modules to names, enabling core language features to be implemented in Vibe itself. For example:

```scheme
(define-bitcode (lambda formals body)
  ;; LLVM IR code that implements lambda
  ...)
```

This primitive is implemented in the bootstrap runtime and is essential for implementing the Vibe kernel in Vibe.

### FFI System

The FFI (Foreign Function Interface) system allows Vibe to call functions from dynamic libraries. This is necessary for:
- System calls
- Calling C libraries
- Platform-specific functionality

The FFI system is implemented in `bootstrap/runtime/ffi.ll` and provides:
- Library loading (`ffi_load_library`)
- Symbol resolution (`ffi_get_symbol`)
- Function calling (`ffi_call`)
- Type mapping (`ffi_define_type`)

## Questions or Issues

If you encounter issues or have questions:
1. Check existing documentation in `doc/design/` and `doc/chats/`
2. Review the implementation plan in `doc/design/bootstrap-plan.md`
3. Document any new insights or decisions in the appropriate chat document

## Next Steps After Bootstrap

Once the bootstrap compiler is complete:
1. Write the core Vibe kernel in Vibe itself (using `define-bitcode`)
2. Implement the macro system
3. Begin self-hosting the compiler
