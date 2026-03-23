# Chat 0033: DSL Deferred Methods Doc and Full Codegen Migration

**Date**: 2026-03-11
**Model**: Cursor Composer 1.5

## Overview

This session implemented Part 1 of the plan (DSL Deferred Methods document) and began Part 2 (Full Codegen Migration). Tier 1 migration (codegen_init, codegen_dispose) completed successfully. Tier 2 migration was attempted but reverted due to bootstrap compiler limitations.

## Work Completed

### Part 1: DSL Deferred Methods Document

Created `docs/design/llvm-dsl-deferred-methods.md` documenting 8 LLVM instructions that could be exposed as DSL primitives but are not currently implemented:

| Method | LLVM API | Why Not Implemented | Future Use Case |
|--------|----------|---------------------|-----------------|
| `llvm:xor` | LLVMBuildXor | Boolean negation via icmp | Cleaner boolean flip |
| `llvm:inttoptr` | LLVMBuildIntToPtr | Not used | Integer-to-pointer casts |
| `llvm:sext` | LLVMBuildSExt | zext suffices | Sign-extending integers |
| `llvm:sdiv` | LLVMBuildSDiv | udiv/urem cover needs | Signed division |
| `llvm:srem` | LLVMBuildSRem | udiv/urem cover needs | Signed remainder |
| `llvm:shl` | LLVMBuildShl | Not used | Shift left |
| `llvm:ashr` | LLVMBuildAShr | Not used | Arithmetic shift right |
| `llvm:lshr` | LLVMBuildLShr | Not used | Logical shift right |

Implementation pattern: When adding, follow Batch 1 pattern—add to bootstrap/dsl.ll, kernel/dsl.vibe, and bootstrap/codegen.ll dispatch + handler.

### Part 2: Tier 1 Migration (Complete)

**codegen_init** and **codegen_dispose** migrated from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe`:

- Added string constants: `.str.module_name`, `.str.target_triple_value`, `.str.data_layout_value`, `.str.target_triple` via `llvm:define-constant`
- Implemented `codegen_init` in Vibe DSL (init flow, error handling, dispose_context on error)
- Implemented `codegen_dispose` in Vibe DSL (reloading context/module/builder from CodeGen in each block)
- Replaced definitions in `codegen_no_vibe.ll` with `declare` stubs
- Changed string constant definitions in `codegen_no_vibe.ll` to `external constant` (provided by codegen.vibe at link time)

**Verification**: `./build.sh bootstrap`, `./build.sh build_kernel`, and `./build.sh` (self-host) all succeed.

### Part 2: Tier 2 Migration (Deferred)

Tier 2 migration was attempted for: `codegen_resolve_type_string`, `codegen_collect_field_types`, `codegen_define_llvm_type`, `codegen_append_type_fields`, `codegen_define_llvm_constant`.

**Issues encountered**:
1. **Parse error**: "unexpected ) (too many closing parens)" in `codegen_resolve_type_string`—fixed by adjusting nesting in `check_element_type` block
2. **Bootstrap compiler limitation**: "ERROR: Global not found!" when codegen tried to resolve symbols like `num_result`, `context_ptr`—local allocas/SSA values from entry block used in later blocks. The bootstrap compiler's DSL expression evaluator appears to treat these as globals.
3. **Complex control flow**: `codegen_resolve_type_string` has ~400 lines with many blocks, phi nodes, and cross-block variable flow

**Resolution**: Reverted Tier 2 migration. Restored full implementations in `codegen_no_vibe.ll` (from `codegen.ll`). Removed Tier 2 code from `codegen.vibe`. Kernel build succeeds.

## Key Decisions

1. **Tier 2 deferral**: The bootstrap compiler cannot yet handle complex DSL code with SSA values flowing across blocks. Migration of Tier 2+ may require bootstrap compiler improvements (e.g., proper local/SSA symbol resolution in codegen_eval_dsl_expr).

2. **String constants for Tier 1**: Moved `.str.module_name`, `.str.target_triple_value`, `.str.data_layout_value`, `.str.target_triple` to codegen.vibe. These are referenced by both codegen_init (in .vibe) and other functions in codegen_no_vibe.ll. Using `external constant` in .ll allows linker to resolve from .vibe output.

3. **Debug logging**: Per AGENTS.md, omit printf in kernel/codegen.vibe. Bootstrap .ll retains debug logging.

## Files Modified

- `docs/design/llvm-dsl-deferred-methods.md` – Created
- `kernel/codegen.vibe` – codegen_init, codegen_dispose; string constants; Tier 2 reverted
- `bootstrap/codegen_no_vibe.ll` – codegen_init/codegen_dispose → declare; external constants; Tier 2 defs restored

## Migration Status (AGENTS.md)

- **Tier 1**: codegen_init, codegen_dispose – **migrated**
- **Tier 2**: codegen_resolve_type_string, codegen_collect_field_types, codegen_define_llvm_type, codegen_append_type_fields, codegen_define_llvm_constant – **deferred** (bootstrap compiler limitation)
- **Tiers 3–9**: Not attempted

## Next Steps

1. Investigate bootstrap compiler's "Global not found" when resolving local/SSA symbols in DSL expressions
2. Consider simplifying codegen_resolve_type_string (e.g., split into helper functions) to reduce cross-block variable flow
3. Resume Tier 2 migration once bootstrap compiler supports the required constructs
