# Chat 0026: Runtime Removal, FFI Migration to Vibe, and Source Tree Reorganization

**Date**: 2026-02-08
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)

## Overview

This session completed three major tasks: removing dead runtime code, migrating the FFI/DSL layer from LLVM IR to Vibe, and reorganizing the source tree for clarity. This is the last step before tackling the codegen migration.

## Work Completed

### 1. Removed `runtime.ll` Entirely

Analysis from the previous conversation confirmed that `bootstrap/runtime/runtime.ll` was entirely dead code. The `runtime_init` function was called from `main.ll` but its return value (`%Runtime*`) was never used anywhere.

**Changes:**
- Deleted `bootstrap/runtime/runtime.ll` (387 lines, ~13.5KB)
- Removed `%Runtime`, `%SymbolTable`, `%BitcodeBinding`, `%VibeSymbol` type declarations from `main.ll`
- Removed `declare %Runtime* @runtime_init(i64)` and its call site from `main.ll`
- Removed all `bootstrap_runtime` build targets, linker references, and install entries from `CMakeLists.txt`

### 2. Pruned Dead Code from `ffi.ll`

Removed 7 unused functions and their supporting declarations (~153 lines):
- `ffi_close_library` / `ffi_dlclose` (and `dlclose` declare)
- `ffi_call` (placeholder returning 0)
- `ffi_define_type` (placeholder returning 0)
- `ffi_value_to_int`, `ffi_int_to_value`
- `ffi_value_to_string`, `ffi_string_to_value`
- `ffi_get_error` (and `dlerror` declare)
- FFI type enum comments and `%FFICallSignature` type

### 3. Created `kernel/ffi.vibe`

New Vibe file containing the FFI dynamic library loading functions:
- Declares `dlopen` and `dlsym` via `llvm:define-ffi-function`
- Defines `ffi_load_library` (wraps `dlopen` with RTLD_LAZY=1)
- Defines `ffi_get_symbol` (wraps `dlsym` directly)

### 4. Created `kernel/dsl.vibe`

Large new Vibe file (~521 lines) containing all LLVM C API wrappers and target initialization:
- ~60 LLVM C API external declarations via `llvm:declare-function`
- `strncmp` and `free` declared via `llvm:define-ffi-function`
- String constants for target triple comparison (`.str.arm64`, `.str.aarch64`)
- Target init functions: `is_arm64_target`, `llvm_initialize_native_target`, `llvm_ffi_init`
- ~45 `llvm_*` wrapper functions as thin pass-throughs to the LLVM C API

### 5. Updated CMakeLists.txt for Conditional FFI Build

Added conditional build logic for the FFI module:
- **BOOTSTRAP mode**: Uses `ffi.ll` as before
- **KERNEL mode**: Compiles `ffi.vibe` and `dsl.vibe` with bootstrap_compiler, converts via llvm-as, links with types
- **SELF_HOST mode**: Compiles `ffi.vibe` and `dsl.vibe` with vibe_kernel

### 6. Reorganized Source Tree

Simplified the directory structure by eliminating unnecessary nesting:

**Before:**
```
bootstrap/
  compiler/codegen.ll, main.ll
  lexer/lexer.ll, lexer.vibe
  parser/parser.ll, parser.vibe
  runtime/ffi.ll, ffi.vibe, dsl.vibe
  types/types.ll
```

**After:**
```
bootstrap/
  types.ll, lexer.ll, parser.ll, ffi.ll, codegen.ll, main.ll
kernel/
  lexer.vibe, parser.vibe, ffi.vibe, dsl.vibe
```

All files were moved with `git mv` to preserve history. Updated all paths in `CMakeLists.txt` and `AGENTS.md`.

## Key Technical Decisions

### `i8**` Type Not Supported by Codegen

The bootstrap codegen's type resolver cannot handle `i8**` (double pointer). When `dsl.vibe` initially used `|i8**|` for parameters like `%LLVMModuleRef*`, the type resolution failed. Since LLVM 21 uses opaque pointers where all pointer types are `ptr`, replacing `|i8**|` with `|i8*|` is semantically equivalent and resolves the issue.

### Error Return Values

The original `ffi.ll` used `-1` for error returns (e.g., in `llvm_parse_ir_in_context`). Since the Vibe DSL's integer parser may not support negative literals, error returns were changed to `1` (non-zero). All callers check `!= 0`, so this is functionally equivalent.

### Unconditional Branch Syntax

Discovered that the Vibe DSL uses `(llvm:br 'label)` for unconditional branches, not `(llvm:br #f 'label 'label)`. Fixed in `llvm_initialize_native_target`.

## Files Modified

- `bootstrap/runtime/runtime.ll` -- deleted
- `bootstrap/main.ll` -- removed runtime type declarations and init call
- `bootstrap/ffi.ll` -- pruned dead functions (was `bootstrap/runtime/ffi.ll`)
- `kernel/ffi.vibe` -- new, FFI dynamic library functions
- `kernel/dsl.vibe` -- new, LLVM C API wrappers and target init
- `CMakeLists.txt` -- removed runtime targets, added conditional FFI build, updated all paths
- `AGENTS.md` -- updated directory structure documentation
- All `.ll` files moved from subdirectories to `bootstrap/`
- All `.vibe` files moved to `kernel/`

## Next Steps

- Migrate `codegen.ll` to Vibe (the last major module)
