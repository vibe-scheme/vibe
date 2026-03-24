# Chat 0035: Codegen Migration Phase 1 and Phase 2

**Date**: 2026-03-12  
**Model**: Cursor Composer 1.5  
**Context**: Implementing the Codegen Migration Completion Plan to finish migrating functions from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe` using correct `let*` scoping (labels inside `let*` body).

## Overview

This session completed Phase 1 (Tier 2 deferred functions) and Phase 2 (simple DSL functions) of the migration plan. Five functions were successfully migrated:

1. **codegen_define_llvm_type** — Tier 2, re-attempted with correct scope
2. **codegen_define_llvm_constant** — Tier 2, re-attempted with correct scope
3. **codegen_dsl_ret_void** — Phase 2, simple DSL builder
4. **codegen_dsl_const_null** — Phase 2, simple DSL builder
5. **codegen_dsl_undef** — Phase 2, simple DSL builder

## Phase 1: Tier 2 Deferred Functions

### codegen_define_llvm_type

**Challenge**: Initial migration failed with "No predecessors!" for create_struct block. Root cause: bootstrap compiler dropped the `br` from collect_fields when using `alloca [64 x i8*]` for types_array.

**Solution**: Use `malloc(512)` for the types array instead of alloca. Store pointer in `types_array_ptr` alloca, pass to `codegen_collect_field_types`, load in set_struct_body, free in both success and error paths. Added `free_and_error` label for error path when field_count is zero.

**Structure**: `let*` with field_count_ptr, name_buf_ptr, named_struct_type_ptr, types_array_ptr. Labels inside: entry, collect_fields, free_and_error, create_struct, free_name_buf_error, set_struct_body, error.

**New constant**: `.str.newline` added to codegen.vibe. Changed to `external constant` in codegen_no_vibe.ll.

### codegen_define_llvm_constant

**Structure**: `let*` with constant_type_ref_ptr, const_str_value_ptr, global_const_ptr. Labels inside: entry, check_bytevector, format_bytevector, create_constant_direct, create_string_constant, create_const_str, create_global, set_initializer, text_only_constant, not_bytevector.

**New constants**: `.str.at_sign`, `.str.constant_equals`, `.str.space`, `.str.c_quote_open`, `.str.quote` added to codegen.vibe. Changed to `external constant` in codegen_no_vibe.ll.

**Fix**: Extra closing paren for not_bytevector block — `(llvm:ret ...)))))` was missing one `)` for outer let*.

## Phase 2: Simple DSL Functions

### codegen_dsl_ret_void

**Structure**: Uses `ret_result_ptr` alloca to pass ret_result from build_ret to success block. Labels: entry, get_current_function, build_ret, success, error.

### codegen_dsl_const_null

**Structure**: Single let* with labels inside. Entry branches on args_null; get_type_null extracts type and calls codegen_resolve_type_string; create_null calls llvm_create_constant_null.

### codegen_dsl_undef

**Structure**: Similar to const_null. Entry branches on args_null; extract_type checks type_node; get_type_string resolves type; build_undef calls llvm_get_undef.

**Forward declarations**: Added llvm_build_ret_void, llvm_create_constant_null, llvm_get_undef (defined in dsl.vibe, linked at build time).

## Key Decisions

1. **malloc for types array**: Avoid bootstrap alloca issues with array types by using malloc. Ensures proper cleanup in both success and error paths.

2. **Phase 3 cancelled**: Phase 3 (medium complexity) was deferred. The plan's core goal (Phase 1 Tier 2 migration) was achieved. Phase 2 added 3 more functions as proof of the pattern.

3. **Scope pattern verified**: All migrations use labels inside `let*` body for cross-block variable access. No "Global not found" or "No predecessors" errors when structure is correct.

## Files Modified

- `kernel/codegen.vibe` — Added codegen_define_llvm_type, codegen_define_llvm_constant, codegen_dsl_ret_void, codegen_dsl_const_null, codegen_dsl_undef; added string constants; added forward declarations
- `bootstrap/codegen_no_vibe.ll` — Replaced 5 function definitions with `declare`; changed .str.newline, .str.at_sign, .str.constant_equals, .str.space, .str.c_quote_open, .str.quote to external constant
- `AGENTS.md` — Updated migration count (40 functions), Tier 2 and Phase 2 status

## Migration Status

- **40 functions** migrated in codegen.vibe
- **~47 functions** remain in codegen_no_vibe.ll
- **Kernel build**: Succeeds
- **Self-host build**: May fail (pre-existing .str.percent type mismatch when linking)

## Related

- Chat 0034 (SSA Cross-Block Resolution) — Established correct let* scope pattern
- Chat 0033 (Full Codegen Migration) — Tier 2 initial attempt, deferred
- Codegen Migration Completion Plan (`.cursor/plans/`)
