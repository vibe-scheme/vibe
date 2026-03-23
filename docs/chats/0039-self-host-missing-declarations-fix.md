# Chat 0039: Fix Self-Host Build — Missing Forward Declarations

**Date**: 2026-03-14
**Model**: Claude claude-4.6-opus-high-thinking (Cursor Agent)

## Overview

Fixed two issues preventing the self-host build from working:

1. **Missing `llvm:declare-function` declarations in `kernel/codegen.vibe`** — the root cause of all "entry block has no terminator" errors and the segfault during self-hosting.
2. **SELF_HOST CMake mode using direct bitcode output** — caused `llvm-link` type mismatch errors when linking the vibe_kernel-compiled bitcode.

After these fixes, the full self-host pipeline (`bootstrap → kernel → self-host`) completes successfully, with all three compilers producing identical LLVM IR output.

## Root Cause Analysis

### The Missing Declarations Bug

When the bootstrap compiler compiles `kernel/codegen.vibe`, it creates a fresh LLVM module. Functions are only available for `(llvm:call ...)` if they are:

1. Declared via `(llvm:declare-function ...)` at the top of the file
2. Defined via `(llvm:define-function ...)` earlier in the same file

Functions from other modules (e.g., `codegen_no_vibe.ll`, `dsl.vibe`) or defined later in the same file are **invisible** to the compiler unless explicitly declared. When a `(llvm:call undeclared_fn ...)` is encountered, `codegen_eval_dsl_expr` returns null, and **all subsequent `let*` bindings that depend on the null value are silently dropped**.

This produced structurally valid but semantically broken LLVM IR. For example, `codegen_dsl_icmp`'s `map_predicate` block was compiled as:

```llvm
map_predicate:
  %20 = load ptr, ptr %5, align 8   ; pred_name
  %21 = load i64, ptr %6, align 8   ; pred_len
  br label %map_predicate_br         ; EVERYTHING ELSE DROPPED
```

Instead of the expected 7 bindings (including the call to `codegen_map_predicate_string`, multiple `icmp`s, `or`s, and `store`s), only 2 loads and the final `br` survived. The call to `codegen_map_predicate_string` was dropped because that function was defined 200 lines later in the same file with no forward declaration.

This caused `pred_ptr` (the predicate alloca) to remain uninitialized. When `build_icmp` loaded from it, it got a garbage value (e.g., 1 = `FCMP_OEQ` instead of 32 = `ICMP_EQ`), producing `icmp oeq` instead of `icmp eq`. This cascaded: every function compiled by the kernel that used `llvm:icmp` got wrong predicates, causing branches to fail, leaving entry blocks unterminated.

### The Cascade

With 13 missing declarations, essentially all control flow functions in the kernel compiler were broken:
- `codegen_dsl_br` — missing calls to `codegen_get_or_create_label` and `llvm_build_br`/`llvm_build_cond_br`
- `codegen_dsl_icmp` — missing call to `codegen_map_predicate_string`
- `codegen_dsl_label` — missing calls to `llvm_get_insert_block`, `llvm_position_builder_at_end`, `llvm_get_basic_block_terminator`, `codegen_eval_dsl_body`
- `codegen_dsl_alloca` — missing call to `llvm_build_alloca`
- `codegen_dsl_phi` — missing calls to `llvm_build_phi`, `llvm_add_incoming`

When the kernel tried to compile ANY `.vibe` file, every generated function had an unterminated entry block, followed by a segfault in LLVM's type verification.

### The Bitcode Pipeline Bug

Separately, the SELF_HOST CMake mode compiled `.vibe` files directly to `.bc` (bitcode) using `vibe_kernel`, while the KERNEL mode went through `.ll` (text IR) → `llvm-as` → `.bc`. The text IR path normalizes types through the `llvm-as` parser, but direct bitcode output from `LLVMWriteBitcodeToFile` preserved type mismatches that `llvm-link` rejected (e.g., `@.str.percent` initializer type mismatch).

## Changes Made

### `kernel/codegen.vibe`

Added 13 missing `llvm:declare-function` forms after the existing declarations (around line 125):

**LLVM builder functions (from `dsl.vibe`):**
- `llvm_build_alloca`
- `llvm_build_br`
- `llvm_build_cond_br`
- `llvm_get_insert_block`
- `llvm_position_builder_at_end`
- `llvm_get_basic_block_terminator`
- `llvm_build_phi`
- `llvm_add_incoming`

**Codegen functions (from `codegen_no_vibe.ll`):**
- `codegen_get_or_create_label`
- `codegen_eval_dsl_body`

**Forward references (defined later in `codegen.vibe`):**
- `codegen_store_constant`
- `codegen_append_bytevector`
- `codegen_map_predicate_string`

### `CMakeLists.txt`

1. **Fixed codegen compilation pipeline**: Changed the SELF_HOST codegen block to use the same `.ll` + `llvm-as` pipeline as KERNEL mode, since `codegen.vibe` must be linked with `codegen_no_vibe.ll` and direct bitcode output causes type mismatches during `llvm-link`. Modules without a `_no_vibe.ll` counterpart (lexer, parser, ffi, dsl) compile directly to `.bc` in SELF_HOST mode for efficiency.

2. **Added zstd library linking**: Added `find_library(ZSTD_LIBRARY ...)` to locate the arm64 zstd library at `/opt/homebrew/lib/` and linked it to both `bootstrap_compiler` and `vibe_kernel` targets. This fixes linking failures with LLVM 22 on Apple Silicon where the x86_64 zstd at `/usr/local/lib/` was being ignored.

## Verification

After the fixes:
- `./build.sh clean && ./build.sh bootstrap` — succeeds
- `./build.sh build_kernel` — succeeds
- `./build.sh build` (self-host) — succeeds
- All 5 `.vibe` files (lexer, parser, ffi, dsl, codegen) produce **byte-for-byte identical** `.ll` output when compiled by `bootstrap_compiler`, `vibe_kernel` (kernel-built), and `vibe_kernel` (self-hosted)

## Key Insight

The silent failure mode of undefined function calls is dangerous. When `codegen_eval_dsl_expr` can't find a function, it returns null, and `codegen_eval_let_star` silently skips dependent bindings. This produces valid-looking IR with missing instructions — no error message, no crash, just wrong behavior at runtime.

Future improvement: the compiler should emit a warning or error when a `(llvm:call ...)` references an undefined function, rather than silently producing null.

## Notes for Completing the Codegen Migration

There are 37 functions remaining in `bootstrap/codegen_no_vibe.ll` to be migrated to `kernel/codegen.vibe`. Current status: 66 functions defined in `codegen.vibe`, 37 remaining in `codegen_no_vibe.ll`.

### Declaration Requirement

**Critical**: Any function called from `codegen.vibe` must be visible at the call site. There are two categories:

1. **External functions** (from `dsl.vibe`, `codegen_no_vibe.ll`, or C stdlib): Must have a `(llvm:declare-function ...)` at the top of `codegen.vibe` before any function that calls them.

2. **Internal forward references** (defined later in the same `codegen.vibe`): Must also have a `(llvm:declare-function ...)` at the top, OR must be reordered so the callee is defined before the caller.

When migrating a new function from `codegen_no_vibe.ll` to `codegen.vibe`:
- Check if it calls any function not yet declared in `codegen.vibe` — if so, add the declaration.
- Check if any already-migrated function in `codegen.vibe` calls it — if so, ensure a forward declaration already exists (it should if the function was in `codegen_no_vibe.ll` and was already being called).
- After migration, the function's `define` in `codegen_no_vibe.ll` should be replaced with a `declare`.

### Remaining Functions (37)

**Core dispatch/evaluation (complex, migrate last):**
- `codegen_eval_dsl_expr` — main DSL expression dispatcher
- `codegen_eval_dsl_list` — list expression evaluator
- `codegen_eval_let_star` — let* binding evaluator
- `codegen_eval_dsl_body` — body expression evaluator

**DSL primitives (moderate complexity):**
- `codegen_dsl_call` — function call builder
- `codegen_dsl_gep` — GEP instruction builder
- `codegen_dsl_ret` — return instruction builder
- `codegen_dsl_get_function` — function lookup
- `codegen_dsl_get_global` — global variable lookup
- `codegen_dsl_get_param` — parameter access
- `codegen_dsl_resolve_local` — local variable resolution
- `codegen_dsl_resolve_param` — parameter resolution
- `codegen_dsl_bind_local` — local variable binding

**Function definition/declaration:**
- `codegen_define_llvm_function` — main function definition handler
- `codegen_declare_llvm_function` — function declaration handler
- `codegen_define_llvm_ffi_function` — FFI function definition
- `codegen_define_bitcode` — bitcode definition handler
- `codegen_define_bitcode_function` — bitcode function handler

**Helpers:**
- `codegen_get_llvm_function` — function lookup in CodeGen list
- `codegen_get_or_create_label` — label/block management
- `codegen_get_function_type_by_value` — reverse function type lookup
- `codegen_resolve_type_string` — type name resolution
- `codegen_collect_param_types` — parameter type collection
- `codegen_build_param_names` — parameter name list building
- `codegen_call` — low-level call instruction builder
- `codegen_append_call_args` — call argument processing
- `codegen_parse_function_ir` — function IR text parsing

**Output/text generation:**
- `codegen_append_function_def` — function definition text output
- `codegen_append_params` — parameter text output
- `codegen_append_typed_params` — typed parameter text output
- `codegen_append_top_level_exprs` — top-level expression output
- `codegen_write_typed_params_to_buffer` — parameter buffer writing
- `codegen_write_ir_text` — IR text file output
- `codegen_write_bitcode` — bitcode file output
- `codegen_write_object_file` — object file output
- `codegen_main` — main/entry point generation
- `debug_log_string` — debug logging utility

### Codegen SELF_HOST Pipeline Note

`codegen.vibe` must go through the `.ll` + `llvm-as` pipeline (not direct `.bc`) in both KERNEL and SELF_HOST modes because it is linked with `codegen_no_vibe.ll` via `llvm-link`, and direct bitcode output causes type mismatches during linking. This constraint will be lifted when all functions are migrated and `codegen_no_vibe.ll` is eliminated.

Modules without a `_no_vibe.ll` counterpart (lexer, parser, ffi, dsl) already compile directly to `.bc` in SELF_HOST mode.

## Files Modified

- `kernel/codegen.vibe` — added 13 `llvm:declare-function` forward declarations
- `CMakeLists.txt` — fixed SELF_HOST codegen pipeline to use `.ll` + `llvm-as`, added zstd linking
