# Chat 0056: Kernel AST / void-ptr null and some macros

**Date**: 2026-03-25 — 2026-03-26  
**Model**: Cursor Agent (Composer 2)  
**Context**: Implement shared `syntax-rules` helpers in `kernel/macros.vibe` and adopt them across the compiler kernel; follow up on `define-vibe-syntax`, expander/driver top-level behavior, and design-doc alignment.

## Overview (pointer / icmp macros)

- Extended **`kernel/macros.vibe`** with **`vibe:ast-some?`**, **`vibe:void-ptr-null?`**, and **`vibe:void-ptr-some?`** (alongside existing **`vibe:ast-null?`**), each a single linear `syntax-rules` clause expanding to the matching `llvm:icmp` + `llvm:const-null` for `|%ASTNode*|` or `|i8*|`.
- Replaced raw **`llvm:icmp 'eq` / `'ne` … `const-null`** forms in **`kernel/codegen.vibe`**, **`kernel/util.vibe`**, **`kernel/main.vibe`**, **`kernel/dsl.vibe`**, and **`kernel/parser.vibe`** so that only **`kernel/macros.vibe`** retains those icmp templates (verified with `rg` on `kernel/*.vibe`).
- **Inlined** a few **`let*`** bindings that existed only to name a single null/some check used once in **`llvm:br`**: **`parse_int_from_ast`**, **`extract_quoted_atom`** (including **`quoted_expr`**), and **`codegen_append_top_level_exprs`** entry **`llvm:label 'entry`**. Broader automated folding was abandoned after a first pass corrupted `let*`/`llvm:label` structure when **`let*`** bodies contained multiple forms (not only **`llvm:br`**).
- Updated **`docs/design/macro-system.md`**: document the four macros, note **`kernel/macros.vibe`** + concat prefix, add a **deferred** bullet for **`vibe:ast-kind-atom?` / `vibe:ast-kind-list?`** as a motivator for **multi-clause `syntax-rules`**.

## Overview (define-vibe-syntax, top-level expansion, docs)

- **`define-vibe-syntax`** is a plain **`define-syntax`** macro: **`(define-vibe-syntax name _doc transformer)`** expands to **`(define-syntax name transformer)`**. Expression-level re-expansion already works; the gap is **top-level**: **`expander_process_one`** only installs macros when the **surface** form is **`define-syntax`**. If the parsed form is **`define-vibe-syntax`**, **`expander_expand_expr`** can produce **`(define-syntax …)`**, but that result is returned to the driver and is **not** re-dispatched through the macro-install path, so the inner macro never enters the environment in one step (bootstrap / seed issue for prelude forms written only as **`define-vibe-syntax`**).
- **Bootstrap-safe prelude**: the four **`vibe:*`** helpers use top-level **`define-syntax`** plus **`;; Registry (planned): …`** comment lines (same strings as the planned macro doc registry). **`define-vibe-syntax`** remains in the file for callers who want the doc subform at the syntax level once **install-after-expand** exists.
- **`docs/design/primitive-forms.md`**: sync registry table and narrative with **`define-syntax` + comments** in the kernel prelude; clarify **`define-vibe-syntax`** vs bootstrap.
- **`docs/design/macro-system.md`**: add a **Phase 1 roadmap** bullet for **top-level macro definitions produced by expansion (“macros defining macros”)** — planned **generic** rule: after expansion, if the tree matches the same simple **`define-syntax` / `syntax-rules`** shape, install it (not name-special-cased). **Near-term priority** together with **multiple `syntax-rules` clauses** (already on the list).
- **No** expander special-case for **`define-vibe-syntax`** by name; **`expander_process_one`** stays the simple **`define-syntax`** vs **`expand`** split until the generic follow-up is implemented.

## Decisions (follow-up)

- Prefer **`define-syntax`** in the shared prelude until install-after-expand exists; avoid seed-only or name-specific expander hacks.
- Describe the future fix as **generic** (registrable **`define-syntax`** shape after **`expand_expr`**).

## Verification

- `./build.sh build` and `./build.sh test` (hello_world, macro_hello) succeed after the prelude / doc alignment.

## Files touched

| File | Change |
|------|--------|
| `kernel/macros.vibe` | `vibe:*` helpers; **`define-vibe-syntax`** macro; prelude uses **`define-syntax`** + registry comments |
| `kernel/codegen.vibe` | Macro adoption + targeted br inline in `codegen_append_top_level_exprs` |
| `kernel/util.vibe` | Macro adoption + br inlines in quoted/int helpers |
| `kernel/main.vibe` | Macro adoption |
| `kernel/dsl.vibe` | `vibe:void-ptr-null?` for buffer check |
| `kernel/parser.vibe` | `vibe:void-ptr-null?` for normalize-type path |
| `docs/design/macro-system.md` | Kernel macro inventory, deferred ast-kind note, **macros-defining-macros** + near-term priority |
| `docs/design/primitive-forms.md` | Registry / prelude / **`define-vibe-syntax`** story |

## Related

- `docs/chats/0055-kernel-concat-prefix-and-darwin-ffi.md` (shared prefix including `macros.vibe`)
- `docs/chats/0054-macro-docs-and-first-kernel-macro.md` (`vibe:ast-null?` introduction)
- `kernel/expander.vibe` — `expander_process_one`, `expander_expand_expr` (planned generic install-after-expand)
- `kernel/main.vibe` — `macro_expand` / `process_ast` pipeline
