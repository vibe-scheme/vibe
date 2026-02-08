# Chat 0024: Parser Partial Migration to Vibe DSL

**Date**: 2026-02-08
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)

## Overview

Partially migrated `bootstrap/parser/parser.ll` to Vibe DSL, following the same pattern established by the lexer migration. The parser was split into `parser.vibe` (9 migrated functions) and `parser_no_vibe.ll` (2 un-migrated functions). All 8 debug functions and their string constants were removed.

## Work Completed

### 1. Analysis and Planning

- Cataloged all 19 functions in `parser.ll`, identifying which LLVM DSL methods each requires
- Determined that 9 functions use only existing DSL methods and can be migrated immediately
- Identified 2 functions (`parse_normalize_type_atom`, `parse_create_atom`) as blocked due to missing `llvm:insertvalue`, `llvm:extractvalue`, and `llvm:undef` DSL methods
- Identified 8 `parse_debug_*` functions for removal (will be re-added when the kernel builds the full compiler)

### 2. Created `bootstrap/parser/parser.vibe`

New Vibe DSL file containing:

- **FFI declarations**: `malloc` via `llvm:define-ffi-function`
- **Type definitions**: `Token`, `Lexer`, `ASTNode`, `Parser` via `llvm:define-type`
- **External declarations**: `lex_next`, `parse_create_atom`, `parse_expr` via `llvm:declare-function`
- **9 function definitions**:
  - `parse_init` -- allocate Parser, store lexer, get first token
  - `parse_advance` -- load lexer, call lex_next, store new token
  - `parse_current` -- load token pointer from parser
  - `parse_check` -- compare current token type
  - `parse_error` -- return null (stub)
  - `parse_atom` -- create atom from current token, advance
  - `parse_list_tail` -- recursive list builder
  - `parse_list` -- parse `(` elements `)` with dot notation support
  - `parse_expr` -- dispatch: quote / list / atom

### 3. Created `bootstrap/parser/parser_no_vibe.ll`

Minimal LLVM IR file containing only:
- Type forward declarations: `%Token`, `%ASTNode`
- External declarations: `malloc`, `free`, `llvm.memcpy.p0i8.p0i8.i64`
- `parse_normalize_type_atom` -- unchanged from `parser.ll`
- `parse_create_atom` -- unchanged from `parser.ll`
- No debug strings, no debug functions

### 4. Updated `CMakeLists.txt`

Updated the "Bootstrap Parser" section to mirror the lexer's conditional build pattern:
- **BOOTSTRAP mode**: unchanged (assemble `parser.ll`, link with types)
- **KERNEL mode**: compile `parser.vibe` via `bootstrap_compiler` to `.ll` then `.bc`; assemble `parser_no_vibe.ll` to `.bc`; link types + both `.bc` files
- **SELF_HOST mode**: same but compile `parser.vibe` via `vibe_kernel`

## Key Decisions

### Self-Referential Type Workaround

The `ASTNode` type contains self-referential fields (`car` and `cdr` are `%ASTNode*`). The codegen's `codegen_define_llvm_type` resolves field types before storing the type in the type map, so `%ASTNode*` can't be resolved during type definition. Since LLVM 21 uses opaque pointers (`%ASTNode*` and `i8*` are both just `ptr`), we used `|i8*|` for these fields as a workaround:

```scheme
(llvm:define-type ASTNode
  ...
  (car |i8*|)   ; would be |%ASTNode*| but codegen can't resolve self-referential types
  (cdr |i8*|)   ; same workaround
  ...)
```

This produces correct IR and is semantically equivalent in opaque pointer mode.

### Cross-Label Value Visibility

The Vibe DSL codegen stores local values in a list that persists across label blocks within a function (no unbinding on label exit). This means values bound in one label block are accessible in subsequent label blocks, similar to LLVM SSA domination. This pattern was essential for `parse_list` where `list_node_ptr` is created in `parse_start` and used in multiple downstream labels.

### Debug Functions Removed

All 8 `parse_debug_*` functions and their associated string constants were removed from the migrated files. They remain in `parser.ll` for the BOOTSTRAP build but are not included in `parser_no_vibe.ll`. Debug functionality will be re-added when the kernel compiler builds Vibe's full compiler.

## Technical Challenges

1. **Self-referential type resolution**: Required the `i8*` workaround described above.
2. **Mutual recursion**: `parse_expr`, `parse_list`, and `parse_list_tail` are mutually recursive. Handled via `llvm:declare-function` for forward declaration of `parse_expr`.
3. **Complex control flow**: `parse_list` has 7 basic blocks with branches spanning multiple labels. Structured as flat sibling labels relying on the codegen's persistent local value map.

## Files Modified

- **Created**: `bootstrap/parser/parser.vibe` (new Vibe DSL file with 9 migrated functions)
- **Created**: `bootstrap/parser/parser_no_vibe.ll` (2 un-migrated functions, no debug code)
- **Modified**: `CMakeLists.txt` (conditional parser build for KERNEL/SELF_HOST modes)
- **Unchanged**: `bootstrap/parser/parser.ll` (kept for BOOTSTRAP mode)

## Build Verification

All three build modes verified:
- `./build.sh bootstrap` -- success (uses `parser.ll`)
- `./build.sh build_kernel` -- success (uses `parser.vibe` + `parser_no_vibe.ll`)
- `./build.sh build` -- success (self-hosted compilation of `parser.vibe`)

## Future Work

- Implement `llvm:insertvalue`, `llvm:extractvalue`, and `llvm:undef` DSL methods to migrate `parse_normalize_type_atom` and `parse_create_atom` from `parser_no_vibe.ll` to `parser.vibe`
- Fix `codegen_define_llvm_type` to support self-referential types (create named struct and store in type map before resolving field types)
- Re-add debug/logging functionality when the kernel compiler builds the full compiler
