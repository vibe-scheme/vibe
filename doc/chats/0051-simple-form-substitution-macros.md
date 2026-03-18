# Simple Form-Substitution Macros Implementation

**Date**: 2026-03-18
**Model**: Cursor Composer 1.5
**Context**: Implemented the minimal macro system per the Simple Form-Substitution Macros plan. Build succeeds, self-hosting intact. macro_hello test still fails—documented below for next session.

## Session Overview

### Implemented

1. **Expander module** (`kernel/expander.vibe`):
   - `expander_reverse_list` — reverses AST list for definition order
   - `expander_is_define_syntax` — detects `define-syntax` forms
   - `expander_is_macro_invocation` — detects `(name)` with no args
   - `expander_parse_simple_macro` — extracts `(name . template)` from first clause
   - `expander_lookup_macro` — alist lookup by name
   - `expander_expand_expr` — recursive expansion
   - `expander_process_one` — handles define-syntax (add to env) vs expansion
   - `expander_expand_top_level` — main entry point

2. **Control flow fix**: The conditional `llvm:br` in the process block was not being emitted by codegen (blocks had no terminators). Restructured to:
   - **process**: load form, call `process_one`, store result and next, unconditional br to `check_result`
   - **check_result**: load result, conditional br to `advance` or `cons_output`
   - **advance**: br to `loop`
   - **cons_output**: cons result onto output, br to `loop`

3. **Integration**: `main.vibe` already calls `expander_expand_top_level` before `codegen_main`.

### Build Status

- `./build.sh build` — succeeds
- Self-hosting — intact (vibe_kernel compiles all kernel modules including expander)
- `hello_world` test — passes

---

## Macro Expansion Problems (For Next Session)

The `macro_hello.vibe` test fails. Documented here for investigation.

### Symptoms

1. **Compile to .o**: Segfault (exit 139). Crash in LLVM's `simplifyFunctionCFG` pass during object emission:
   ```
   llvm::Value::getContext() const  (address 0x8 - null/invalid pointer)
   llvm::removeUnreachableBlocks
   simplifyFunctionCFG
   ```

2. **Compile to .ll**: Succeeds but produces wrong IR:
   - `main`: entry block **empty** (no terminator)
   - `main.1`: `ret i32 0`

3. **Comparison**: A file with the same content but no macros (`(llvm:ret (llvm:const-int |i32| 42))` literally) produces correct IR: single `main` with `ret i32 42`.

### What Works

- `test/macro_minimal.vibe` (define-syntax present but macro not used, literal 42 in body) — compiles to .o, links, runs, returns 42.
- Expansion logic appears correct: `(answer)` should expand to `(llvm:const-int |i32| 42)`.

### Hypotheses to Investigate

1. **Expanded AST structure**: When the template comes from macro lookup (vs. parsed literally), the AST may have different structure or pointers that codegen mishandles.

2. **codegen_main / create_main_llvm interaction**: The create_main_llvm path creates an empty main, then calls `codegen_append_top_level_exprs`. When `llvm:define-function (main)` is processed, it may reuse that main. The subsequent `llvm_build_ret builder zero_const` may overwrite or conflict with the expanded body.

3. **Template memory**: The template is part of the define-syntax AST. Returning it from lookup (no copy) might lead to use-after-free or corruption if the parser/allocator reuses memory.

4. **Order of processing**: Verify that define-syntax is processed before llvm:define-function (reversed list order). If not, `(answer)` would be expanded without `answer` in env.

### Debugging Commands Used

```bash
# IR output (no crash)
./build/bin/vibe_kernel test/macro_hello.vibe -o /tmp/macro.ll

# Segfault with backtrace
lldb -o "run test/macro_hello.vibe -o /tmp/macro.o" -o "bt" -o "quit" -- ./build/bin/vibe_kernel

# Compare IR
./build/bin/vibe_kernel test/macro_hello.vibe -o /tmp/hello_macro.ll
# vs. file with literal (llvm:const-int |i32| 42) — produces correct single main
```

### Files Modified

- `kernel/expander.vibe` — full expander implementation

### References

- Plan: `.cursor/plans/Simple Form-Substitution Macros-2e372013.plan.md`
- Chat 0038: codegen terminator bug, store+br workaround
- Chat 0050: macro expander foundation
