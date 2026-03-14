# Chat 0040: Codegen Migration Phase 1-3 (Partial)

**Date**: 2026-03-14
**Model**: Cursor Composer 1.5
**Context**: Implementing the Codegen Migration Plan (codegen_no_vibe.ll to codegen.vibe)

## Session Overview

This session continued the codegen migration per the plan in `.cursor/plans/Codegen Migration Plan-3d4f16e4.plan.md`. Work included fixing orphaned IR, deferring problematic migrations, and successfully migrating several Phase 1 and Phase 3 functions.

## Work Completed

### 1. Fixed Orphaned IR in codegen_no_vibe.ll

When `codegen_get_llvm_function` was previously migrated, the replacement left ~80 lines of orphaned LLVM IR (the old function body) between the new `declare` and the next valid function. This caused build failures. Removed the orphaned block.

### 2. Phase 1: Deferred Migrations

**codegen_get_llvm_function**: Reverted from codegen.vibe to codegen_no_vibe.ll. The Vibe implementation's complex let*/label structure caused a segfault when the bootstrap compiler processed codegen.vibe ("Storing constant: name=pair"). Restored a simplified define in codegen_no_vibe.ll (without debug printf).

**codegen_get_or_create_label**: Attempted migration using alloca/store/load instead of phi (per AGENTS.md). Caused segfault during kernel build ("Storing constant: name=first_block"). Reverted to codegen_no_vibe.ll.

### 3. Phase 3: Successfully Migrated Functions

**codegen_write_ir_text**: Migrated to codegen.vibe. Writes module IR text to file via `llvm_print_module_to_file`. Simple structure: entry → get_module → write → success/error.

**codegen_write_bitcode**: Migrated to codegen.vibe. Writes bitcode via `llvm_verify_module` + `llvm_write_bitcode_to_file`. Same simple structure.

**codegen_append_params**: Migrated to codegen.vibe. Recursive function that appends parameter list (i8* %name format) to function signature. Added `.str.i8_ptr` constant. Uses existing `.str.space`, `.str.percent`, `.str.comma_space`.

### 4. Declarations Added

- `llvm_print_module_to_file`, `llvm_verify_module`, `llvm_write_bitcode_to_file` (for write functions)
- `codegen_append_params` (forward declare for recursion)

## Key Decisions

1. **Defer complex migrations**: Functions with many nested let*/label blocks trigger segfaults in the bootstrap compiler's codegen_dsl_bind_local path. Defer these until the bootstrap compiler is more robust.

2. **Simple structures succeed**: Functions with straightforward control flow (few labels, minimal nesting) migrate successfully.

3. **String constants**: Added `.str.i8_ptr` for codegen_append_params. Other Phase 3 text functions will need similar constants.

## Build Status

- `./build.sh bootstrap`: Success
- `./build.sh build_kernel`: Success
- `./build.sh build`: Success

## Migration Status Summary

| Phase | Migrated | Deferred | Remaining |
|-------|----------|----------|-----------|
| 1     | 6        | 2        | 0         |
| 2     | 0        | 0        | 5         |
| 3     | 3        | 0        | 7         |

**Phase 1 migrated**: debug_log_string, codegen_dsl_ret, codegen_dsl_get_global, codegen_dsl_get_param, codegen_get_function_type_by_value, (codegen_dsl_get_function was in plan but not in Phase 1 list - verify)

**Phase 1 deferred**: codegen_get_llvm_function, codegen_get_or_create_label

**Phase 3 migrated**: codegen_write_ir_text, codegen_write_bitcode, codegen_append_params

## Files Modified

- `bootstrap/codegen_no_vibe.ll`: Removed orphaned IR, restored codegen_get_llvm_function define, restored codegen_get_or_create_label define, replaced codegen_write_ir_text/codegen_write_bitcode/codegen_append_params with declare
- `kernel/codegen.vibe`: Removed codegen_get_llvm_function, removed codegen_get_or_create_label attempt, added codegen_write_ir_text, codegen_write_bitcode, codegen_append_params, added .str.i8_ptr constant, added LLVM API declarations

## Related Documentation

- AGENTS.md: Bootstrap/Kernel Sync Strategy, cross-block values (alloca/store/load)
- doc/chats/0039: Forward declarations, migration notes
- .cursor/plans/Codegen Migration Plan-3d4f16e4.plan.md: Full migration plan
