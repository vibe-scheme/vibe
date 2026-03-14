# Codegen Incremental Migration Session

**Date**: 2026-03-14
**Model**: Cursor Composer 1.5
**Context**: Implementing the Codegen Incremental Migration Plan (`.cursor/plans/Codegen Incremental Migration-aca0ff0e.plan.md`)

## Session Overview

Continued migration of functions from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe` following the plan's linear migration order. Migrated 10 functions successfully this session.

## Migrations Completed

### 1. codegen_append_function_def
- Simple text IR appender; uses `.str.define_void`, `.str.at_sign`, etc. from codegen_no_vibe.ll via `llvm:get-global`

### 2. codegen_eval_dsl_body
- Loop over DSL body list, calls `codegen_eval_dsl_expr`; no debug logging in kernel version

### 3. codegen_define_bitcode
- Legacy define-bitcode handler; delegates to `codegen_append_function_def`

### 4. codegen_append_top_level_exprs
- Recursive over top-level exprs; added forward decl for `codegen_call`

### 5. codegen_append_call_args
- Recursive over call args; uses `codegen_get_string_constant_name`, `codegen_format_number`, strlen; added forward decls

### 6. codegen_dsl_gep
- GEP builder; uses malloc/free for indices array, `codegen_eval_dsl_list`, `llvm_build_gep`; added forward decls

### 7. codegen_declare_llvm_function
- Function declaration handler; uses `llvm_create_function_type`, `llvm_add_function`, etc.; replaced phi with alloca/store/load for `func_type`

### 8. codegen_eval_dsl_list
- **Location**: ~124 lines in codegen_no_vibe.ll
- **Function**: Evaluates list of DSL expressions to array
- **Implementation**: Converted count loop + eval loop to Vibe DSL with `let*`, `llvm:label`, alloca/store/load for cross-block values
- **Key**: Replaced phi with alloca/store/load per AGENTS.md; used `(llvm:gep |i8*| array i_val)` for array indexing
- **Verification**: `./build.sh build` passed

### 9. codegen_define_bitcode_function
- **Location**: ~138 lines in codegen_no_vibe.ll
- **Function**: Generate LLVM function definition with typed params from IR body
- **Implementation**: AST extraction, buffer building with memcpy, `codegen_write_typed_params_to_buffer`, `codegen_parse_function_ir`
- **Key**: Used `func_def_buf_ptr` alloca for cross-block value (do_parse block needs buffer for free)
- **Forward declarations**: Added `codegen_parse_function_ir`
- **Verification**: `./build.sh build` passed

## Migrations Reverted (Per Plan)

### 11. codegen_main
- **Blocker**: Compiler bug - `add_function` block generated without terminator (br)
- **Symptom**: `llvm-as: error: expected instruction opcode` at `append_block: ; No predecessors!`
- **Root cause**: Generated IR had add_function block with only 2 loads (module, main_func_type), missing llvm_add_function call, store, and br
- **Action**: Reverted per plan ("If a migration breaks the build and the fix is non-trivial, revert and move on")

### 12. codegen_call
- **Blocker**: Complex migration - phi nodes, codegen_get_llvm_function (deferred), many branches
- **Action**: Reverted incomplete implementation; kept in codegen_no_vibe.ll

## Current Migration Status

- **Completed**: 10 functions (82 total in codegen.vibe)
- **Remaining in codegen_no_vibe.ll**: 20 functions (including 3 deferred)
- **Next in order**: codegen_parse_function_ir, codegen_define_llvm_ffi_function, ...

## Technical Notes

- **codegen_main compiler bug**: The block that had `(llvm:call llvm_add_function ...)` followed by `(llvm:br ...)` in a let* did not emit the call and br. Tried nested let* structure - no fix. May be a compiler bug in DSL codegen for certain label/let* patterns.
- **Forward declarations**: Removed `codegen_get_llvm_function`, `llvm_get_int32_type`, `llvm_get_pointer_type`, `llvm_build_call` after codegen_call revert (they were only needed for that migration).

## Files Modified

- `kernel/codegen.vibe`: Added codegen_append_function_def, codegen_eval_dsl_body, codegen_define_bitcode, codegen_append_top_level_exprs, codegen_append_call_args, codegen_dsl_gep, codegen_declare_llvm_function, codegen_eval_dsl_list, codegen_define_bitcode_function; added codegen_parse_function_ir forward decl; removed codegen_main (reverted)
- `bootstrap/codegen_no_vibe.ll`: Replaced define with declare for all 10 migrated functions; restored codegen_main define after revert

## Related Documentation

- `AGENTS.md`: Bootstrap/Kernel Sync Strategy, forward declarations, cross-block patterns
- `doc/chats/0039`: Forward declaration requirements
- `doc/chats/0040`: Deferred migrations
- `doc/chats/0042`: codegen_build_param_names deferral
