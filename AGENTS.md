# Guide for AI Agents Working on Vibe

## Overview

This document provides guidance for AI agents contributing to the Vibe language project. Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode, with a focus on self-hosting and extensibility.

## Vibe Coding Strategy and Philosophy

### Core Principles

1. **Self-Hosting**: The goal is to write Vibe in Vibe itself. The bootstrap compiler is written in LLVM IR, but the eventual goal is to have the entire compiler written in Vibe.

2. **Human-Language Descriptions**: All functions should be documented with clear, human-language descriptions explaining what they do and why. This is part of Vibe's philosophy of making code readable and understandable.

3. **Minimal Bootstrap**: The bootstrap compiler should be minimal - only what's absolutely necessary to bootstrap the language. Once we can write Vibe in Vibe, we can expand functionality.

4. **`define-bitcode` Primitive**: This is the central primitive that enables the Vibe kernel to be written in Vibe itself. It allows binding LLVM modules to names, enabling core language features (like `lambda`) to be implemented in Vibe.

5. **Fix at the Source**: Always fix issues at their root cause rather than adding workarounds. For example, if the lexer isn't recognizing numbers correctly, fix the lexer rather than adding fallback logic in the codegen. We don't need to worry about backwards compatibility until we actually have something working - prioritize correctness and proper architecture over maintaining broken behavior.

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
- The bootstrap compiler uses LLVM tools (`llvm-as`, `llvm-link`, `llc`) during build time
- The bootstrap compiler will link against LLVM libraries via FFI for bitcode generation
- FFI is used to call LLVM C API functions for generating bitcode programmatically
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

- The CMake build system finds LLVM tools and LLVM libraries for linking
- The bootstrap compiler executable links against LLVM C API libraries (Core, IR, Support, Target, etc.)
- FFI is reintroduced to enable calling LLVM C API functions at runtime
- FFI requires dynamic library loading (dlopen/dlsym) - libdl on Linux, built-in on macOS
- LLVM libraries will be loaded via FFI at runtime for bitcode generation

## Key Concepts

### `define-bitcode-*` Primitives

These are the core primitives that enable self-hosting. They allows binding LLVM functions, types, and constants to names,
enabling core language features to be implemented in Vibe itself. For example:

```scheme
(define-bitcode-function (lambda (formals |i8*|) (body |i8*|)) |void*|
  ;; LLVM IR code that implements lambda
  ...)
```

This primitive is implemented in the bootstrap runtime and is essential for implementing the Vibe kernel in Vibe.

### FFI System

The FFI (Foreign Function Interface) system allows Vibe to call functions from dynamic libraries. This is necessary for:
- System calls
- Calling C libraries
- Platform-specific functionality
- **LLVM C API integration** - calling LLVM functions for bitcode generation

The FFI system will be implemented in `bootstrap/runtime/ffi.ll` and provides:
- Library loading (`ffi_load_library`) - Load LLVM libraries dynamically
- Symbol resolution (`ffi_get_symbol`) - Get LLVM C API function pointers
- Function calling (`ffi_call`) - Call foreign functions including LLVM C API
- Type mapping (`ffi_define_type`) - Map Vibe types to C/LLVM types
- LLVM-specific wrappers for creating contexts, modules, functions, etc.

## Questions or Issues

If you encounter issues or have questions:
1. Check existing documentation in `doc/design/` and `doc/chats/`
2. Review the implementation plan in `doc/design/bootstrap-plan.md`
3. Document any new insights or decisions in the appropriate chat document

### LLVM Integration via FFI

The bootstrap compiler uses FFI to call LLVM C API functions for bitcode generation. This approach:

- **Keeps bootstrap pure LLVM IR**: No C++ dependency, maintains pure LLVM IR bootstrap
- **Enables runtime flexibility**: Can load different LLVM versions at runtime
- **Provides platform abstraction**: FFI handles platform differences (macOS/Linux/Windows)
- **Future-proof**: Aligns with 2nd generation bootstrap goals where bootstrap .ll files will be converted to `define-bitcode-*` methods
- **Direct bitcode generation**: Can generate bitcode directly via LLVM API instead of text IR strings

The LLVM C API integration via FFI allows:
- Creating LLVM contexts and modules programmatically
- Generating functions, types, and constants via API calls
- Writing bitcode files directly without text IR intermediate format
- Better error handling and validation through LLVM's API

## Next Steps After Bootstrap

Once the bootstrap compiler is complete:
1. Write the core Vibe kernel in Vibe itself (using `define-bitcode`)
2. Convert bootstrap .ll files to `define-bitcode-*` methods (2nd gen bootstrap)
3. Implement the macro system
4. Begin self-hosting the compiler
5. The 2nd gen bootstrap will use FFI for LLVM C API calls instead of text IR generation

### Future: `define-bitcode-ffi-function`

When we begin rewriting `.ll` files in `.vibe`, we should implement `define-bitcode-ffi-function` to:

1. **Declare external C functions from Vibe code**:
   ```scheme
   (define-bitcode-ffi-function printf
     (return-type |i32|)
     (params (|i8*| format) ...)
     (linkage external)
     (vararg #t))
   ```

2. **Replace hardcoded declarations**: Move `printf` and other C library function declarations from hardcoded `codegen_init()` calls to Vibe code, making the compiler more flexible and extensible.

3. **Support user-defined FFI**: Allow users to declare their own external functions for calling C libraries, enabling better integration with system libraries.

4. **Pattern for FFI usage**: This will establish the pattern for declaring and using FFI functions from Vibe code, which is essential for the self-hosting goals.

**Current status**: External function declarations (like `printf`) are hardcoded in `codegen_init()`. The infrastructure for FFI exists, but `define-bitcode-ffi-function` is not yet implemented. This will be implemented as part of the 2nd generation bootstrap when rewriting `.ll` files in `.vibe`.

## End-of-Session Practices

At the end of each development session, the following steps should be completed:

### 1. Memorialize the Chat

Create a new chat document in `doc/chats/` following the naming convention:
- Format: `NNNN-descriptive-name.md` where NNNN is the next sequential number
- Check existing chat files to determine the next number
- Include:
  - Date and context
  - Overview of work completed
  - Key decisions made
  - Implementation details
  - Technical challenges encountered
  - Files modified
  - Related documentation references

### 2. Generate Git Commit Message

Create a commit message following best practices:
- **First line**: Concise summary (50-72 characters, imperative mood)
- **Blank line**: Separate summary from body
- **Body**: Detailed explanation of changes, why they were made, and any important notes
- **Format**: Use present tense, imperative mood (e.g., "Fix string constant generation" not "Fixed string constant generation")

Example:
```
Fix string constant generation in function calls

String constants were being generated inline within function call
arguments, causing invalid LLVM IR syntax. Implemented two-phase
constant generation: collect all string constants at module level
before generating functions, then generate only references in function
calls.

- Add codegen_collect_string_constants to traverse AST and generate
  constants at module level
- Fix getelementptr syntax to include result type and parentheses
- Update codegen_append_call_args to use constant references only

Fixes compilation errors when string literals are used as function
arguments.
```

### 3. Update AGENTS.md (if needed)

If new practices, patterns, or conventions were established during the session, document them in AGENTS.md to ensure consistency in future sessions.
