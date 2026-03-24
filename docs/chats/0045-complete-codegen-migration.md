# Chat 0045: Complete Codegen Migration - Remove codegen_no_vibe.ll

**Date**: 2026-03-17  
**Model**: Claude Opus 4.6 (Claude Code)  

## Overview

Completed the final codegen migration: all remaining functions moved from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe`, and `codegen_no_vibe.ll` deleted from the repository and build system. The Vibe compiler's code generator is now 100% self-hosted in Vibe DSL.

## Functions Migrated This Session

### 1. codegen_define_llvm_function (~270 lines IR → Vibe)
- **Phi nodes**: 3 → 11 allocas
- **Bug fix**: `.str.entry_block_name` was defined AFTER the function, causing `llvm:get-global` to return null. Moved the constant before the function definition.
- **Root cause pattern**: Bootstrap compiler forward-reference bug — globals defined later in `codegen.vibe` are invisible to `llvm:get-global` at compile time.

### 2. codegen_resolve_type_string (~285 lines IR → Vibe)
- **Phi nodes**: 2 (`name_len`, `is_pointer_flag`) → allocas + stores from predecessor blocks
- **Cross-label values**: Added `base_type_ptr` and `resolved_type_ptr` allocas to pass values computed in one label to successor labels (replacing SSA values that flowed across basic blocks in the original IR).
- **Array parsing**: Translated iterative `[N x i8]` parser with alloca-based loop state directly.

### 3. codegen_eval_dsl_expr (~690 lines IR → Vibe)
- **Phi nodes**: 0 — no phi elimination needed
- **Structure**: Entry dispatch (quote/atom/list) + atom resolution chain (local → function → param → constant) + ~25 primitive dispatch table
- **Debug printf**: All stripped (~40% of original function was debug logging)
- **String constants**: 33 new `llvm:define-constant` entries for DSL primitive names and `let*`
- **Forward declarations added**: `codegen_eval_let_star`, `codegen_dsl_call`, `codegen_dsl_gep`, `codegen_get_constant`

### Also migrated (from previous conversation, fixed this session)
- **codegen_get_or_create_label**: 1 alloca replacing 1 phi
- **codegen_build_param_names**: 4 allocas replacing 1 phi; required forward declaration of `codegen_create_int_node`

## codegen_no_vibe.ll Removal

After all functions were migrated, `codegen_no_vibe.ll` contained only:
- Type definitions (duplicated from `types.ll`)
- `declare` statements (satisfied by `codegen.vibe` output)
- Dead `private` string constants (debug logging)

**CMakeLists.txt changes**: Removed the `llvm-as` step for `codegen_no_vibe.ll` and the `llvm-link` of its bitcode. The kernel now links `codegen_vibe_temp.bc` directly with `bootstrap_types.bc`.

## Key Bugs Found and Fixed

### Forward-reference null pattern (recurring)
When `llvm:get-global` references a constant defined LATER in `codegen.vibe`, it returns null. This null propagates through `let*` bindings and causes either silent call dropping (via `codegen_dsl_call`'s null argument validation) or segfaults (when uninitialized allocas are read).

**Fix**: Move constants before the functions that reference them, or add forward declarations for functions.

### codegen_build_param_names returning null
`codegen_create_int_node` was defined at line 4546, after `codegen_build_param_names` at line 3962. The bootstrap compiler couldn't find it, so all dependent calls were silently dropped.

**Fix**: Added `(llvm:declare-function (codegen_create_int_node ...))` forward declaration.

## Build Validation

All stages pass without `codegen_no_vibe.ll`:
```
./build.sh clean && ./build.sh bootstrap && ./build.sh build_kernel && ./build.sh build && ./build.sh test
```

## Files Changed

| File | Change |
|------|--------|
| `kernel/codegen.vibe` | +2221 lines: 5 migrated functions, 33 string constants, 4 forward declarations |
| `bootstrap/codegen_no_vibe.ll` | **Deleted** (was 3209 lines) |
| `CMakeLists.txt` | Removed codegen_no_vibe assembly/linking steps |
| `bootstrap/codegen.ll` | Minor adjustments from previous session carry-over |

## Migration Statistics

- **Total functions in codegen.vibe**: ~100+ (all codegen functions)
- **Functions migrated this session**: 5
- **codegen_no_vibe.ll**: 0 functions remaining → file deleted
- **Net line change**: -1022 lines (3243 deleted, 2221 added)
