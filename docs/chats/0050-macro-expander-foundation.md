# Macro Expander Foundation

**Date**: 2026-03-18
**Model**: Cursor Composer 1.5
**Context**: Implemented the Macro Expander Foundation Plan from `.cursor/plans/Macro Expander Foundation-f30385fe.plan.md`

## Overview

Prepared the codebase for unhygienic macro implementation by creating the expander pipeline, extracting AST utilities into a shared module, and adding a macro canary test.

## Work Completed

### 1. `kernel/util.vibe` (new)

Extracted AST construction and utility functions from `codegen.vibe` per `docs/design/macro-system.md`:

| Function | Purpose |
|----------|---------|
| `check_primitive` | Match identifier against target string |
| `parse_int_string` | Parse integer from string |
| `parse_int_from_ast` | Parse integer from AST number atom |
| `extract_quoted_atom` | Extract atom name from AST_QUOTE node |
| `create_pointer_node` | Create AST node for pointer value |
| `create_string_node` | Create AST node for string atom |
| `create_cons` | Create cons cell (AST_LIST) |
| `create_pair` | Create pair with wrapped cdr |
| `is_array_type` | Check if LLVM type is array |
| `format_number` | Convert number to string (single digit) |
| `int_to_string` | Convert integer to string representation |

**Deferred**: `create_int_node` and `map_predicate_string` remain in codegen (they call `int_to_string` and `check_primitive` from util; compiler stops emitting after `int_to_string` when compiling util).

**Fix**: Corrected unbalanced parentheses in `int_to_string` — added one closing paren to fix "unexpected end of file (unclosed parentheses)" parse error.

### 2. `kernel/codegen.vibe` (modified)

- Added `llvm:declare-function` for all util functions (new names)
- Removed definitions of extracted functions
- Replaced all call sites with new util names
- Kept `create_int_node` and `map_predicate_string` definitions (with declare-function for forward reference)

### 3. `kernel/expander.vibe` (new)

- No-op `expander_expand_top_level(exprs)` that returns `exprs` unchanged
- Declares `ASTNode` type and util functions for future macro implementation

### 4. `kernel/main.vibe` (modified)

- Declared `expander_expand_top_level`
- In `generate_code`, call expander before codegen:
  ```scheme
  (let* ((expanded (llvm:call expander_expand_top_level exprs)))
    (llvm:call codegen_main codegen expanded))
  ```

### 5. `CMakeLists.txt` (modified)

- Added `compile_util` target: `kernel/util.vibe` → `util.bc`
- Added `compile_expander` target: `kernel/expander.vibe` → `expander.bc`
- Link order: `main lexer parser ffi dsl util codegen expander`
- Added both to `add_dependencies(vibe_kernel ...)`

### 6. Tests

- **`test/macro_hello.vibe`**: Macro canary using `(define-syntax answer (syntax-rules () ((answer) (llvm:const-int |i32| 42))))` and `(llvm:ret (answer))`. Fails (segfault) until macros implemented — expected.
- **`test/run_test.sh`**: Runs `hello_world` (must pass) and `macro_hello` (PENDING). Added `-arch arm64` for cc on Darwin to fix architecture mismatch when cmake runs tests under Rosetta (x86_64 cc vs arm64 object files).

## Verification

1. **Build**: `./build.sh build` — compiles successfully
2. **Tests**: `hello_world` passes; `macro_hello` PENDING (expected)
3. **Self-hosting**: `./build/bin/vibe_kernel kernel/main.vibe -o /tmp/main.ll` — succeeds

## Key Files

- **New**: `kernel/util.vibe`, `kernel/expander.vibe`, `test/macro_hello.vibe`
- **Modified**: `kernel/codegen.vibe`, `kernel/main.vibe`, `CMakeLists.txt`, `test/run_test.sh`

## Related

- `docs/design/macro-system.md` — macro implementation plan
- `.cursor/plans/Macro Expander Foundation-f30385fe.plan.md` — implementation plan
