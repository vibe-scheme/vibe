# Chat 0054: Macro documentation notes and first kernel convenience macro

**Date**: 2026-03-24  
**Model**: Cursor Composer 2  
**Context**: Document design conclusions from discussion of macro docstrings, `define-vibe-syntax`, per-file macro scope, and deferred R7RS libraries; introduce the first kernel `syntax-rules` simplification (`vibe:ast-null?` in `kernel/expander.vibe`).

## Session overview

1. **Design documentation (`docs/design/primitive-forms.md`)**  
   Added a subsection under `define-syntax` / `syntax-rules` covering:
   - Why docstrings cannot live inside `syntax-rules` as extra clauses.
   - R7RS-safe options such as `(begin "…" (syntax-rules …))` as the transformer spec.
   - A portable user-level `define-vibe-syntax` sketch that expands to `define-syntax` and omits the doc from the template.
   - Planned future Vibe `define-vibe-syntax` as an expander-handled form (name + docstring + transformer + registry), not implemented in this session.
   - Current reality: one kernel `.vibe` file per bitcode compile unit; macro environment is per file.
   - R7RS libraries / module design explicitly deferred until the kernel is farther along and work shifts to full R7RS.
   - Future direction (document only): multiple source paths as one logical compilation unit (e.g. driver accepts a file list and concatenates sources before parse/expand) as a possible way to share macros without settling library semantics.

2. **Macro system doc (`docs/design/macro-system.md`)**  
   New subsection “Kernel convenience macros (incremental)” describing `vibe:ast-null?`, per-file macro scope, deferred libraries, and pointer to `primitive-forms.md` for the multi-file-unit note.

3. **First kernel macro (`kernel/expander.vibe`)**  
   - Defined file-local `(define-syntax vibe:ast-null? (syntax-rules () ((vibe:ast-null? ptr) (llvm:icmp 'eq ptr (llvm:const-null |%ASTNode*|)))))` after string constants, with a short comment referencing `primitive-forms.md`.  
   - Pattern variable `ptr` avoids clashing with uses of `p` in the rest of the file when bulk-replacing expansions.  
   - Replaced 37 occurrences of `(llvm:icmp 'eq <atom> (llvm:const-null |%ASTNode*|))` below the macro with `(vibe:ast-null? <atom>)`, leaving the macro template as the sole remaining `llvm:icmp … const-null` for `ASTNode*`.

4. **Verification**  
   `./build.sh build` and `./build.sh test` succeeded (hello_world, macro_hello).

## Key decisions

- Document `define-vibe-syntax` and macro registry as **intent** only; no expander or registry implementation this session.
- No multi-file concatenation or CMake/driver changes; libraries remain **out of scope** for now.
- First convenience macro is intentionally **small and local** to `expander.vibe`; `codegen.vibe` left for a follow-up.

## Files touched

| File | Change |
|------|--------|
| `docs/design/primitive-forms.md` | Macro documentation subsection |
| `docs/design/macro-system.md` | Kernel convenience macros + future multi-file pointer |
| `kernel/expander.vibe` | `vibe:ast-null?` + replacements |

## Related documents

- `docs/design/macro-system.md` — Phase 1 expander behavior and roadmap  
- `docs/design/primitive-forms.md` — primitives and docstring convention for `define`
