# Chat 0037: Phi to Alloca Migration

**Date**: 2025-03-12
**Model**: Cursor Composer
**Context**: Reverting from phi nodes to alloca/store/load for cross-block values, adopting the Chat 0034 pattern. Rely on future mem2reg optimization pass for performance.

## Overview

This session replaced all phi node usage in `kernel/lexer.vibe` and `kernel/codegen.vibe` with the alloca/store/load pattern. The decision was driven by:

1. **Chat 0034 was correct**: Alloca/store/load is a valid, simpler pattern for cross-block values
2. **mem2reg can optimize later**: LLVM's C API exposes `LLVMRunPasses` which can run the mem2reg pass to promote allocas to phi nodes
3. **Lexical scope issues**: The lexer's phi referenced `token_type` from the `check_hash` block's `let*` when building the phi in `set_token_type`—cross-block binding reference that worked by undocumented behavior
4. **Migration simplicity**: Phi nodes require cross-block variable resolution that can be fragile; alloca avoids this

## Work Completed

### 1. kernel/lexer.vibe: lex_read_identifier

- Added `token_type_ptr (llvm:alloca |i32|)` to outer let*
- **all_digits**: Store `(llvm:const-int |i32| 2)` (TOKEN_NUMBER) before br to set_token_type
- **check_hash**: Store select result (TOKEN_SYMBOL or TOKEN_IDENTIFIER) before br to set_token_type
- **set_token_type**: Load from token_type_ptr instead of phi, store to type_ptr

### 2. kernel/codegen.vibe: codegen_append_type_fields

- Added `current_field_ptr (llvm:alloca |%ASTNode*|)` to outer let*
- **append_first**: Store `next` before br to append_more
- **append_more**: Load current_field from alloca; store `next_field` before br back to append_more

### 3. kernel/codegen.vibe: codegen_collect_field_types

- Added `current_fields_ptr (llvm:alloca |%ASTNode*|)` to outer let*
- **entry**: Store `fields` before br to collect_loop or done
- **collect_loop, get_field_pair, get_field_type, get_type_node, resolve_type, store_type**: Replace phi with load from current_fields_ptr
- **continue_collect**: Store `next_fields` before br to collect_loop

### 4. kernel/codegen.vibe: codegen_init

- Added `module_name_ptr (llvm:alloca |i8*|)` to outer let*
- **use_default_name**: Store default_name_array before br to create_module
- **use_provided_name**: Store module_name before br to create_module
- **create_module**: Load module_name_to_use instead of phi

### 5. AGENTS.md

- Replaced "Phi nodes for cross-block values" paragraph with "Cross-block values" guidance
- New guidance: Use alloca/store/load; mem2reg will optimize later; avoid phi for migration
- Removed "TODO (next session)" about reconsidering phi representation

## Key Decisions

1. **Leave phi DSL intact**: The `codegen_dsl_phi` implementation and `llvm:phi` primitive remain in the codebase for potential future use
2. **No bootstrap sync**: Migrated functions are defined in kernel/codegen.vibe; bootstrap has only declarations
3. **Chat 0034 precedence**: Per AGENTS.md immutability policy, Chat 0036's phi guidance is superseded by this session's adoption of the alloca approach

## Files Modified

- `kernel/lexer.vibe` — lex_read_identifier: phi → alloca/store/load
- `kernel/codegen.vibe` — codegen_append_type_fields, codegen_collect_field_types, codegen_init: phi → alloca/store/load
- `AGENTS.md` — Cross-block values guidance, removed phi TODO

## Related

- Chat 0034 (SSA Cross-Block Resolution Plan) — Original alloca recommendation
- Chat 0036 (Codegen Tier A, Phi and Init) — Phi migration that this reverts
- LLVMRunPasses / mem2reg discussion — Future optimization pass integration
