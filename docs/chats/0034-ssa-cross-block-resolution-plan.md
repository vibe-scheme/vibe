# Chat 0034: SSA Cross-Block Resolution Plan and Tier 2 Migration

**Date**: 2026-03-12  
**Model**: Cursor Composer 1.5  
**Context**: Implementing the SSA Cross-Block Symbol Resolution Plan to resolve Tier 2 migration "Global not found" errors, then performing actual Tier 2 migration.

## Overview

This session had two parts:

1. **Phase 1**: Added a minimal repro with the correct structure (labels inside `let*` body). The repro passed, confirming the Tier 2 failure in chat 0033 was due to **incorrect migration structure**, not a bootstrap compiler bug.

2. **Phase 2**: Removed the repro and performed actual Tier 2 migration. **codegen_collect_field_types** and **codegen_append_type_fields** were successfully migrated. The initial migration had a **lexical scope bug** — labels were siblings of `let*` instead of inside it, so bindings like `count` and `current_field_ptr` were out of scope. Fixed by moving labels inside the `let*` body. **codegen_define_llvm_type** and **codegen_define_llvm_constant** remain deferred; re-attempt with correct scope structure.

## Scope Semantics (Clarified)

- **`let*`** introduces lexical scope — variable names (bindings) are visible only within its body.
- **`llvm:label`** does not introduce lexical scope — it is like a goto target.

So: if `let*` and `llvm:label` are **siblings**, the label cannot access bindings from the `let*` (out of scope). If two `llvm:label` blocks are **siblings within** a `let*` body, both can access the `let*` bindings.

## Work Completed

### Phase 1.1: Minimal Repro

Added `test_cross_block` to `kernel/codegen.vibe` with the **correct structure** — labels inside the `let*` body:

```scheme
(llvm:define-function (test_cross_block ()) |void|
  (let* ((x (llvm:alloca |i32|)))
    (llvm:label 'entry
      (llvm:store (llvm:const-int |i32| 42) x)
      (llvm:br 'other))
    (llvm:label 'other
      (llvm:store (llvm:const-int |i32| 0) x)
      (llvm:ret-void))))
```

### Phase 1.2: Build Verification

`./build.sh build_kernel` succeeded. The repro compiles without "Global not found" errors.

### Phase 2: Actual Tier 2 Migration

**Removed test_cross_block** repro per user request.

**Migrated codegen_append_type_fields** — Uses labels inside `let*` with alloca for `current_field_ptr` to pass loop state between blocks. Scope fix: labels were moved inside the `let*` body so `current_field_ptr` is in lexical scope.

**Migrated codegen_collect_field_types** to `kernel/codegen.vibe`:

- **Structure**: Labels **inside** the `let*` body (not siblings) so `count` and `current_fields_ptr` are in lexical scope
- **Flow**: entry → collect_loop → get_field_pair → get_field_type → get_type_node → resolve_type → store_type → continue_collect → done
- **Key pattern**: Alloca-based loop (store/load) instead of phi nodes; each label reloads values it needs from allocas or re-computes from node
- **Dependency**: Calls `codegen_resolve_type_string` (stays in codegen_no_vibe.ll)

**bootstrap/codegen_no_vibe.ll**: Replaced codegen_collect_field_types definition with `declare`.

**Scope fix**: The initial migration had labels as siblings of `let*`, not inside it — `count` and `current_fields_ptr` were out of scope in the label blocks. Fixed by moving all labels inside the `let*` body. Same fix applied to `codegen_append_type_fields`.

**Attempted codegen_define_llvm_type — Deferred**

Multiple migration attempts failed with "No predecessors!" / "expected instruction opcode" errors. **Later diagnosis**: The failure was likely the same **lexical scope** issue — labels were siblings of `let*` instead of inside it, so references to `count`, `current_fields_ptr`, `types_array_storage` in label blocks were out of scope. Re-attempt with labels inside the `let*` body.

**Deferred codegen_define_llvm_constant** — Similar multi-block structure with cross-block SSA. Expected to hit the same block-terminator bug.

**codegen_resolve_type_string** — Remains deferred from chat 0033 (~250 lines, many blocks). Would likely hit the same terminator issue.

## Key Decisions

1. **No "Global not found" bug**: The "Global not found" in chat 0033 was due to incorrect migration structure (labels as siblings of `let*`), not a bug in `codegen_dsl_resolve_local` or `codegen_eval_let_star`.

2. **Correct structure for Tier 2**: When migrating, wrap the function body in a `let*` that binds all values needed across blocks, with labels as the body of that `let*`. Use alloca for loop state instead of phi nodes.

3. **Lexical scope is critical**: Labels must be **inside** the `let*` body (not siblings) for any bindings that must be shared across blocks. The initial migration of codegen_collect_field_types and codegen_append_type_fields had this bug — labels referenced `count`, `current_fields_ptr`, `current_field_ptr` from outside their scope.

4. **Deferral comments**: Added comments in codegen.vibe for codegen_define_llvm_type and codegen_define_llvm_constant. Re-attempt with correct scope (labels inside let*) when resuming.

## Migration Status (Current)

| Function | Status | Notes |
|----------|--------|-------|
| codegen_append_type_fields | Migrated | Labels in let*, alloca for loop |
| codegen_collect_field_types | Migrated | Alloca pattern, calls codegen_resolve_type_string |
| codegen_resolve_type_string | Deferred | ~250 lines, complex; stays in .ll |
| codegen_define_llvm_type | Deferred | Re-attempt with labels inside let* |
| codegen_define_llvm_constant | Deferred | Same scope structure needed |

## Files Modified

- `kernel/codegen.vibe` — Added test_cross_block (later removed); added codegen_collect_field_types; added deferral comments for codegen_define_llvm_type and codegen_define_llvm_constant
- `bootstrap/codegen_no_vibe.ll` — Replaced codegen_collect_field_types definition with `declare`
- `AGENTS.md` — Updated Tier 2 status and added Cross-block variable usage section
- `docs/chats/0034-ssa-cross-block-resolution-plan.md` — This document

## Next Steps

1. **Re-attempt codegen_define_llvm_type and codegen_define_llvm_constant** using the correct structure: wrap the entire function body in a `let*` that binds all values needed across blocks (types_array_storage, named_struct_type_ptr, name_buf_ptr, etc.), with `llvm:label` blocks as the body of that `let*`.

2. **Verify scope in any new migration**: Labels that reference `count`, `current_fields_ptr`, or other allocas must be inside the `let*` that defines those bindings.

## Related

- Chat 0033 (Full Codegen Migration) — Tier 2 deferred due to "Global not found"
- SSA Cross-Block Resolution Plan (`.cursor/plans/`)
