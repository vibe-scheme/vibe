# Chat 0027: Codegen Migration Batch 1

**Date**: 2026-02-09  
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)  

## Overview

This session implemented the first batch of codegen migration from `bootstrap/codegen.ll` to `kernel/codegen.vibe`, along with preparatory architectural changes. This is a significant step in the self-hosting journey: the codegen module is now partially written in Vibe DSL.

## Work Completed

### Phase 0: Split `bootstrap/ffi.ll` into `ffi.ll` + `dsl.ll`

Mirrored the `kernel/ffi.vibe` + `kernel/dsl.vibe` structure in the bootstrap:
- **`bootstrap/ffi.ll`**: Trimmed to platform FFI only (dlopen/dlsym wrappers, ~71 lines)
- **`bootstrap/dsl.ll`**: New file with LLVM C API declarations and wrapper functions (~1220 lines extracted from original ffi.ll)
- **`CMakeLists.txt`**: Updated BOOTSTRAP mode FFI build to assemble both files separately and link together

### Phase 1: New DSL Primitives

Added three new LLVM instruction wrappers needed for codegen migration:
- `llvm:urem` / `llvm_build_urem` - Unsigned remainder
- `llvm:udiv` / `llvm_build_udiv` - Unsigned division
- `llvm:ptrtoint` / `llvm_build_ptrtoint` - Pointer to integer conversion

Added to:
- `bootstrap/dsl.ll` (LLVM C API declares + wrapper functions)
- `kernel/dsl.vibe` (declare-function + define-function wrappers)
- `bootstrap/codegen.ll` (dispatch entries + handler functions)

### Phase 2: Build System Changes

Updated `CMakeLists.txt` with `USE_VIBE_FILES` branching for the codegen module:
- BOOTSTRAP mode: Uses `codegen.ll` only
- KERNEL mode: Compiles `kernel/codegen.vibe` via bootstrap_compiler, assembles `codegen_no_vibe.ll`, links both
- SELF_HOST mode: Compiles `kernel/codegen.vibe` via vibe_kernel, assembles `codegen_no_vibe.ll`, links both

### Phase 3: Create `bootstrap/codegen_no_vibe.ll`

Created by copying `codegen.ll` and replacing 9 function definitions with `declare` statements. All remaining functions are intact with their full implementations.

### Phase 4: Create `kernel/codegen.vibe`

Implemented 9 codegen utility functions in Vibe DSL:

1. **`codegen_dsl_check_primitive`** - String comparison for DSL primitive matching
2. **`codegen_parse_int_string`** - Integer parsing from string (digit loop)
3. **`codegen_parse_int_from_ast`** - Integer extraction from AST number nodes
4. **`codegen_extract_quoted_atom`** - Atom name extraction from quote nodes
5. **`codegen_create_pointer_node`** - AST node creation for pointer values
6. **`codegen_create_string_node`** - AST node creation for strings (with memcpy)
7. **`codegen_create_cons`** - Cons cell creation
8. **`codegen_create_pair`** - Pair creation (cons with cdr wrapper)
9. **`codegen_is_array_type`** - LLVM type checking heuristic

### Phase 5: Documentation

Updated `AGENTS.md` with codegen migration status and new file listings.

## Key Decisions

1. **C library functions declared as external** rather than FFI-defined in codegen.vibe. This avoids duplicate symbol definitions when linked with lexer.vibe (which already defines malloc/free/memcpy via FFI). The declarations resolve at link time.

2. **`strncmp` declared with `i32` length** parameter to match `codegen_no_vibe.ll`'s existing declaration, with explicit `llvm:trunc` from i64 to i32.

3. **Flat `let*` binding style** preferred over deeply nested let*. Deep nesting (17+ levels) caused the bootstrap compiler to generate spurious `main` functions. Flat bindings with sequential `llvm:store` calls are cleaner and avoid this issue.

4. **`(llvm:sub 0 1)` for negative constants** since `(llvm:const-int |i32| -1)` doesn't support negative values (the parser treats `-1` as non-digit and returns 0).

## Technical Challenges

### 1. `llvm:trunc` Syntax (Segfault)
The DSL expects 3 arguments: `(llvm:trunc value source-type target-type)`, not 2. Using only 2 arguments caused the codegen to access a null pointer (trying to read the third argument). Fixed by providing all 3 args: `(llvm:trunc id_len |i64| |i32|)`.

### 2. Missing `%ASTNode` Type Definition
Functions using `|%ASTNode*|` parameters compiled to zero-parameter functions because the type couldn't be resolved. Fixed by adding `(llvm:define-type ASTNode ...)` at the top of codegen.vibe.

### 3. Deep Nesting Generates Spurious `main`
The `codegen_create_pair` function with 17+ nested `let*` levels caused the bootstrap compiler to generate a `main` function in the output. This triggered a "symbol multiply defined" error during final linking. Resolved by flattening to 3 nesting levels using multi-binding `let*` forms.

### 4. Cross-Label Variable Access
LLVM SSA values defined in one basic block are accessible in successor blocks. The Vibe DSL's local variable table correctly supports this: `element_type` defined in `'get_element_type` label is accessible in `'check_array_element` label.

## Files Modified

- `bootstrap/ffi.ll` - Trimmed to platform FFI only
- `bootstrap/dsl.ll` - New: LLVM C API wrappers (extracted from ffi.ll)
- `bootstrap/codegen.ll` - Added urem/udiv/ptrtoint dispatch and handlers
- `bootstrap/codegen_no_vibe.ll` - New: codegen with 9 functions as declares
- `kernel/dsl.vibe` - Added urem/udiv/ptrtoint wrappers
- `kernel/codegen.vibe` - New: 9 migrated codegen functions
- `CMakeLists.txt` - Updated for ffi/dsl split and codegen KERNEL/SELF_HOST support
- `AGENTS.md` - Updated codegen migration status

## Build Validation

All three build modes compile and link successfully:
- **BOOTSTRAP**: `codegen.ll` with all functions defined
- **KERNEL**: `codegen.vibe` (9 functions) + `codegen_no_vibe.ll` (remaining functions)
- **SELF_HOST**: Same as KERNEL but compiled by vibe_kernel itself

Test suite failure is pre-existing (arm64/x86_64 architecture mismatch in test runner).
