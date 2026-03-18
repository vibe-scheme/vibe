# Guide for AI Agents Working on Vibe

## Overview

This document provides guidance for AI agents contributing to the Vibe language project. Vibe is a R7RS Small Scheme derivative that compiles to LLVM bitcode, with a focus on self-hosting and extensibility.

**Vibe is fully self-hosted.** The compiler (`vibe_kernel`) compiles itself from `.vibe` source files. The original bootstrap compiler (written in LLVM IR) has been retired and is available only in git history for reference.

## Vibe Coding Strategy and Philosophy

### Core Principles

1. **Self-Hosting**: Vibe is written in Vibe. The compiler compiles itself from `.vibe` source files in the `kernel/` directory. A seed binary (from a GitHub release) is used only for initial bootstrapping on a clean checkout.

2. **Human-Language Descriptions**: All functions should be documented with clear, human-language descriptions explaining what they do and why. This is part of Vibe's philosophy of making code readable and understandable.

3. **`define-bitcode` Primitive**: This is the central primitive that enables the Vibe kernel to be written in Vibe itself. It allows binding LLVM modules to names, enabling core language features (like `lambda`) to be implemented in Vibe.

4. **Fix at the Source**: Always fix issues at their root cause rather than adding workarounds. Prioritize correctness and proper architecture over maintaining broken behavior.

5. **Parser/Codegen Separation**: The parser phase should handle all syntax normalization (e.g., stripping vertical bars `|` from symbols like `|%Foo|` → `%Foo`), while the codegen phase should only handle semantic resolution (e.g., mapping type names to LLVM types). This separation simplifies both layers and makes the codebase more maintainable.

### Code Style

- **Naming Conventions**: Use `snake_case` for LLVM functions and variables
- **Documentation**: Every function should have a comment explaining its purpose
- **Error Handling**: Handle errors gracefully with informative error messages
- **Modularity**: Keep components separate and well-defined (lexer, parser, codegen, etc.)
- **Parentheses**: Take care to keep parentheses balanced in Vibe source (`.vibe` files). Unclosed `)` causes infinite parse loops; extra `)` can trigger spurious main generation. The compiler reports "unexpected end of file (unclosed parentheses)" or "unexpected ) (too many closing parens)" when it detects imbalance.

## Directory Structure

```
vibe/
├── kernel/            # Compiler source (Vibe, .vibe files)
│   ├── lexer.vibe     # Lexer
│   ├── parser.vibe    # Parser
│   ├── ffi.vibe       # FFI dynamic library functions
│   ├── dsl.vibe       # LLVM C API wrappers
│   ├── main.vibe      # Compiler driver (main + helpers)
│   └── codegen.vibe   # Code generator
├── src/               # Future standard library code
├── doc/               # Documentation
│   ├── design/        # Design documents and formal plans
│   ├── chats/         # Recorded development conversations
│   └── examples/      # Example programs and tutorials
├── test/              # Test files
└── build/             # Build output (gitignored)
```

## Build System Overview

The Vibe compiler is self-hosted: `vibe_kernel` compiles `.vibe` source files to produce a new `vibe_kernel`.

### Building

```bash
./build.sh build    # Build the compiler (default)
./build.sh clean    # Remove build directory
./build.sh test     # Run tests
./build.sh install  # Install
```

On a clean checkout with no existing `vibe_kernel` binary, `build.sh` automatically downloads a seed compiler from the [GitHub release](https://github.com/vibe-scheme/vibe/releases/tag/v0.0.1-seed) and uses it to compile the `.vibe` source. Subsequent builds use the just-built `vibe_kernel`.

**After upgrading LLVM**: Run `./build.sh clean` first so CMake reconfigures and finds the new LLVM paths.

### Build Pipeline

1. `vibe_kernel` compiles each `.vibe` file in `kernel/` to LLVM bitcode (`.bc`)
2. `llvm-link` links all bitcode modules together
3. `llc` compiles the linked bitcode to a native object file
4. The system linker produces the `vibe_kernel` executable, linked against LLVM C API libraries

### Seed Binary

The seed compiler is hosted as a GitHub release asset at `v0.0.1-seed`. It was produced through the original bootstrap chain (LLVM IR → bootstrap compiler → kernel compiler → self-hosted compiler) and verified to compile all kernel modules correctly. The original LLVM IR bootstrap source remains in git history for emergency re-bootstrapping.

### Vibe DSL Conventions

**Forward declarations required**: Every function called via `(llvm:call ...)` in a `.vibe` file must be visible at the call site. The compiler resolves calls by searching (1) local bindings, (2) the function list, (3) parameters, (4) constants. If a called function is defined in another module or later in the same file, it must be forward-declared with `(llvm:declare-function ...)` at the top of the file. **Calls to undeclared functions silently return null**, causing dependent `let*` bindings to be dropped without any error message. See chat 0039.

**Cross-block variable usage**: `let*` introduces lexical scope; `llvm:label` does not. For bindings to be visible in label blocks, put the labels **inside** the `let*` body. If `let*` and `llvm:label` are siblings, the label cannot access the `let*` bindings (out of scope). Correct structure: `(let* ((x (llvm:alloca ...))) (llvm:label 'a ...) (llvm:label 'b ...))` — both labels can use `x`. See `test_cross_block` in `kernel/codegen.vibe` and chat 0034.

**Cross-block values**: Use alloca/store/load for values that flow across blocks. Each predecessor stores its value into an alloca; the merge block loads. A future mem2reg optimization pass (via LLVMRunPasses) will promote these to phi nodes. Do not use phi nodes for migration—they require cross-block variable resolution that can be fragile. See Chat 0034 and Chat 0036.

## Development Chat Documentation

**IMPORTANT**: All development conversations must be memorialized in the `doc/chats/` directory. Each conversation should be saved as a numbered markdown file (e.g., `0001-initial-setup.md`, `0002-lexer-implementation.md`, etc.). **One session, one chat document** — do not split a single session across multiple chat files.

### Chat Documentation Format

Each chat document should include:
- Date, model used, and context of the conversation
  - **Model tracking**: Always record which AI model was used for the session (e.g., `**Model**: Cursor Composer 1`, `**Model**: Claude claude-4.6-opus-high-thinking`). This helps track which model contributed to which parts of the codebase.
- **Complete session overview**: Document ALL work done in the session, not just the final topic investigated. Review git diff to ensure comprehensive coverage of:
  - Bug fixes
  - Feature implementations (including migrated functions and methods)
  - Code cleanup
  - Security fixes
  - Architectural discoveries
  - Refactoring work
- Key decisions made
- Implementation details discussed
- Any important notes or considerations
- Links to related design documents or code

**Note**: Sessions often involve multiple related fixes and investigations. The chat documentation should reflect the full breadth of work accomplished, even if topics seem unrelated. This provides better historical context and helps future developers understand the evolution of the codebase.

### Date Verification for Chat Documents

**CRITICAL**: Always verify the current date before creating or updating chat documents. Incorrect dates can cause confusion in historical records.

**Process**:
1. Before writing the date in a chat document, run `date +"%Y-%m-%d"` to get the current date
2. Use ISO 8601 format: `YYYY-MM-DD` (e.g., `2025-12-28`)
3. If updating an existing chat document, verify the date is still correct
4. When in doubt, check the system date rather than guessing

### Chat Immutability and Precedence

**Committed chats are immutable**: Once a chat document is committed, do not modify it. Each chat memorializes a session and its outcome; editing past chats would distort the historical record.

**Contradictory evidence**: When later chats or code contradict an earlier chat, give precedence to the later chat. Document the correction in the newer chat rather than editing the older one.

## Coding Standards and Practices

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

2. **Build and Test**: Run `./build.sh build` to build from source. The seed compiler is downloaded automatically on first build.

3. **Document Your Work**: 
   - Add comments to code explaining functionality
   - Update relevant design documents if architecture changes
   - Create chat documentation for significant conversations

4. **Test Thoroughly**: 
   - Test each component as you implement it
   - Test integration between components
   - Test error conditions

## Documentation Structure

### Design Documents (`doc/design/`)

Formal plans and architectural decisions. Examples:
- `bootstrap-plan.md` - Historical bootstrap compiler plan
- `cross-compilation-plan.md` - Plan for cross-compilation support
- `ffi-llvm-integration.md` - FFI system design

### Chat Documentation (`doc/chats/`)

Recorded development conversations, numbered sequentially:
- `0001-initial-setup.md`
- `0002-lexer-implementation.md`
- etc.

### Examples (`doc/examples/`)

Example programs and tutorials demonstrating Vibe features.

## Technical Considerations

### LLVM Version Requirements

- **LLVM 21+** is required
- The build uses LLVM tools (`llvm-as`, `llvm-link`, `llc`) during build time
- The compiler links against LLVM C API libraries for bitcode generation
- Verify installation with: `llvm-as --version`, `llvm-link --version`, `llc --version`

### Target Architecture

The compiler currently hardcodes the target triple `arm64-apple-darwin` in `kernel/codegen.vibe`. See `doc/design/cross-compilation-plan.md` for the plan to support runtime target detection and cross-compilation.

**Current Configuration**:
- **Apple Silicon (arm64)**: `arm64-apple-darwin` with data layout `"e-m:o-i64:64-i128:128-n32:64-S128"`

### Build System Notes

- The CMake build system finds LLVM tools and LLVM libraries for linking
- The compiler executable links against LLVM C API libraries (Core, BitWriter, Support, Target, MC, Linker)
- FFI enables calling platform functions at runtime (dlopen/dlsym)
- Architecture-specific LLVM components are automatically linked based on the detected target triple (AArch64 for arm64, X86 for x86_64)

### Platform-Aware Target Initialization

The `llvm_initialize_native_target()` function in `kernel/dsl.vibe` detects the target architecture at runtime and initializes the appropriate LLVM target components. Currently only AArch64 is supported; see `doc/design/cross-compilation-plan.md` for X86 support plans.

## Key Concepts

### `define-bitcode-*` Primitives

These are the core primitives that enable self-hosting. They allow binding LLVM functions, types, and constants to names, enabling core language features to be implemented in Vibe itself. For example:

```scheme
(define-bitcode-function (lambda (formals |i8*|) (body |i8*|)) |void*|
  ;; LLVM IR code that implements lambda
  ...)
```

### FFI System

The FFI (Foreign Function Interface) system allows Vibe to call functions from dynamic libraries. The FFI system is implemented in `kernel/ffi.vibe` and `kernel/dsl.vibe` and provides:
- Library loading (`ffi_load_library`) via dlopen
- Symbol resolution (`ffi_get_symbol`) via dlsym
- LLVM-specific wrappers for creating contexts, modules, functions, etc.

### LLVM Integration

The compiler uses LLVM C API functions (statically linked) for bitcode generation:
- Creating LLVM contexts and modules programmatically
- Generating functions, types, and constants via API calls
- Writing bitcode files directly
- Error handling and validation through LLVM's API

### Future: `define-bitcode-ffi-function`

A planned primitive to declare external C functions from Vibe code:

```scheme
(define-bitcode-ffi-function printf
  (return-type |i32|)
  (params (|i8*| format) ...)
  (linkage external)
  (vararg #t))
```

This will replace hardcoded external function declarations in `codegen_init()` and allow user-defined FFI declarations.

### Future: Remove Implicit Main Insertion

The compiler currently has `codegen_main` inject a `main` function when a module has top-level executable expressions. This should be removed in favor of explicit `main` definition.

## Next Steps

Now that Vibe is self-hosted, priorities are:
1. Cross-compilation support (see `doc/design/cross-compilation-plan.md`)
2. Implement `define-bitcode-ffi-function` for user-defined FFI
3. Implement the macro system
4. Expand the standard library
5. Optimize code generation

## Questions or Issues

If you encounter issues or have questions:
1. Check existing documentation in `doc/design/` and `doc/chats/`
2. Review the design documents for architectural context
3. Document any new insights or decisions in the appropriate chat document

## End-of-Session Practices

At the end of each development session, the following steps should be completed:

### 1. Memorialize the Chat

Create a new chat document in `doc/chats/` following the naming convention:
- Format: `NNNN-descriptive-name.md` where NNNN is the next sequential number
- Check existing chat files to determine the next number
- **Review git diff** to ensure comprehensive coverage of ALL work done:
  - Run `git diff --stat` to see all modified files
  - Review `git diff` for each major file to understand all changes
  - Don't just document the final topic - document everything accomplished
- Include:
  - Date and context
  - **Complete overview** of ALL work completed (not just the last investigation)
  - Key decisions made
  - Implementation details for each major change
  - Technical challenges encountered
  - Files modified (with specific changes)
  - Related documentation references

### 2. Generate Git Commit Message

Create a commit message following best practices:
- **First line**: Concise summary (50-72 characters, imperative mood)
- **Blank line**: Separate summary from body
- **Body**: Detailed explanation of changes, why they were made, and any important notes
- **Format**: Use present tense, imperative mood (e.g., "Fix string constant generation" not "Fixed string constant generation")

### 3. Update AGENTS.md (if needed)

If new practices, patterns, or conventions were established during the session, document them in AGENTS.md to ensure consistency in future sessions.
