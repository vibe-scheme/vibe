# Chat 0042: Self-Host Parameter Resolution Fix

**Date**: 2026-03-14  
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)  

## Context

After migrating 8 functions from `codegen_no_vibe.ll` to `codegen.vibe`, self-hosting broke again. The kernel compiler (`vibe_kernel`) produced broken IR when compiling `codegen.vibe`: the output for `codegen_dispose` and other functions was missing content, basic blocks lacked terminators, and `llvm-as` reported "No predecessors!" errors.

## Work Completed

### Phase 1: Revert and Verify

Reverted all 8 migrated functions back to their full `define` forms in `codegen_no_vibe.ll` (restored from commit `3e37a8d`) and replaced their `llvm:define-function` forms in `codegen.vibe` with `llvm:declare-function`. Verified that bootstrap, kernel, and self-host builds all pass after revert.

The 8 functions reverted:
1. `codegen_build_param_names`
2. `codegen_dsl_resolve_param`
3. `codegen_dsl_resolve_local`
4. `codegen_dsl_bind_local`
5. `codegen_collect_param_types`
6. `codegen_dsl_get_function`
7. `codegen_append_typed_params`
8. `codegen_write_typed_params_to_buffer`

### Phase 2: Add Diagnostic Logging

Added a `[WARN] Unresolved atom` warning in `codegen_eval_dsl_expr` at the `constant_not_found` label in `codegen_no_vibe.ll`. This diagnostic proved critical for identifying the scope of the breakage during re-migration testing.

Also added debug logging around the `codegen_build_param_names` call site in `codegen_define_llvm_function` to check its input (`params_list`) and output (`param_names_list`).

### Phase 3: Incremental Re-migration

Re-migrated functions one at a time (least-critical first), testing self-host after each:

**Group A (migrated successfully together):**
- `codegen_append_typed_params`
- `codegen_write_typed_params_to_buffer`
- `codegen_dsl_get_function`
- `codegen_collect_param_types`

**Group B (migrated successfully one at a time):**
- `codegen_dsl_bind_local`
- `codegen_dsl_resolve_local`
- `codegen_dsl_resolve_param`

**Identified breaking function:**
- `codegen_build_param_names` — self-hosting immediately failed when this function was migrated to Vibe

### Phase 4: Deep Investigation and Deferral

Investigated `codegen_build_param_names` by comparing IR output from `bootstrap_compiler` vs `vibe_kernel`:

- **Bootstrap compiler**: Produces correct IR for `codegen_build_param_names` that properly accesses the `params` parameter
- **Kernel compiler**: When self-compiling, drops critical instructions that access the `params` parameter (`%2`), including `icmp eq ptr %2, null` and `store ptr %2, ptr %4`. This causes `codegen_build_param_names` to always return null.

82 instances of `[CODEGEN] ERROR: param_names list is null!` appeared during the broken self-host, plus 1912 `[WARN] Unresolved atom` messages downstream — confirming that a null `param_names` list broke all parameter resolution.

**Root cause**: Unknown. The bootstrap compiler generates correct IR from the Vibe DSL, but the kernel compiler fails to generate the same correct IR when self-compiling. Despite the Vibe source looking correct, there's a runtime issue in the kernel compiler's code generation for this specific function.

**Decision**: Deferred migration per the chat 0040 strategy. The function remains as `define` in `codegen_no_vibe.ll` and `declare-function` in `codegen.vibe` with an explanatory comment.

## Key Decisions

1. **Systematic approach works**: The 4-phase plan (revert, diagnose, incremental re-migrate, fix-or-defer) successfully isolated the breaking function from a pool of 8 candidates.
2. **7 of 8 functions migrated successfully**: Only `codegen_build_param_names` has the self-hosting issue.
3. **Deferred rather than forced**: Following the chat 0040 strategy, deferring complex migrations is the right approach when the root cause involves kernel compiler self-compilation bugs.

## Technical Details

### The Self-Compilation Bug Pattern

The `codegen_build_param_names` bug follows a pattern where:
1. The Vibe DSL source is correct
2. The bootstrap compiler generates correct IR from it
3. The kernel compiler *also* generates correct IR when compiling other functions
4. But the kernel compiler fails to generate correct IR for `codegen_build_param_names` *when self-compiling*
5. The broken self-compiled version then causes cascading failures

This suggests a subtle interaction between the function's structure (complex alloca/store/load pattern across many label blocks with the `params` parameter) and the kernel compiler's code generation.

## Files Modified

- `bootstrap/codegen_no_vibe.ll`: Restored 7 function definitions to `declare` (migrated to Vibe); kept `codegen_build_param_names` as full `define` (deferred); added diagnostic string constants and logging
- `kernel/codegen.vibe`: Restored 7 functions as `llvm:define-function`; kept `codegen_build_param_names` as `llvm:declare-function` with DEFERRED comment; removed orphaned function body

## Migration Status After This Session

- **81 functions** migrated to `kernel/codegen.vibe`
- **22 functions** remaining in `bootstrap/codegen_no_vibe.ll`
- **Deferred functions**: `codegen_build_param_names` (this session), `codegen_get_llvm_function`, `codegen_get_or_create_label` (from chat 0040)

## Related Documents

- Chat 0040: Codegen migration phases and deferral strategy
- Chat 0041: Previous self-host bug investigation
- `AGENTS.md`: Updated migration counts
