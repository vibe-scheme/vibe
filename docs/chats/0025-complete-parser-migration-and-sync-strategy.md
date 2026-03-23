# Chat 0025: Complete Parser Migration and Sync Strategy

**Date**: 2026-02-08
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)

## Overview

Completed the parser migration from LLVM IR to Vibe DSL by implementing three new DSL methods (`llvm:undef`, `llvm:insertvalue`, `llvm:extractvalue`), migrating the last two parser functions (`parse_normalize_type_atom`, `parse_create_atom`) from `parser_no_vibe.ll` to `parser.vibe`, and documenting a strategy for keeping bootstrap and kernel files in sync.

## Work Completed

### 1. FFI Layer (ffi.ll)

Added LLVM C API declarations and thin wrappers for three new operations:

- `LLVMGetUndef` / `llvm_get_undef` -- creates an undef value of a given type
- `LLVMBuildInsertValue` / `llvm_build_insert_value` -- inserts a value into an aggregate (struct/array) at a given index
- `LLVMBuildExtractValue` / `llvm_build_extract_value` -- extracts a value from an aggregate at a given index

### 2. Codegen DSL Methods (codegen.ll)

Added three new DSL methods to the Vibe DSL evaluator:

- **`llvm:undef`** -- Syntax: `(llvm:undef type)`. Resolves the type via `codegen_resolve_type_string` and returns an undef value. Used for building aggregate values incrementally.
- **`llvm:insertvalue`** -- Syntax: `(llvm:insertvalue agg-val elt-val index)`. Evaluates the aggregate and element values, parses the index as integer, and builds an insertvalue instruction.
- **`llvm:extractvalue`** -- Syntax: `(llvm:extractvalue agg-val index)`. Evaluates the aggregate value, parses the index, and builds an extractvalue instruction.

Changes required:
- 3 new FFI function declarations
- 3 new string constants for primitive name matching
- 3 new dispatch entries in `codegen_eval_dsl_expr` (after `check_phi`)
- 3 new handler functions (`codegen_dsl_undef`, `codegen_dsl_insertvalue`, `codegen_dsl_extractvalue`)

### 3. Parser Migration (parser.vibe)

#### NormalizeResult Named Type

Defined a new named struct type to replace the anonymous `{ i8*, i64 }` return type:

```scheme
(llvm:define-type NormalizeResult
  (value |i8*|)
  (len |i64|))
```

Named structs and anonymous structs with identical layout are structurally equivalent in LLVM, so this change is transparent to callers.

#### parse_normalize_type_atom

Migrated from `parser_no_vibe.ll`. Key patterns:
- `(llvm:undef |%NormalizeResult|)` creates the initial empty aggregate
- `(llvm:insertvalue result value 0)` sets the pointer field
- `(llvm:insertvalue result len 1)` sets the length field

#### parse_create_atom

Migrated from `parser_no_vibe.ll`. Key patterns:
- `(llvm:extractvalue normalized 0)` extracts the normalized value pointer
- `(llvm:extractvalue normalized 1)` extracts the normalized length
- Uses cross-label value visibility (values from entry block accessible in `free_normalized` and `store_copied` labels)

Also added `free` and `memcpy` FFI declarations to parser.vibe (previously only `malloc` was declared).

### 4. Cleanup

- Deleted `bootstrap/parser/parser_no_vibe.ll` (no longer needed)
- Updated `CMakeLists.txt` to remove all `parser_no_vibe` references
- Simplified parser KERNEL/SELF_HOST build to mirror the lexer pattern (just compile `.vibe` + link with types)

### 5. Sync Strategy Documentation

Added "Bootstrap/Kernel Sync Strategy" section to AGENTS.md documenting:
- Current migration status for each module
- Six sync rules governing how bootstrap and kernel files coexist
- Guidance on when sync is needed
- Acceptance of debug logging divergence between bootstrap and kernel

Updated the "Synchronizing `*_no_vibe.ll` Files" section to reflect that lexer and parser are now fully migrated with no `*_no_vibe.ll` files remaining.

## Key Decisions

### Named Type for Aggregate Return

Used `%NormalizeResult` named struct instead of anonymous `{ i8*, i64 }` to work with the existing type resolution system. This is cleaner and aligns with Vibe's philosophy of named, documented types.

### Debug Logging Strategy

Decided to keep debug logging in bootstrap `.ll` files while keeping kernel `.vibe` files silent. Rationale:
- `codegen.ll` (where most logging lives, 639+ printf calls) is shared by all modes
- Only `lexer.ll`/`parser.ll` vs their `.vibe` counterparts need manual sync
- The divergence is manageable and the logging is valuable for debugging

### Forward Declarations for Migrated Functions

Kept the `(llvm:declare-function (parse_create_atom ...))` forward declaration in parser.vibe since `parse_atom` (defined earlier) references it. The LLVM C API handles this correctly -- `LLVMAddFunction` returns the existing declaration when the function is later defined.

## Technical Challenges

1. **Aggregate type resolution**: The `llvm:undef` handler needs to resolve a type string like `%NormalizeResult` via `codegen_resolve_type_string`. This works because the type is defined earlier in the file via `llvm:define-type`.

2. **Index parsing for insertvalue/extractvalue**: The index argument (e.g., `0`, `1`) is parsed as a TOKEN_NUMBER atom by `codegen_parse_int_from_ast`, which handles the string-to-integer conversion.

3. **Cross-label value visibility**: `parse_create_atom` defines values in the entry block that are used in `free_normalized` and `store_copied` label blocks. The codegen's persistent local value map makes this possible.

## Files Modified

- **Modified**: `bootstrap/runtime/ffi.ll` -- added 3 LLVM C API declarations and 3 wrapper functions
- **Modified**: `bootstrap/compiler/codegen.ll` -- added 3 FFI declarations, 3 string constants, 3 dispatch entries, 3 handler functions
- **Modified**: `bootstrap/parser/parser.vibe` -- added NormalizeResult type, free/memcpy FFI declarations, migrated 2 functions, updated comments
- **Deleted**: `bootstrap/parser/parser_no_vibe.ll` -- no longer needed
- **Modified**: `CMakeLists.txt` -- removed parser_no_vibe references, simplified parser build
- **Modified**: `AGENTS.md` -- added sync strategy, updated build mode descriptions
- **Created**: `docs/chats/0025-complete-parser-migration-and-sync-strategy.md`

## Build Verification

All three build modes verified:
- `./build.sh bootstrap` -- success (uses `parser.ll` with all functions)
- `./build.sh build_kernel` -- success (uses `parser.vibe` with all functions)
- `./build.sh build` -- success (self-hosted compilation of `parser.vibe`)

Note: The test infrastructure has a pre-existing linking issue (cc defaults to x86_64 on this arm64 machine), but compilation of test programs succeeds.

## Migration Status

With this work, the parser is **fully migrated** to Vibe DSL. Current module status:
- **Lexer**: Fully migrated (`lexer.vibe` complete, no `_no_vibe.ll`)
- **Parser**: Fully migrated (`parser.vibe` complete, no `_no_vibe.ll`)
- **Codegen**: Not yet migrated (shared `codegen.ll` used by all modes)
- **FFI**: Not yet migrated (shared `ffi.ll`)
- **Runtime**: Not yet migrated (shared `runtime.ll`)
- **Main**: Not yet migrated (shared `main.ll`)

## Future Work

- Begin migrating codegen functions to `codegen.vibe` (this will be the most complex migration due to the 9000+ line file and extensive debug logging)
- Implement `define-bitcode-ffi-function` for user-defined FFI declarations
- Fix the test infrastructure's architecture mismatch issue
- Consider implementing anonymous struct type support in `codegen_resolve_type_string` for more general aggregate operations
