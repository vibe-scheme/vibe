> **ARCHIVED** — This document describes work completed during the bootstrap era.
> The bootstrap compiler has been retired; Vibe is now fully self-hosted.
> See `vision.md` for current goals.

# Bootstrap Compiler Implementation Plan

## Overview

The bootstrap compiler for Vibe is written entirely in LLVM IR (bitcode). It provides the minimal functionality needed to bootstrap the Vibe language, which will eventually be self-hosted (written in Vibe itself).

## Architecture

### Components

1. **Lexer** (`bootstrap/lexer/lexer.ll`)
   - Tokenizes source code according to R7RS Scheme lexical syntax
   - Handles identifiers, numbers, strings, symbols, comments
   - Provides token stream interface

2. **Parser** (`bootstrap/parser/parser.ll`)
   - Parses S-expressions from token stream
   - Builds Abstract Syntax Tree (AST)
   - Handles quote, quasiquote, unquote syntax

3. **Runtime** (`bootstrap/runtime/runtime.ll`)
   - Core data structures (VibeValue, VibeCons, VibeSymbol, etc.)
   - Memory management primitives
   - Garbage collection foundation
   - Core primitives including `define-bitcode`

4. **FFI System** (`bootstrap/runtime/ffi.ll`)
   - Platform abstraction for dynamic library loading
   - Type conversion between Vibe and C types
   - Function calling interface

5. **Compiler Driver** (`bootstrap/compiler/main.ll`)
   - Main entry point
   - Command-line argument parsing
   - Orchestrates lexer → parser → code generation pipeline
   - Outputs LLVM bitcode or assembly

## Data Structures

### VibeValue

Tagged union representing all Vibe values:
- Type tag (integer, string, symbol, cons, etc.)
- Value payload

### VibeCons

Cons cell for lists:
- Car (first element)
- Cdr (rest of list)

### VibeSymbol

Symbol internment table for efficient symbol comparison.

### VibeString

String representation with length and data.

### VibeNumber

Number representation (integer or floating-point).

## Core Primitives

### `define-bitcode`

The central primitive that enables self-hosting. Binds an LLVM module to a name, allowing core language features to be implemented in Vibe itself.

**Signature**: `(define-bitcode name formals body)`

**Purpose**: Allows defining functions that are implemented as LLVM IR, enabling the Vibe kernel to be written in Vibe.

**Example**:
```scheme
(define-bitcode (lambda formals body)
  ;; LLVM IR code implementing lambda
  ...)
```

## Implementation Phases

### Phase 1: Project Structure ✓
- Create directory structure
- Set up CMake build system
- Create documentation files

### Phase 2: Lexer
- Implement token types and structures
- Implement lexer functions (lex_init, lex_next, lex_peek, lex_error)
- Handle R7RS Scheme lexical syntax

### Phase 3: Parser
- Implement AST structures
- Implement parser functions (parse_init, parse_expr, parse_list, parse_atom)
- Support quote syntax

### Phase 4: Runtime Foundation
- Implement core data structures
- Implement basic memory management
- Implement symbol internment
- Implement `define-bitcode` primitive

### Phase 5: FFI System
- Implement platform abstraction (POSIX/Windows)
- Implement type conversion
- Implement function calling
- **FFI-based LLVM Integration**: Use FFI to call LLVM C API for bitcode generation
  - Load LLVM libraries dynamically via FFI
  - Resolve LLVM C API function symbols
  - Create wrappers for LLVM context, module, function creation
  - Enable direct bitcode generation instead of text IR

### Phase 6: Compiler Driver
- Implement main entry point
- Wire together lexer, parser, code generation
- Test end-to-end compilation

## Technical Considerations

- All bootstrap code is pure LLVM IR
- Bitcode modules are linked together using `llvm-link`
- Final executable is created by compiling linked bitcode to native code
- Error handling should be informative and include context
- Keep bootstrap code minimal - only what's needed to bootstrap

## Testing Strategy

- Test lexer with various Scheme tokens
- Test parser with nested S-expressions
- Test `define-bitcode` with simple LLVM module bindings
- Test FFI with simple C library calls
- Test end-to-end compilation of simple Vibe programs

## FFI-Based LLVM Integration

The bootstrap compiler uses FFI to integrate with LLVM C API, enabling:
- Direct bitcode generation via LLVM API calls
- Runtime loading of LLVM libraries
- Platform abstraction for LLVM integration
- Future migration path to 2nd gen bootstrap

See `doc/design/ffi-llvm-integration.md` for detailed design.

## Future Work

Once bootstrap compiler is complete:
1. Write core Vibe kernel in Vibe itself (using `define-bitcode`)
2. Convert bootstrap .ll files to `define-bitcode-*` methods (2nd gen bootstrap)
3. Implement macro system
4. Begin self-hosting the compiler
5. Expand standard library
6. Optimize code generation
7. The 2nd gen bootstrap will use FFI for LLVM C API calls instead of text IR generation
