# Linear macro pattern matching and seed release tooling

**Date**: 2026-03-23  
**Model**: Cursor agent (GPT-5.2)  
**Context**: Implemented linear pattern matching for `syntax-rules` macros; fixed self-host parse regression; added seed release automation while keeping the **default** bootstrap tag at `v0.0.1-seed` until `v0.0.2-seed` exists on GitHub.

## Session overview

### Macro expander (`kernel/expander.vibe`)

1. **Parse error fix**: Self-host compile failed with `unexpected ) (too many closing parens)`. The opening `let*` in `expander_atoms_equal` is a **direct** child of `llvm:define-function` (not under `llvm:label`), so its body must end with `))` (close `llvm:br`, close `let*`), not `)))`. Removed one stray `)` after `(llvm:br both_atoms 'cmp_lens 'no)`.

2. **`expander_expand_expr`**: Full expansion using one outer `let*` (pattern aligned with `codegen_get_type`): `bindings_slot` and `template_slot` allocas; labels inside that body. Flow: null → null; non-list → expr; list with atom car → macro lookup → match → substitute → recursive expand; else expand car/cdr. Added `llvm:declare-function` for self-recursion.

3. **Tests**: `./build.sh test` passes, including `macro_hello.vibe` (exit 42) with `use`, `add-of`, `ret`.

### Seed release workflow

4. **Default seed**: After **`v0.0.2-seed`** existed on GitHub, `build.sh` default **`SEED_TAG`** was set to **`v0.0.2-seed`**. Use **`VIBE_SEED_TAG=v0.0.1-seed`** for older trees.

5. **`./build.sh release-seed [tag]`** (default tag `v0.0.2-seed`): runs tests, copies `build/bin/vibe_kernel` to `build/release/vibe_kernel_seed`, strips (Darwin/Linux), then `gh release create` or `gh release upload --clobber`. Uses `doc/release-notes/<tag>.md` when present. `GITHUB_REPOSITORY` overrides `vibe-scheme/vibe`.

6. **GitHub Action** `.github/workflows/release-seed.yml`: `workflow_dispatch` on `macos-14`, Homebrew LLVM, `./build.sh test`, strip, same `gh` create/upload logic. Documented limitation: only works in CI when the default seed can compile current `main`.

7. **Bootstrap docs**: `RELEASING.md`, `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, release notes for `v0.0.2-seed`.

### Documentation sync (public site + design)

8. **`doc/pages/index.html`**: “Macro system (unhygienic)” → **Partial** (new `.partial` style); “Kernel rewrite using macros” → **Next**; Resources link to `RELEASING.md`.

9. **`doc/design/macro-system.md`**: Phase 1 split into **implemented (v1)** vs **planned**; expander bullets match `expander.vibe`; Phase 2 intro notes v1 is enough to start some kernel macros.

10. **`doc/design/r7rs-compliance.md`**: `syntax-rules` and `define-syntax` → **Partial** with notes; implementation-order bullet 1 updated.

## Files touched (cumulative)

- `kernel/expander.vibe` — paren fix; `expander_expand_expr`; forward declare.
- `test/macro_hello.vibe` — parameterized macro examples.
- `build.sh` — `SEED_TAG` default `v0.0.1-seed`; `release-seed`; `strip_seed_binary`.
- `RELEASING.md`, `doc/release-notes/v0.0.2-seed.md`.
- `.github/workflows/release-seed.yml`.
- `README.md`, `AGENTS.md`, `CONTRIBUTING.md`.
- `doc/pages/index.html`, `doc/design/macro-system.md`, `doc/design/r7rs-compliance.md`.

## Notes

- Wrong-arity macro calls fail match and recurse into list children.
- **`v0.0.2-seed`** was published via `./build.sh release-seed v0.0.2-seed` (GitHub release + asset). Default `SEED_TAG` in `build.sh` and primary doc links use **`v0.0.2-seed`**.
