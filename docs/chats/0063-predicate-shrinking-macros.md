# Chat 0063: Predicate-shrinking macros and a small semantic vocabulary

**Date**: 2026-05-09  
**Model**: Claude Code (claude-opus-4-7[1m])  
**Human Navigator**: Joshua Ballanco (josh.ballanco@manhattanmetric.com)  
**Context**: Continue the macro-ification of the self-hosted compiler. Chat 0062 introduced **`vibe:label-branch`** and collapsed 114 label-then-branch sites, leaving **372 multi-binding `let*+br` sites untouched** — the commit message earmarked them as "awaiting smaller predicate-shrinking macros that let those uses collapse into the single-binding shape." This session designs and applies that next layer of macros, deliberately framed at the **domain level** (predicate held? strings matched? lexer at EOF?) rather than the **i32 ABI level** (i32 == 1 / i32 == 0) that the existing **`vibe:i32-one?`** / **`vibe:i32-zero?`** / **`vibe:i32-nonzero?`** primitives expose.

## Session overview

Introduced **six new semantic-vocabulary macros** — five predicate forms and one lexer accessor — and applied them across the kernel. After the sweep, **zero `vibe:i32-one?` calls remain in caller code** (only inside macros.vibe, where they are now internal building blocks). Net **−191 lines** in `kernel/` with the kernel still **self-hosting at a fixed point** (gen1 from prior seed → gen2 byte-equal to gen1) and all 6 tests passing.

### New semantic-vocabulary macros (`kernel/macros.vibe`)

- **`vibe:pred?`** — true when **`(llvm:call FN ARGS...)`** — a strict 0/1 C-bool predicate function — returned 1. Replaces the bare `(let* ((flag (llvm:call FN ARGS)) (ok (vibe:i32-one? flag))) ...)` boilerplate. Used **99×** across the kernel.
- **`vibe:str-match?`** — true when **`strncmp(a, b, len)`** returned 0 (first `len` bytes match). Used **3×**.
- **`vibe:ast-str-eq?`** — composite of length-equal AND strncmp-zero for two AST atoms. Used **4×**.
- **`vibe:lex-eof?`** — true when the lexer is at end-of-input (wraps **`(vibe:i32-nonzero? (llvm:call lex_is_eof lexer))`**). Used **10×**.
- **`vibe:parse-check?`** — true when the parser's current token matches the requested kind. Used **4×**.
- **`vibe:lex-char`** — read the lexer's current char as i32 (zext from the i8 returned by **`lex_current_char`**). Used **19×**.

### Naming progression

The first plan called the call-and-check combiner **`vibe:call-i32-one?`**. Josh pushed back: "an i32 parameter having a value of 1 feels like a magic number that should be avoided unless it's truly necessary." The data confirmed the concern was real:

- All **98** `vibe:i32-one?` sites in `kernel/expander.vibe` check the result of strict 0/1 C-bool predicate functions (`expander_is_atom_node`, `expander_is_list_node`, `expander_is_ellipsis_id`, `expander_atoms_equal`, etc.).
- `vibe:i32-zero?` was **overloaded** between two unrelated concepts: "predicate returned false" (1 site) and "strncmp matched" (3 sites).
- `vibe:i32-nonzero?` was exclusively used for C-truthy functions (`lex_is_eof`, `lex_is_delimiter`, `parse_check`).

Settled on naming the **concept** ("a predicate function returned true", "strings matched", "lexer at EOF") rather than the implementation. The low-level `vibe:i32-one?` / `-zero?` / `-nonzero?` primitives **stay** but are pushed back to "internal building blocks used inside macros.vibe definitions" — the magic number is encapsulated, not eliminated.

### Sweep across the kernel

Per the audit discipline established in chat 0062: for each candidate site, confirm the intermediate `let*` bindings feed only the predicate before inlining.

| target | sites | files |
|---|---|---|
| **`vibe:pred?`** | 99 | `expander.vibe` (heaviest), `parser.vibe` |
| **`vibe:lex-char`** | 19 | `lexer.vibe` |
| **`vibe:lex-eof?`** | 10 | `lexer.vibe` |
| **`vibe:parse-check?`** | 4 | `parser.vibe` |
| **`vibe:ast-str-eq?`** | 4 | `expander.vibe` (incl. CFG restructure of `expander_atoms_equal` and `expander_lookup_macro` that merged separate `cmp_lens`/`cmp_str` labels) |
| **`vibe:str-match?`** | 3 | `expander.vibe` |
| **new `vibe:label-branch` sites** | +38 | scattered (opportunistic Phase 3 pass) |

### Self-host validation

- Phases 1–3 (the conservative regime): all bitcode hashes were **byte-identical** to the f4b48e7 baseline at every checkpoint.
- Phases 4–6 (looser regime — multi-call AND patterns; non-adjacent call+icmp pairs in lexer loops; CFG restructure with `vibe:ast-str-eq?`): build succeeds, 6/6 tests pass.
- **Self-host rotation**: saved the kernel built from prior sources as `gen1`; touched all `kernel/*.vibe` and rebuilt; the `gen2` binary was **byte-equal** to `gen1` (`cmp` returned no diff). Confirms the new kernel can compile its own sources to itself — the strongest self-host check.

### Doc-string discipline (follow-up cleanup)

Josh observed that "all the information needed to understand a function or macro should, eventually, be captured in the doc string that will (future feature) be registered with the symbol." Audited and folded:

- **`kernel/macros.vibe`**:
  - Inline ASTNode field table (8 lines of `;;` comments enumerating index/type per field) folded into **`vibe:ast-ref`**'s and **`vibe:ast-addr`**'s doc strings.
  - **`cond_val`** internal-temp warning folded into **`vibe:label-branch`** doc.
  - "Semantic test forms" section header dropped — rationale lives in each macro's own doc.
  - Duplicate **`vibe:ast-str-eq?`** multi-evaluation warning dropped (already in the doc).
  - File-header comment on `define-vibe-syntax` (build-prefix and doc-string-stripping behavior) **kept** — `define-vibe-syntax` itself is built on plain `define-syntax` and has no doc-string slot, so the comment is the only available place.
- **`kernel/codegen.vibe`**:
  - 11-line section header on codegen DSL handler templates dropped.
  - Internal-temp warnings folded per-macro: **`vibe:eval-and-store`** documents `evald_val`/`evald_null`; **`vibe:resolve-type-and-store`** documents `resolved_node`/`resolved`/`resolved_null`.
  - **`vibe:define-binop`** / **`vibe:define-cast2`** / **`vibe:define-cast3`** docs now enumerate the labels and locals each generates.

### Label-nesting cleanup (follow-up)

Josh flagged a hand-fix to **`codegen_collect_string_constants_from_args`**: nested `gen_constant` → `next_arg` → `done` labels flattened to siblings (none referenced bindings from outer let* scopes, so nesting was pure cosmetic). Memorialized the principle:

> **Nest a label only when its body references a `let*` binding from an enclosing scope.** Otherwise, sibling layout is preferred — same IR, less indentation, easier to reorder.

Ran a paren-aware scan across the files we touched. One genuinely-nested case in updated code (**`expander_process_one`** at line 1477) is **justified** — its inner `expand_add_installed_macro` and `expand_ret` both reference `expanded` from the outer let*, and per `AGENTS.md`'s rule (`let*` introduces scope; `llvm:label` does not), flattening would break visibility.

Found and fixed one obvious sibling case in code we touched: **`codegen_collect_string_constants`** (the function literally above the one Josh fixed) had the same `check_call` → `next_expr` → `done` nesting with no scope dependencies. Flattened.

Pre-existing nesting elsewhere — **`codegen_append`** (line 320), the big string-escape loop at codegen.vibe line 3762, and a couple of `util.vibe` digit-loop functions — flagged for a future cleanup pass; not touched this session.

## Decisions and notes

- **"Semantic vocabulary" framing won over a one-macro fix.** Three options were on the table: (A) add **`vibe:pred?`** alone and leave existing primitives untouched; (B) rename the i32 primitives; (C) build a small vocabulary of domain-named test forms (`vibe:pred?`, `vibe:str-match?`, `vibe:lex-eof?`, etc.) and let the i32 primitives stay as internal building blocks. Josh chose (C). Result: caller code reads at the domain level; magic-number primitives are encapsulated.
- **Byte-identical regime, then loosen.** First three phases held to byte-identical bitcode (the discipline from chat 0062), which constrained rewrites to (i) call+icmp adjacency and (ii) preserved let*-binding order. After Phase 3, Josh confirmed "We don't need to be byte-identical, so long as we're still self-hosting and pass all tests." Phases 4–7 then: collapsed multi-call AND patterns (3 sites in expander.vibe), used **`vibe:lex-eof?`** in non-adjacent let* sites in lexer loops, and restructured `expander_atoms_equal` / `expander_lookup_macro` to use **`vibe:ast-str-eq?`** in a single label rather than the prior `cmp_lens`+`cmp_str` two-label CFG.
- **`vibe:ast-str-eq?` is unhygienic on its arguments.** The macro re-references `value` and `value_len` of each node multiple times via expansion; pass plain identifiers, not expressions with side effects. Documented in the doc string.
- **2 sites of `vibe:i32-zero?` on `parse_check`** in parser.vibe (lines 113-114, 144-145) are semantically `(not (vibe:parse-check? ...))`. A `vibe:not-parse-check?` macro for 2 sites isn't worth defining; left as-is.
- **`lex_is_delimiter`** has only 1 site — not worth a `vibe:lex-delim?` macro; left expressed via `vibe:i32-nonzero?` directly.
- **372 multi-binding `let*+br` sites from chat 0062**: most collapse via this session's macros — `vibe:pred?` covers the bulk, `vibe:lex-char` and `vibe:lex-eof?` cover the lexer subset, `vibe:str-match?` and `vibe:ast-str-eq?` cover the strncmp/atom-equal subset. The chat 0062 figure was conservative; net new `vibe:label-branch` sites this session: **38**.

## Final kernel line counts

| file | start (post-0062) | end | delta |
|---|---|---|---|
| **`kernel/codegen.vibe`** | 5807 | 5814 | +7 (doc strings) |
| **`kernel/expander.vibe`** | 1689 | ~1500 | ~−190 |
| **`kernel/lexer.vibe`** | 614 | ~570 | ~−44 |
| **`kernel/macros.vibe`** | 228 | 267 | +39 |
| **`kernel/parser.vibe`** | 302 | 299 | −3 |
| **kernel total** | **10175** | **~9984** | **−191** |

(Per `git diff --shortstat`: 5 files changed, 427 insertions, 618 deletions — net −191.)

## Files modified

- **`kernel/macros.vibe`** (+39 lines) — added **`vibe:pred?`**, **`vibe:str-match?`**, **`vibe:ast-str-eq?`**, **`vibe:lex-eof?`**, **`vibe:parse-check?`**, **`vibe:lex-char`**; folded the inline ASTNode field table and `cond_val` internal-temp warning into the relevant doc strings.
- **`kernel/expander.vibe`** (~−190 net) — rewrote 95 sites to use **`vibe:pred?`**; restructured **`expander_atoms_equal`** and **`expander_lookup_macro`** to use **`vibe:ast-str-eq?`** (CFG simplified — separate `cmp_lens` + `cmp_str` labels merged into one); applied **`vibe:str-match?`** to 3 strncmp sites; applied opportunistic **`vibe:label-branch`** to newly-eligible single-binding sites.
- **`kernel/lexer.vibe`** (~−44 lines) — replaced 19 `(char (call lex_current_char) ; char_int (zext ...))` pairs with **`vibe:lex-char`**; replaced 7 `(is_eof ...) (eof_bool (vibe:i32-nonzero? is_eof))` pairs with **`vibe:lex-eof?`**; flattened 1 `check_closing` label via **`vibe:label-branch`**.
- **`kernel/parser.vibe`** (−3 lines) — replaced 4 `parse_check`+`vibe:i32-nonzero?` pairs with **`vibe:parse-check?`**; one **`vibe:pred?`** call.
- **`kernel/codegen.vibe`** (+7 lines net) — folded the section header on codegen DSL handler templates into per-macro doc strings (each now documents its internal temps and labels); flattened sibling-able label nesting in **`codegen_collect_string_constants`** to match Josh's fix in **`_from_args`**.
- **`docs/chats/0063-predicate-shrinking-macros.md`** — this document.
