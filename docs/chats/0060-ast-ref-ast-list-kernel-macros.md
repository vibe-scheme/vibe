# Chat 0060: AST field macros (`vibe:ast-ref`, `vibe:ast-addr`) and `vibe:ast-list`

**Date**: 2026-03-28  
**Model**: Cursor Composer 2  
**Context**: Implement the planned batch of kernel macros so `ASTNode` layout lives in one place (`kernel/macros.vibe`), with mechanical adoption across the self-hosted kernel. **Same working session (before commit)** later redefined **`vibe:ast-list`** so it matches how the kernel already builds **`create_cons`** chains (right-nested pairs), instead of R7RS-style proper lists; **`codegen.vibe`** then compiles cleanly with the macro in use.

## Summary

### AST field access and GEP cleanup

- Added **`vibe:ast-ref`** (multi-clause `syntax-rules` with literals `type`, `atom_type`, `value`, `value_len`, `car`, `cdr`, `line`, `column`) and **`vibe:ast-addr`** (same literals, GEP-only) in **`kernel/macros.vibe`**, with a header comment documenting indices and load types aligned with **`kernel/types.vibe`**.
- Refactored **`vibe:node-empty?`**, **`vibe:node-kind?`**, and **`vibe:atom-type?`** to expand via **`vibe:ast-ref`** (and existing **`vibe:ptr-empty?`** where needed).
- Replaced essentially all raw **`(llvm:gep |%ASTNode| …)`** in **`kernel/util.vibe`**, **`kernel/expander.vibe`**, **`kernel/parser.vibe`**, **`kernel/main.vibe`**, and **`kernel/codegen.vibe`** with **`vibe:ast-addr`** / **`vibe:ast-ref`** (after a mechanical pass for combined **`llvm:load`+`llvm:gep`** forms). **`kernel/macros.vibe`** still contains the underlying GEP/load templates for the macros themselves.
- Cross-linked **`types.vibe`** (`ASTNode`) to the new macros.

### `vibe:ast-list` (two steps in one session)

- **First version**: variadic **`syntax-rules`** with ellipsis, expanding like R7RS **`list`**: recursive **`create_cons`** with a **null** tail. Using it in **`codegen_store_llvm_function`** while compiling **`codegen.vibe`** triggered a host **segmentation fault** (likely expander stack/recursion depth during macro expansion); DEBUG comments were left in place during investigation.
- **Refined version** (same session): three clauses **in order**: **`()` → `(llvm:const-null |%ASTNode*|)`**; **`(x) → x`**; **`(x y …) → (llvm:call create_cons x (vibe:ast-list y …))`**. This is **right-nested** **`create_cons`** (e.g. **`(a b c)` → `(create_cons a (create_cons b c))`**), matching hand-written kernel codegen, **not** a proper list ending in null. The **single-argument** clause must come **before** the ellipsis clause so **`(vibe:ast-list a)`** is not expanded to **`(create_cons a null)`**. Docstring and **`docs/design/macro-system.md`** describe this; a future R7RS **`list`** / parser-aligned empty list is deferred.
- **`kernel/codegen.vibe`**: **`codegen_store_llvm_function`** uses **`(vibe:ast-list name_node func_value_node func_type_node)`**; DEBUG comments removed after the nesting fix.
- **`docs/design/macro-system.md`**: AST layering section and macro table updated for the final **`vibe:ast-list`** shape; the interim warning not to use the macro in large kernel modules was dropped once **build**/**test** succeeded with the nested expansion.

### Tests

- Added **`test/macro_ast_ref_shape.vibe`** (user-level canary for literal-keyed clauses like **`vibe:ast-ref`**) and wired it into **`test/run_test.sh`** (expected exit **19**).

## Technical notes

- Initial automated replacement used a broken regex for LLVM types containing `*` (e.g. `|%ASTNode*|`) because `[^\)]` swallowed the closing `|`; fixed by matching types as `\|[^|]+\|`.
- Combined **`llvm:load (llvm:gep …)`** was replaced first; remaining GEPs became **`vibe:ast-addr`**, then **`llvm:load (vibe:ast-addr …)`** folded to **`vibe:ast-ref`** where types matched.

## Verification

- **`./build.sh build`** (self-hosted **`vibe_kernel`**, including **`compile_codegen`** with **`vibe:ast-list`**).
- **`./build.sh test`** — all 6 tests passed.

## Files touched

- `kernel/macros.vibe`, `kernel/types.vibe`, `kernel/util.vibe`, `kernel/expander.vibe`, `kernel/parser.vibe`, `kernel/main.vibe`, `kernel/codegen.vibe`
- `docs/design/macro-system.md`
- `docs/pages/index.html` (macro status blurb: shared `macros.vibe` helpers including `vibe:ast-list` nesting)
- `test/macro_ast_ref_shape.vibe`, `test/run_test.sh`
