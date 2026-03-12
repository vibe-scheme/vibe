# Chat 0036: Codegen Tier A Migration, Phi Node Guidance, and Codegen Init

**Date**: 2026-03-12
**Model**: Cursor Composer
**Context**: Tier A codegen migration; phi node guidance (correcting chat 0034); codegen_init migration; chat immutability policy.

## Session Overview

This session had three main parts:

1. **Tier A Migration**: Migrated 18 simple DSL functions from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe`.
2. **Phi Node Guidance**: Chat 0034 recommended alloca/store/load for cross-block values; that hurts performance. This chat corrects that: use phi nodes (see `kernel/lexer.vibe`). Chat 0034 was left unchanged (chats are immutable); AGENTS.md documents that later chats take precedence when there is contradiction.
3. **Codegen Init and Phi Migrations**: Updated `codegen_append_type_fields`, `codegen_collect_field_types`, and `codegen_init` to use phi nodes instead of alloca for loop-carried and merged values.

## Work Completed

### Part 1: Tier A Migrations (18 functions)

1. **Prerequisites**
   - Added `.str.empty` constant definition at top of `kernel/codegen.vibe` (before Tier A functions) so `llvm:get-global .str.empty` resolves during codegen
   - Removed duplicate `.str.empty` definition from end of file
   - Forward declarations for `llvm_build_*` and `codegen_eval_dsl_expr` already present

2. **Tier A Migrations**
   - Binary ops: `codegen_dsl_add`, `codegen_dsl_or`, `codegen_dsl_sub`, `codegen_dsl_and`, `codegen_dsl_mul`, `codegen_dsl_urem`, `codegen_dsl_udiv`
   - Unary/other: `codegen_dsl_const_int`, `codegen_dsl_bitcast`, `codegen_dsl_store`, `codegen_dsl_load`, `codegen_dsl_trunc`, `codegen_dsl_select`, `codegen_dsl_zext`, `codegen_dsl_icmp`, `codegen_dsl_insertvalue`, `codegen_dsl_extractvalue`, `codegen_dsl_ptrtoint`

3. **Bootstrap DSL Workarounds Applied**
   - **Terminator bug**: When a block ends with `(llvm:call llvm_build_X ...)` followed by `(llvm:ret result)`, the bootstrap drops the terminator. Workaround: store result in alloca, branch to ret block, load and ret in separate block.
   - **Store+br bug**: When a block has store then conditional br, the br can be dropped. Workaround for `codegen_dsl_icmp` map_predicate: split into map_predicate (store + br to map_predicate_br) and map_predicate_br (conditional br).
   - **Local variable lookup**: DSL resolves symbols as globals; local variables in let* (e.g. `empty_str`, `add_result`) cause "Global not found". Workaround: inline expressions—use `(llvm:gep |[1 x i8]| (llvm:get-global .str.empty) 0 0)` directly in llvm:call, and `(llvm:store (llvm:call llvm_build_X ...) result_ptr)` to avoid storing then referencing local.

4. **codegen_no_vibe.ll Updates**
   - Replaced `define` with `declare` for all 18 migrated Tier A functions
   - `.str.empty` remains `external constant` (defined in codegen.vibe output)

### Part 2: Documentation Updates

- **AGENTS.md**: Added "Phi nodes for cross-block values" section; added "Chat Immutability and Precedence" (committed chats are immutable; later chats take precedence when contradictory); updated migration count 40 → 58 (Tier A: 18 functions).

### Part 3: Phi Node Migrations and Codegen Init

- **codegen_append_type_fields**: Replaced `current_field_ptr` alloca with `(llvm:phi |%ASTNode*| (next 'append_first) (next_field 'append_more))` in append_more block.
- **codegen_collect_field_types**: Replaced `current_fields_ptr` alloca with phi chain — `collect_loop` uses `(llvm:phi |%ASTNode*| (fields 'entry) (next_fields 'continue_collect))`; downstream blocks use phi to receive `current_fields` from their predecessors.
- **codegen_init**: Replaced `(llvm:select ...)` with `(llvm:phi |i8*| (default_name_array 'use_default_name) (module_name 'use_provided_name))` in create_module; fixed label closing parens (check_module_name, use_default_name, create_module, set_target). User manually fixed remaining paren balancing.

### Bootstrap

- **bootstrap/main.ll**: Increased read_file buffer from 128KB to 512KB (codegen.vibe exceeds 128KB).

## Build Status

- **Bootstrap compiler**: Succeeds (compiles codegen.vibe to .ll)
- **llvm-as**: Succeeds (converts .ll to .bc)
- **Linker**: Initially failed with undefined symbols (`codegen_init`, `codegen_dispose`, etc.); kernel build still fails after phi migrations and user's manual paren fixes. Compilation issues remain; root cause not fully resolved this session.

## Note for Next Session

**Reconsider how we represent phi nodes in Vibe.**

The current `(llvm:phi type (value1 'label1) (value2 'label2) ...)` form requires the codegen to resolve values from other blocks when building phi nodes (e.g., `(current_fields 'collect_loop)` when in `get_field_pair`). This may be causing compilation failures or exposing limitations in the DSL/codegen. The next session should:

1. Investigate whether the phi form and cross-block value resolution are working correctly.
2. Consider alternative representations or codegen approaches for phi nodes.
3. Verify the lexer.vibe phi pattern still works and understand why it succeeds where codegen_collect_field_types may fail.

## Key Decisions

1. **Scope**: Labels must be inside let* body for allocas to be visible (chat 0034).
2. **Phi over alloca**: Use phi nodes for SSA values that merge from multiple predecessors; do not use alloca/store/load (chat 0034 recommended alloca; this chat corrects to phi).
3. **Chat immutability**: Committed chats are not edited; corrections go in newer chats; later chats take precedence when contradictory.

## Technical Notes

- **Trunc/zext**: Use `(llvm:trunc value |source-type| |target-type|)` with 3 args
- **codegen_dsl_icmp**: Uses `codegen_extract_quoted_atom` for predicate, `pred_invalid_ptr` alloca for store+br workaround

## Files Modified

- `kernel/codegen.vibe` — Tier A function definitions, .str.empty placement, workarounds; codegen_append_type_fields, codegen_collect_field_types, codegen_init phi migrations
- `bootstrap/codegen_no_vibe.ll` — define → declare for 18 Tier A functions
- `bootstrap/main.ll` — Buffer size increase
- `AGENTS.md` — migration count, phi node guidance, chat immutability and precedence

## Related

- Chat 0034 (SSA Cross-Block Resolution) — Original migration that recommended alloca; this chat corrects to phi
- Chat 0022 (Lexer Migration) — Established llvm:phi usage in lexer.vibe
- `kernel/lexer.vibe` line 522 — Reference phi pattern
