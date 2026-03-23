# Chat 0023: Codegen Bugfixes and lexer_no_vibe.ll Removal

**Date**: 2026-02-08
**Model**: Claude claude-4.6-opus-high-thinking (Cursor)

## Overview

This session focused on debugging and fixing several codegen bugs that were preventing the kernel compiler from building, then completing the full lexer migration by removing `lexer_no_vibe.ll`.

## Bugs Fixed

### 1. Array Type Parser Off-by-One (`codegen.ll:3894`)

The `check_element_type` block in `codegen_resolve_type_string` used `getelementptr +4` to find `'i'` in the string `" x i8]"` (offset from `num_end`), but the correct offset is `+3`:

```
" x i8]"
 0123456
    ^ +3 = 'i' (correct)
     ^ +4 = '8' (wrong)
```

This caused ALL `[N x i8]` array type resolution to fail silently, which meant constants defined with `llvm:define-constant` were never stored in the LLVM module's constant lookup table. They were only generated as text IR. When later referenced in `llvm:call`, the constant couldn't be found, silently dropping the call and leaving basic blocks unterminated -- producing the `llvm-as` error at the `done_ok:` label.

### 2. Forward Declaration Collision (`codegen.ll:7884`)

`codegen_define_llvm_function` always called `llvm_add_function`, but if a prior `llvm:declare-function` had already added a declaration with the same name to the LLVM module, LLVM would rename the new definition (e.g., `lex_next` became `lex_next.1`). The original declaration remained as an unresolved external, causing a linker error:

```
Undefined symbols for architecture arm64:
  "_lex_next", referenced from: _lex_peek, _parse_init, _parse_advance
```

Fixed by calling `llvm_get_named_function` first. If a function with that name already exists (from a forward declaration), the existing value is reused and the definition body is added to it. A phi node merges the function value from both the new-creation and reuse paths.

### 3. Variadic Function Flag Extraction (`codegen.ll:8044`)

The `codegen_define_llvm_ffi_function` handler was looking for the `#t` vararg flag inside the library info list `("lib" "sym")` by navigating `lib_info_cdr.cdr`, instead of in the top-level form. The correct navigation is `cdr_cdr_cdr.cdr` (the 5th element of the top-level list):

```scheme
;; Top-level form structure:
;; (llvm:define-ffi-function  ;; element 1
;;   (printf (fmt |i8*|))     ;; element 2 (signature)
;;   |i32|                    ;; element 3 (return type)
;;   ("libSystem" "printf")   ;; element 4 (library info)
;;   #t)                      ;; element 5 (vararg flag) <-- was looked up inside element 4
```

This caused `printf` to be declared as `declare i32 @printf(ptr)` instead of `declare i32 @printf(ptr, ...)`, resulting in variadic arguments being silently dropped on AArch64 (different calling convention for variadic vs non-variadic functions).

## Other Changes

### Label Un-nesting in `lexer.vibe`

Flattened nested labels in `lex_advance` so all labels (`advance`, `newline`, `normal`, `increment_pos`, `done`) are siblings at the same scope level, matching the flat style used in all other functions.

### Removal of `lexer_no_vibe.ll`

Since all lexer functions have been migrated to `lexer.vibe`, the `lexer_no_vibe.ll` file was just an empty shell containing only target triple and type definitions (already present in `types.ll`). Removed the file and updated `CMakeLists.txt`:

- Removed the `lexer_no_vibe.ll` assembly step from KERNEL/SELF_HOST build modes
- The link step now combines `bootstrap_types.bc` + `bootstrap_lexer_vibe_temp.bc` directly (2 inputs instead of 3)
- Removed the now-unused `LEXER_SOURCE` variable for non-BOOTSTRAP modes

### Updated `test/hello_world.vibe`

Uncommented and corrected all Vibe code to serve as a working end-to-end test:
- Defines a `Point` type, two string constants, printf via FFI with varargs
- Defines a `hello` function that takes a `name` parameter and calls `printf` with format string substitution
- Defines a `main` function that calls `hello` with "World"
- Successfully compiles to a native executable that prints `Hello, World!`

## Files Modified

- `bootstrap/compiler/codegen.ll` -- Three bug fixes (array type parser, forward declaration reuse, vararg flag extraction)
- `bootstrap/lexer/lexer.vibe` -- Flattened nested labels in `lex_advance`
- `bootstrap/lexer/lexer_no_vibe.ll` -- Deleted
- `bootstrap/runtime/ffi.ll` -- No changes in this session (changes from previous session)
- `CMakeLists.txt` -- Removed `lexer_no_vibe.ll` from build pipeline
- `test/hello_world.vibe` -- Updated to working hello world program

## Testing

All three build modes pass:
- `./build.sh bootstrap` -- Bootstrap compiler builds successfully
- `./build.sh build_kernel` -- Kernel compiler builds and links successfully
- `./build.sh build` -- Self-hosting build completes successfully
- `test/hello_world.vibe` compiles to a working executable with the kernel compiler
