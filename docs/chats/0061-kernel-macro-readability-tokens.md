# Chat 0061: Kernel macro readability (tokens, chars, i32 flags, quote kind)

**Date**: 2026-04-11  
**Model**: Cursor Composer 2  
**Context**: Continue macro-ifying the self-hosted compiler for readability and intent; align public and design docs with the new shared helpers.

## Session overview

Extended **`kernel/macros.vibe`** with small **`syntax-rules`** helpers so lexer, parser, expander, util, and codegen stop repeating magic numbers and C-style **`i32`** truthiness patterns. Refactored call sites to use those names. Documented everything in **`docs/design/macro-system.md`**, **`docs/design/primitive-forms.md`** (planned registry table), **`docs/pages/index.html`** (current status), and **`kernel/types.vibe`** (AST **`type`** field semantics).

**Explicit non-goal for later**: Large line-count reduction in codegen dispatch is deferred until something like a **dispatch macro** (or data-driven table) is viable under the current expander.

### New and updated macros (`kernel/macros.vibe`)

- **`vibe:i32-zero?`**, **`vibe:i32-one?`**, **`vibe:i32-nonzero?`** — common **`icmp`** shapes for predicates, **`strncmp`**, **`lex_is_eof`**, **`parse_check`**, etc.
- **`vibe:token-lit`** / **`vibe:token-type?`** — single source of truth for lexer **`Token.type`** (eof through bytevector, dot **11**, error **12**, …).
- **`vibe:ast-type-lit`** — parser **`ASTNode.type`** stores: atom **0**, list **1**, quote wrapper **2**.
- **`vibe:char-eq?`** — named ASCII code units (**`squote`** vs token **`quote`** to avoid confusion).
- **`vibe:char-digit?`** — **`'0'`–`'9'`** range on **`i32`** code units.
- **`vibe:node-kind?`** — extended with literal **`quote`** (type field **2**), alongside **`atom`** and **`list`**.

### Refactors by module

| File | Changes |
|------|---------|
| **`kernel/expander.vibe`** | Mechanical use of **`vibe:i32-one?`** / **`vibe:i32-zero?`** (and related) for **`i32`** boolean idioms after helper calls. |
| **`kernel/lexer.vibe`** | Token stores and comparisons use **`vibe:token-lit`** / implied intent; whitespace, delimiters, **`#u8(`** peek, and string/char loops use **`vibe:char-eq?`**, **`vibe:char-digit?`**, **`vibe:i32-nonzero?`**. |
| **`kernel/parser.vibe`** | **`parse_check`** and token-type branches use token macros; AST type stores use **`vibe:ast-type-lit`**; **`%`** normalization uses **`vibe:char-eq?`** **`percent`**; boolean branches use **`vibe:i32-*`**. |
| **`kernel/util.vibe`** | **`extract_quoted_atom`** uses **`vibe:node-kind?`** for quote wrapper and inner atom; **`parse_int_string`** uses **`vibe:char-digit?`**. |
| **`kernel/codegen.vibe`** | Quote-wrapper detection uses **`(vibe:node-kind? … quote)`** instead of raw **`type == 2`**. |
| **`kernel/types.vibe`** | Comment documents **`ASTNode.type`** **2** = quote wrapper. |
| **`docs/design/macro-system.md`** | AST layering bullet and macro table updated for new helpers and **`quote`** on **`node-kind?`**. |
| **`docs/design/primitive-forms.md`** | Planned registry table rows updated / added for new **`vibe:*`** names. |
| **`docs/pages/index.html`** | “Kernel rewrite using macros” set to **Partial**; macro blurb lists new helper families. |

### Testing

- **`./build.sh test`**: all tests passed (6/6) after codegen quote-path updates.

## Decisions and notes

- **`vibe:node-kind?`** **`quote`** was chosen over a separate predicate so one form covers all **`ASTNode.type`** discriminants the parser emits.
- **`vibe:token-lit quote`** is the **token** kind (**7**); **`vibe:ast-type-lit quote`** / **`node-kind? … quote`** is the **AST** wrapper (**2**). Names are documented to avoid mixing them up.

## Suggested commit message

```
Add kernel macros for tokens, chars, and i32 flags; extend node-kind? quote

Introduce vibe:token-lit/token-type?, vibe:ast-type-lit, vibe:char-eq?/
char-digit?, and vibe:i32-zero?/one?/nonzero? in macros.vibe. Extend
vibe:node-kind? with a quote clause (AST type 2). Refactor lexer, parser,
expander, util, and codegen to use them; document in macro-system.md,
primitive-forms.md, types.vibe, and GitHub Pages status.

Tests: ./build.sh test (6 passed).
```

## Related references

- **`docs/design/macro-system.md`** — authoritative macro table and Phase 1 status.
- **`docs/design/primitive-forms.md`** — planned **`vibe:*`** registry text.
- **`kernel/macros.vibe`** — implementations and doc strings on **`define-vibe-syntax`** forms.
