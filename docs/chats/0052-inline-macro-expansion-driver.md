# Chat 0052: Inline top-level macro expansion in the driver

**Date**: 2026-03-20  
**Model**: Composer 2 (Cursor agent)  
**Context**: Implement the shortest path to a working simple substitution (unhygienic) macro: expand each top-level form in the parse loop before kernel dispatch, and fix `define-syntax` parsing so `syntax-rules` is read from the correct AST shape.

## Summary

1. **`kernel/main.vibe` — driver**
   - Added persistent macro environment: `macro_env_head` (`alloca` + null init in `after_free` alongside `exprs_list`).
   - After each successful `parse_expr`, call `expander_process_one(form, macro_env_head)`:
     - `null` result → `define-syntax` registered only → branch to `parse_loop`.
     - Non-null → store expanded AST in `ast_ptr`, then run existing `process_ast` dispatch (so `llvm:define-function` bodies see expanded subtrees).
   - `generate_code` passes `exprs_list` directly to `codegen_main` (removed `expander_expand_top_level`).
   - Forward declaration: `expander_process_one`; removed unused `expander_expand_top_level` declaration from `main.vibe`.

2. **`kernel/expander.vibe` — `expander_parse_simple_macro`**
   - **Bug fix**: For `(define-syntax <name> (syntax-rules ...))`, `form_cdr_cdr` is a **wrapper cons** whose **car** is the `(syntax-rules ...)` list. The code previously treated that cons cell as `syntax-rules`, so `sr_cdr` was always null and parsing failed. Macros never registered; `define-syntax` fell through to generic expansion and landed on `exprs_list`, producing a duplicate `main` with `codegen_main`.
   - Unwrap via `wrapper` → `sr = car(wrapper)` in each clause, with small helper labels (`get_syntax_rules_sr`, `get_clauses_sr`, etc.).

3. **`test/run_test.sh`**
   - `macro_hello`: expect exit code `42`; count compile/link/exit failures as `FAIL`.
   - Guard executable run with `if ./test/macro_hello.exe` / `else MACRO_EXIT=$?` so `set -e` does not treat exit `42` as script failure.

4. **`test/macro_hello.vibe`**
   - Updated header comments to reflect current behavior.

## Verification

- `./build.sh build` — self-host succeeds.
- `./build.sh test` — `hello_world` and `macro_hello` both PASS.
- `vibe_kernel test/macro_hello.vibe -o /tmp/macro_hello.ll` — single `define i32 @main()` with `ret i32 42`.

## Related

- Plan: inline expansion in the parse/codegen loop (visitor-style), no whole-file AST buffer.
- Prior: `docs/chats/0051-simple-form-substitution-macros.md`, `0050-macro-expander-foundation.md`.
- `expander_expand_top_level` remains in `expander.vibe` but is unused by the driver (optional cleanup later).
