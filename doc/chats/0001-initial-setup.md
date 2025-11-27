# Chat 0001: Initial Bootstrap Compiler Setup

**Date**: 2025-11-27
**Context**: Setting up the bootstrap compiler project structure and initial implementation plan

## Overview

This conversation established the initial plan for implementing the Vibe language bootstrap compiler. The bootstrap compiler will be written entirely in LLVM IR (bitcode) and will provide the minimal functionality needed to bootstrap the Vibe language.

## Key Decisions

1. **Bootstrap Language**: The bootstrap compiler will be written in pure LLVM IR, not C/C++. This ensures we can compile to bitcode and link modules together.

2. **Directory Structure**: Established clear separation between:
   - `bootstrap/` - Bootstrap compiler code (LLVM IR)
   - `src/` - Future self-hosted Vibe code
   - `doc/` - Documentation repository
   - `test/` - Test files

3. **Build System**: Using CMake with LLVM toolchain to:
   - Assemble LLVM IR files to bitcode
   - Link bitcode modules together
   - Compile to native executable

4. **Core Primitive**: `define-bitcode` is identified as the central primitive that enables self-hosting. It allows binding LLVM modules to names, enabling the Vibe kernel to be written in Vibe itself.

## Implementation Plan

The implementation will proceed in phases:

1. **Phase 1**: Project structure and build system setup
2. **Phase 2**: Lexer implementation
3. **Phase 3**: Parser implementation
4. **Phase 4**: Runtime foundation (including `define-bitcode`)
5. **Phase 5**: FFI system
6. **Phase 6**: Compiler driver

## Components

### Lexer (`bootstrap/lexer/lexer.ll`)
- Token types: identifier, number, string, symbol, paren, quote, etc.
- Functions: `lex_init()`, `lex_next()`, `lex_peek()`, `lex_error()`
- Handles R7RS Scheme lexical syntax

### Parser (`bootstrap/parser/parser.ll`)
- Parses S-expressions from token stream
- Functions: `parse_init()`, `parse_expr()`, `parse_list()`, `parse_atom()`, `parse_error()`
- Supports quote, quasiquote, unquote syntax

### Runtime (`bootstrap/runtime/runtime.ll`)
- Core data structures: VibeValue, VibeCons, VibeSymbol, VibeString, VibeNumber
- Memory management primitives
- Garbage collection foundation
- `define-bitcode` primitive implementation

### FFI System (`bootstrap/runtime/ffi.ll`)
- Platform abstraction (POSIX dlopen/dlsym, Windows LoadLibrary/GetProcAddress)
- Type conversion between Vibe values and C types
- Function calling interface

### Compiler Driver (`bootstrap/compiler/main.ll`)
- Main entry point
- Command-line argument parsing
- Orchestrates lexer → parser → code generation pipeline

## Documentation

Created documentation structure:
- `AGENTS.md` - Guide for AI agents working on the project
- `doc/design/bootstrap-plan.md` - Formal implementation plan
- `doc/chats/0001-initial-setup.md` - This conversation
- `doc/README.md` - Documentation index

## Next Steps

1. Complete Phase 1 (project structure) ✓
2. Begin Phase 2 (lexer implementation)
3. Continue through remaining phases
4. Test each component as it's implemented

## Notes

- All functions should be documented with human-language descriptions
- Use `snake_case` for LLVM function names
- Keep bootstrap code minimal - only what's needed to bootstrap
- Error messages should be informative and include context
