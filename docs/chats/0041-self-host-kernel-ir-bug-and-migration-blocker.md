# Chat 0041: Self-Host Kernel IR Bug and Migration Blocker

**Date**: 2026-03-14
**Model**: Cursor Composer 1.5
**Context**: Investigating self-host build failure; adding forward declarations per chat 39; documenting the kernel vs bootstrap codegen divergence bug that blocks further migration.

## Session Overview

This session attempted to fix the self-host build by adding missing forward declarations per the guidance in chat 39. We added 33 forward declarations (32 `codegen_dsl_*` handlers + `codegen_extract_quoted_atom`) and verified that all dependencies for `codegen_dsl_icmp` are correctly declared. Despite this, the self-host build still fails. We identified a **kernel vs bootstrap codegen divergence bug**: the bootstrap compiler produces correct IR when compiling `codegen.vibe`, but the kernel (vibe_kernel) produces broken IR for the same input. This bug blocks further migration of functions from `codegen_no_vibe.ll` to `codegen.vibe`.

## Work Completed

### 1. Forward Declarations Added (per chat 39)

Added to `kernel/codegen.vibe`:

**codegen_dsl_* handlers** (32 functions, called from `codegen_eval_dsl_expr` in `codegen_no_vibe.ll`; defined later in codegen.vibe; must be declared so early functions like `codegen_parse_int_string` can emit calls when their DSL forms are evaluated):

- `codegen_dsl_load`, `codegen_dsl_store`, `codegen_dsl_icmp`, `codegen_dsl_zext`, `codegen_dsl_and`, `codegen_dsl_add`, `codegen_dsl_sub`, `codegen_dsl_mul`, `codegen_dsl_or`, `codegen_dsl_br`, `codegen_dsl_alloca`, `codegen_dsl_label`, `codegen_dsl_phi`, `codegen_dsl_trunc`, `codegen_dsl_select`, `codegen_dsl_const_int`, `codegen_dsl_const_null`, `codegen_dsl_bitcast`, `codegen_dsl_ret_void`, `codegen_dsl_ret`, `codegen_dsl_get_global`, `codegen_dsl_get_function`, `codegen_dsl_get_param`, `codegen_dsl_undef`, `codegen_dsl_insertvalue`, `codegen_dsl_extractvalue`, `codegen_dsl_urem`, `codegen_dsl_udiv`, `codegen_dsl_ptrtoint`, `codegen_dsl_resolve_local`, `codegen_dsl_bind_local`, `codegen_dsl_resolve_param`

**Other forward declarations:**

- `codegen_extract_quoted_atom` (used by `codegen_dsl_icmp`, `codegen_dsl_br`, etc.)
- `codegen_append_typed_params`, `codegen_write_typed_params_to_buffer` (for Batch B migrations)
- `llvm_count_params`

### 2. Verification of codegen_dsl_icmp Dependencies

All forward declarations needed by `codegen_dsl_icmp` were verified present and in correct order:

| Function | Purpose | Declared |
|----------|---------|----------|
| `codegen_extract_quoted_atom` | Extract predicate from quote node | ✓ |
| `codegen_map_predicate_string` | Map predicate string to enum | ✓ |
| `codegen_eval_dsl_expr` | Evaluate lhs/rhs (i_val, len) | ✓ |
| `llvm_build_icmp` | Build icmp instruction | ✓ |
| `codegen_dsl_get_global` | For llvm:get-global .str.empty | ✓ |
| `codegen_dsl_resolve_local` | Resolve "i_val" from let* bindings | ✓ |
| `codegen_dsl_resolve_param` | Resolve "len" from params | ✓ |

## The Bug: Kernel vs Bootstrap Codegen Divergence

### Observed Behavior

- **Bootstrap compiler** (`./build/bin/bootstrap_compiler kernel/codegen.vibe -o /tmp/codegen_bootstrap.ll`): Produces **correct** IR. The `codegen_parse_int_string` function has proper control flow:
  ```llvm
  loop:
    %4 = load i64, ptr %3, align 8
    %5 = icmp uge i64 %4, %1
    br i1 %5, label %return, label %process_char
  process_char:  ; preds = %loop
    ...
  ```

- **Kernel compiler** (`./build/bin/vibe_kernel kernel/codegen.vibe -o /tmp/codegen_kernel.ll`): Produces **broken** IR. The loop block is missing the icmp and conditional branch:
  ```llvm
  loop:
    %4 = load i64, ptr %3, align 8
  process_char:  ; No predecessors!
    ...
  ```

### Error Message

```
/opt/homebrew/Cellar/llvm/22.1.0/bin/llvm-as: bootstrap_codegen_vibe_temp.ll:90:1: error: expected instruction opcode
process_char:                                     ; No predecessors!
^
```

### Root Cause Hypothesis

The kernel's codegen (from `codegen.vibe`, compiled by bootstrap) differs from the bootstrap's codegen (from `codegen.ll`, pure LLVM IR). When the kernel compiles `codegen_parse_int_string`, the following flow occurs:

1. The function body has a `let*` in the `loop` label: `(let* ((i_val (llvm:load ...)) (done (llvm:icmp 'uge i_val len))) (llvm:br done 'return 'process_char))`
2. For the second binding, `codegen_dsl_icmp` is called with args `('uge i_val len)`.
3. `codegen_dsl_icmp` must resolve `i_val` (from let* bindings) and `len` (from params) via `codegen_eval_dsl_expr`.
4. `codegen_eval_dsl_expr` resolves atoms by calling `codegen_dsl_resolve_local` (for locals) then `codegen_dsl_resolve_param` (for params).

**Hypothesis**: If `codegen_dsl_resolve_local` returns null when resolving 'i_val' (e.g., because let* bindings are not in the expected state when processing a label block), then `codegen_dsl_icmp` returns null. The `done` binding is dropped, and the conditional branch is never emitted. The loop block then has no terminator or an incorrect default branch, causing `process_char` to have no predecessors.

**Alternative hypothesis**: The bug may be in `codegen_eval_let_star` (in `codegen_no_vibe.ll`) — when processing bindings inside a label block, the order of adding bindings to locals vs. evaluating the next binding may be wrong, so `i_val` is not yet in the locals when `codegen_dsl_icmp` tries to resolve it.

### Why Forward Declarations Are Not the Fix

The forward declarations in chat 39 fix the case where **compiling** codegen.vibe fails because the compiler cannot find a function to emit a call for. We added declarations for all `codegen_dsl_*` handlers so that when the compiler processes `(llvm:icmp ...)`, it can emit a call to `codegen_dsl_icmp`.

The current bug is different: it occurs at **runtime** when the kernel runs. The kernel's `codegen_dsl_icmp` is called and executes, but it fails to produce correct IR — likely because a runtime lookup (e.g., `codegen_dsl_resolve_local` for 'i_val') returns null. The declarations are correct; the failure is in the runtime behavior of the kernel's codegen.

## Why We Could Not Migrate More Functions

1. **Self-host build fails**: The self-host pipeline (`./build.sh build`) fails at the `llvm-as` step when processing the kernel's output. We cannot verify that migration succeeds when the kernel compiles itself.

2. **Kernel bug blocks verification**: Until the kernel produces correct IR for `codegen.vibe` (matching bootstrap output), we cannot trust that migrated functions work correctly when the kernel compiles itself. Migrating more functions would add more code that the kernel must compile, but the kernel's codegen is already broken for basic control flow.

3. **Deferred migrations remain deferred**: `codegen_get_llvm_function` and `codegen_get_or_create_label` (complex let*/label) remain in `codegen_no_vibe.ll` per chat 0040. These cannot be migrated until the kernel bug is fixed.

4. **Batch B migration incomplete**: `codegen_append_typed_params` and `codegen_write_typed_params_to_buffer` were migrated (per conversation summary). The remaining Batch B functions (`codegen_append_function_def`, `codegen_append_call_args`, `codegen_call`, `codegen_append_top_level_exprs`, `codegen_main`) should not be migrated until the kernel produces correct IR.

## Recommended Next Steps

1. **Debug the kernel's codegen_dsl_resolve_local path**: Add logging or assertions to trace when `codegen_dsl_resolve_local` is called for 'i_val' during `codegen_parse_int_string` compilation, and whether it returns null. Compare with `codegen.ll`'s implementation.

2. **Debug codegen_eval_let_star binding order**: Verify that when processing a `let*` inside a label block, bindings are added to `cg->locals` before the next binding's value expression is evaluated. The binding for `i_val` must be visible when evaluating `(llvm:icmp 'uge i_val len)`.

3. **Compare bootstrap vs kernel codegen**: The bootstrap uses `codegen.ll` (pure LLVM IR); the kernel uses `codegen.vibe` (Vibe DSL). Diff the two implementations of `codegen_dsl_resolve_local`, `codegen_dsl_icmp`, and related code paths to find behavioral differences.

4. **Consider adding compiler diagnostics**: Per chat 39, when `codegen_eval_dsl_expr` returns null for an undefined function, the failure is silent. Adding a warning or error when a lookup returns null would make similar bugs easier to diagnose.

## Files Modified This Session

- `kernel/codegen.vibe`: Added 33 forward declarations (codegen_dsl_* handlers, codegen_extract_quoted_atom, codegen_append_typed_params, codegen_write_typed_params_to_buffer, llvm_count_params)

## Build Status

- `./build.sh bootstrap`: Success
- `./build.sh build_kernel`: Success
- `./build.sh build` (self-host): **Fails** — `process_char: No predecessors!` in `bootstrap_codegen_vibe_temp.ll`

## Related Documentation

- docs/chats/0039-self-host-missing-declarations-fix.md: Forward declaration rules, silent null failure mode
- docs/chats/0040-codegen-migration-phase-1-3-partial.md: Deferred migrations, Batch B status
- AGENTS.md: Bootstrap/Kernel Sync Strategy, cross-block variable usage
