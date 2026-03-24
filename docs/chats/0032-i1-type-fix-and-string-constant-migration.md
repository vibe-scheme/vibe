# Chat 0032: i1 Type Fix and String Constant Migration

**Date**: 2026-03-10  
**Model**: Cursor Composer 1.5  

## Overview

This session resolved the let* + store + br bug by fixing the root cause (missing `i1` type support), then completed the deferred migration of `codegen_define_string_constant_only` and `codegen_string_literal` from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe`.

## Work Completed

### 1. Root Cause: i1 Type Support

**Problem**: `codegen_resolve_type_string` did not support the `i1` (1-bit integer) type. When `test_cond_br_in_let` used `(llvm:alloca |i1|)` and `(llvm:const-int |i1| 1)` in let* bindings, type resolution failed, causing "value eval FAILED" for bindings `x` and `cond`. Those bindings were never stored, so `(llvm:br cond 'then 'else)` could not resolve `cond` and returned null—the br was never emitted.

**Fix**:
- Added `i1` support in `codegen_resolve_type_string` in both `bootstrap/codegen.ll` and `bootstrap/codegen_no_vibe.ll`
- Added `llvm_get_int1_type` in `bootstrap/dsl.ll` and `kernel/dsl.vibe`

### 2. Migrated Functions (2 total)

**codegen_define_string_constant_only**:
- Increments string counter, formats name, loads context/module
- Branches on `can_use_llvm` (context and module non-null)
- **create_llvm_constant**: Builds i8 array type, constant string, global, sets initializer/constant/linkage. Context and module are reloaded inside this block because they are not in scope across blocks.
- **text_only**: Calls `codegen_append_string_constant`, returns name

**codegen_string_literal**:
- Implemented as a wrapper that calls `codegen_define_string_constant_only`

### 3. codegen_no_vibe.ll Updates

Replaced the full `define` bodies for both functions with `declare` stubs.

### 4. Documentation Updates

- **AGENTS.md**: Updated migration counts—Batch 3: 12 functions, 33 total migrated (from 10 and 31)
- **let-star-store-br-bug-resolution-plan.md**: Phase 4 marked complete; status set to Resolved (2026-03-11)

## Key Decisions

1. **Fix at source**: The let* store+br bug was not in body iteration or br emission—it was in type resolution. Adding `i1` support fixed the underlying cause.
2. **Context/module reload**: In `codegen_define_string_constant_only`, context and module are reloaded inside the `create_llvm_constant` block because they are not in scope across SSA blocks.

## Files Modified

| File | Changes |
|------|---------|
| `bootstrap/codegen.ll` | +i1 type support in codegen_resolve_type_string |
| `bootstrap/codegen_no_vibe.ll` | +i1 type support, 2 define→declare |
| `bootstrap/dsl.ll` | +llvm_get_int1_type |
| `kernel/dsl.vibe` | +llvm_get_int1_type |
| `kernel/codegen.vibe` | +codegen_define_string_constant_only, +codegen_string_literal |
| `AGENTS.md` | Migration count: 33 functions (Batch 3: 12) |
| `docs/design/let-star-store-br-bug-resolution-plan.md` | Phase 4 complete, status Resolved |

## Verification

- `./build.sh build_kernel` ✓
- `./build.sh` (self-host) ✓

## Related

- Chat 0031 (Codegen Batch 3 Migration) – deferred these two functions
- Plan: `docs/design/let-star-store-br-bug-resolution-plan.md`
