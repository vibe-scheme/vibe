# Chat 0022: Lexer Function Migration & llvm:declare-function

**Date**: 2026-02-07
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)

## Overview

This session continued the migration of lexer functions from `lexer_no_vibe.ll` to `lexer.vibe`, building on the work planned in a prior session. We migrated 5 functions total, and in the process implemented a new DSL primitive (`llvm:declare-function`) to unblock migration of functions that call into separately-linked modules.

## Work Completed

### 1. Migrated 4 Lexer Functions (from prior plan)

The following functions were ported from raw LLVM IR in `lexer_no_vibe.ll` to Vibe DSL in `lexer.vibe`, and their definitions in `lexer_no_vibe.ll` were replaced with `declare` statements:

- **`lex_is_delimiter`** - Character delimiter check (whitespace, punctuation, EOF)
- **`lex_peek_char`** - Peek at character at offset from current position
- **`lex_skip_comment`** - Skip line comments (semicolon to newline)
- **`lex_error`** - Create error tokens with message and position info

These functions only required existing DSL primitives (`llvm:gep`, `llvm:load`, `llvm:store`, `llvm:icmp`, `llvm:br`, `llvm:label`, `llvm:zext`, `llvm:add`, `llvm:or`, `llvm:call`, `llvm:const-int`, `llvm:ret`, `llvm:ret-void`, `llvm:bitcast`).

### 2. Implemented `llvm:declare-function` DSL Primitive

**Problem**: `lex_peek` calls `lex_next`, which remains in `lexer_no_vibe.ll`. The existing `llvm:call` resolution chain (local bindings -> tracked functions -> parameters -> constants) only finds functions defined in the current `.vibe` file or declared via `llvm:define-ffi-function`. There was no way to declare a function that would be resolved at link time from another module.

**Solution**: Added `llvm:declare-function`, a new top-level DSL form that creates an LLVM function declaration (no body) with external linkage and registers it for name resolution.

**Syntax**:
```scheme
(llvm:declare-function (name (param1 type1) (param2 type2) ...) return-type)
```

**Implementation** (3 files modified):

- **`bootstrap/compiler/codegen.ll`**: Added `codegen_declare_llvm_function` handler. This is a stripped-down version of `codegen_define_llvm_function` that:
  - Parses the function signature (name, parameter types, return type)
  - Resolves types via `codegen_resolve_type_string` and `codegen_collect_param_types`
  - Creates the function type via `llvm_create_function_type`
  - Adds the declaration via `llvm_add_function` (same LLVM C API as definitions - a function with no basic blocks is automatically a declaration)
  - Sets external linkage via `llvm_set_linkage`
  - Stores the function and type for later resolution via `codegen_store_llvm_function` and `codegen_store_function_type`
  - Skips all body-related logic (no basic block creation, no parameter naming, no DSL body evaluation)

- **`bootstrap/compiler/main.ll`**: Added dispatch logic between `check_ffi_function` and `check_bitcode_function` to recognize `llvm:declare-function` and route to the new handler. Added string constant and function declaration.

**Key insight**: In LLVM, `LLVMAddFunction` creates both declarations and definitions. A function with no basic blocks is a declaration (`declare`), while one with basic blocks is a definition (`define`). So `llvm:declare-function` reuses the same infrastructure as `llvm:define-function` but simply stops before creating any basic blocks.

### 3. Migrated `lex_peek` Using `llvm:declare-function`

With the new primitive in place, `lex_peek` was migrated to `lexer.vibe`:

```scheme
; Forward declaration for lex_next, defined in lexer_no_vibe.ll
(llvm:declare-function (lex_next (lexer |%Lexer*|)) |%Token*|)

; lex_peek: Peek at the next token without consuming it
(llvm:define-function (lex_peek (lexer |%Lexer*|)) |%Token*|
  (let* ((pos_ptr (llvm:gep |%Lexer| lexer 0 2))
         (saved_pos (llvm:load pos_ptr |i64|))
         (line_ptr (llvm:gep |%Lexer| lexer 0 3))
         (saved_line (llvm:load line_ptr |i32|))
         (col_ptr (llvm:gep |%Lexer| lexer 0 4))
         (saved_col (llvm:load col_ptr |i32|))
         (token (llvm:call lex_next lexer)))
    (llvm:store saved_pos pos_ptr)
    (llvm:store saved_line line_ptr)
    (llvm:store saved_col col_ptr)
    (llvm:ret token)))
```

The generated LLVM IR correctly shows `declare ptr @lex_next(ptr)` (declaration only) alongside `define ptr @lex_peek(...)` (full definition that calls it).

## Remaining Functions in `lexer_no_vibe.ll`

6 functions remain to be migrated. The table below lists each function and the new DSL primitives it would require beyond what is currently available.

### Available DSL Primitives (as of this session)

**Top-level forms**: `llvm:define-function`, `llvm:declare-function`, `llvm:define-ffi-function`, `llvm:define-type`, `llvm:define-constant`

**Expression primitives**: `llvm:gep`, `llvm:call`, `llvm:ret`, `llvm:ret-void`, `llvm:const-int`, `llvm:const-null`, `llvm:bitcast`, `llvm:store`, `llvm:load`, `llvm:icmp`, `llvm:br`, `llvm:label`, `llvm:zext`, `llvm:add`, `llvm:or`, `llvm:get-global`, `llvm:get-function`, `llvm:get-param`, `llvm:array`, `list`

### Migration Table

| Function | New DSL Primitives Needed | Notes |
|---|---|---|
| `lex_read_identifier` | `llvm:alloca`, `llvm:and`, `llvm:select`, `llvm:phi` | Uses `alloca` for loop counter, `and` for range checks, `select` for hash/identifier type, `phi` to merge token type from multiple predecessors |
| `lex_read_string` | `llvm:alloca` | Uses `alloca` for buffer position counter; escape sequence handling uses only existing primitives |
| `lex_read_vertical_bar_symbol` | `llvm:alloca`, `llvm:global-string` (or equivalent) | Uses `alloca` for buffer position; references global string constant `@.str.unclosed_vbar` for error message |
| `lex_read_bytevector` | `llvm:alloca`, `llvm:trunc`, `llvm:mul`, `llvm:sub`, `llvm:global-string` (or equivalent) | Uses `alloca` for buffer position and accumulator; `trunc` to convert i32 to i8; `mul`/`sub` for digit parsing; references global string `@.str.invalid_bytevector` |
| `lex_next` | `llvm:global-string` (or equivalent), `llvm:declare-function` (for self-recursion and `printf`) | Large dispatcher (~145 lines of IR); calls `printf` with global format strings for debug logging; recursive self-call; calls `lex_debug_log_token`. Could use `llvm:declare-function` for `printf` and self-reference. |
| `lex_debug_log_token` | `llvm:global-string` (or equivalent), variadic `llvm:call` support | Uses `printf` with format strings and variadic args; references multiple global string constants |

### Priority Order for New Primitives

Based on frequency of use and unblocking potential:

1. **`llvm:alloca`** - Needed by 4 of 6 functions. Stack allocation for mutable loop variables.
2. **`llvm:global-string`** (or `llvm:define-global-string`) - Needed by 4 of 6 functions. Module-level string constants referenced inline.
3. **`llvm:and`** - Needed by `lex_read_identifier` and `lex_read_bytevector`. Bitwise AND for range checks.
4. **`llvm:sub`** - Needed by `lex_read_identifier` and `lex_read_bytevector`. Integer subtraction.
5. **`llvm:mul`** - Needed by `lex_read_bytevector`. Integer multiplication.
6. **`llvm:trunc`** - Needed by `lex_read_bytevector`. Integer truncation (i32 -> i8).
7. **`llvm:select`** - Needed by `lex_read_identifier`. Conditional value selection without branching.
8. **`llvm:phi`** - Needed by `lex_read_identifier`. SSA phi nodes for merging values from multiple predecessors.
9. **Variadic `llvm:call`** - Needed by `lex_debug_log_token`. Calling variadic functions like `printf`.

### Migration Strategy

With `llvm:alloca` and `llvm:global-string` implemented, `lex_read_string` becomes immediately migratable (it only needs those two plus existing primitives). Adding `llvm:and` and `llvm:sub` further unblocks `lex_read_vertical_bar_symbol`. The most complex function is `lex_next` due to its size and debug logging, but it is structurally simple (a large chain of `br`/`label` dispatches).

## Files Modified

- `bootstrap/compiler/codegen.ll` - Added `codegen_declare_llvm_function` handler and debug string constant (+127 lines)
- `bootstrap/compiler/main.ll` - Added dispatch for `llvm:declare-function`, string constant, and function declaration (+14 lines)
- `bootstrap/lexer/lexer.vibe` - Added `lex_next` forward declaration and `lex_peek` function definition; earlier in session added `lex_is_delimiter`, `lex_peek_char`, `lex_skip_comment`, `lex_error` (+107 lines)
- `bootstrap/lexer/lexer_no_vibe.ll` - Replaced 5 function definitions with `declare` statements (-137 lines)

## Verification

- Bootstrap compiler rebuilt successfully with `./build.sh bootstrap`
- Kernel built successfully with `./build.sh build_kernel`
- Generated IR confirmed correct `declare ptr @lex_next(ptr)` and `define ptr @lex_peek(...)` 
- Smoke test with `test/hello_world.vibe` passed (exit code 0)
