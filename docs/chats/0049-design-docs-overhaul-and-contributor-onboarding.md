# Chat 0049: Design Docs Overhaul and Contributor Onboarding

**Date**: 2026-03-17
**Model**: Claude claude-4.6-opus-high-thinking (Cursor Agent)
**Context**: Post-self-hosting session establishing Vibe's forward-looking design documentation, contributor workflow, and public-facing site.

## Overview

This session marks the transition from "building the compiler" to "building the language." With Vibe fully self-hosted, we established the foundational documentation for Vibe's goals, analyzed the R7RS primitive/macro boundary, defined the macro-first implementation strategy, set up contributor infrastructure, and created the project's public landing page.

## Work Completed

### 1. Design Documentation Overhaul

**Archived obsolete documents** (added archival headers, no content changes):
- `docs/design/bootstrap-plan.md` — historical bootstrap compiler plan
- `docs/design/narrow-bootstrap-goal.md` — historical hello-world milestone
- `docs/design/ffi-llvm-integration.md` — historical FFI/LLVM integration design

**Updated still-relevant documents:**
- `docs/design/cross-compilation-plan.md` — removed stale `bootstrap/codegen.ll` sync reference and `types.ll` mention
- `docs/design/llvm-dsl-deferred-methods.md` — updated implementation pattern to reference only `kernel/dsl.vibe` and `kernel/codegen.vibe`

**Created three new foundational documents:**
- `docs/design/vision.md` — Vibe's mission (human+AI co-reasoning about programs), two goals (R7RS via macros, binding registry), downstream possibilities (conversational programming, verified transformation, self-modifying runtime), current state, and architecture layer diagram
- `docs/design/primitive-forms.md` — analysis of why `define`, `lambda`, `if`, `set!`, `quote`, and `define-syntax`/`syntax-rules` must be primitive; full derived forms catalog; mapping to LLVM generation patterns; docstring design note
- `docs/design/r7rs-compliance.md` — section-by-section tracker for all of R7RS Small (sections 4-6 + standard libraries), with macro-first implementation order

### 2. Macro System Design Document

Created `docs/design/macro-system.md` capturing:
- **Strategic rationale**: Why macros before primitives — the compiler already has AST infrastructure; macros need no runtime value representation; the bootstrapping opportunity (implement in DSL, self-host, rewrite kernel with macros, then implement primitives)
- **Phase 1**: Minimal unhygienic `syntax-rules` — pattern matching + template substitution, sufficient for kernel convenience macros
- **Phase 2**: Kernel rewrite using macros (`with-field`, `if-null`, `string-match`, `define-dsl-binop`, `alist-lookup`)
- **Phase 3**: Full hygienic `syntax-rules` for R7RS compliance
- **Architectural changes**: New `expander` phase between parser and codegen; extraction of shared utilities from `codegen.vibe` into `kernel/util.vibe`; integration with `main.vibe`

Updated `docs/design/r7rs-compliance.md` implementation strategy section to reference the macro-first approach.

### 3. Contributor Onboarding

**Created `CONTRIBUTING.md`:**
- Development philosophy (conversation-driven, every PR must include a chat document)
- PR requirements: `0000-descriptive-name.md` placeholder prefix, one session per PR
- Getting started guide with build instructions and doc pointers
- Code standards summary

**Created `.github/workflows/renumber-chat.yml`:**
- GitHub Action triggered on PR merge to `main`
- Finds chat files with `0000-` placeholder prefix
- Determines next sequential number from existing chats
- Renames and commits with `[bot] Renumber chat document`

### 4. GitHub Pages Site

**Created `docs/pages/index.html`:**
- Single-page static site, no JS, no build tools
- Hero section introducing Vibe
- "The Problem with Vibe Coding" argument: the problem isn't the vibe, it's the code — Scheme's transparency makes AI collaboration fundamentally more powerful
- Two goals section (R7RS via macros, binding registry)
- Architecture layer diagram adapted for web
- Current status grid (self-hosted: done, macro system: next, etc.)
- Resource links to all design docs, chats, contributing guide, and repo
- Dark-mode friendly with system font stack

### 5. AGENTS.md Updates

- Replaced outdated `define-bitcode` core principle with `llvm:define-function` DSL primitives description
- Added docstring convention as core principle #4
- Updated directory structure to include `docs/pages/`
- Replaced `define-bitcode-*` Key Concepts section with current DSL primitives
- Removed obsolete "Future" sections (`define-bitcode-ffi-function`, implicit main insertion)
- Updated Next Steps to macro-first roadmap
- Updated Documentation Structure with new design docs and GitHub Pages
- Updated How to Contribute to reference `CONTRIBUTING.md`
- Added GitHub Pages maintenance as end-of-session step

### 6. Additional Items

- Added docstring design note to `docs/design/primitive-forms.md` (Python-style first-string-in-body convention)
- Created `LICENSE` — BSD 2-Clause, copyright Joshua Ballanco and Vibe Scheme Contributors

## Key Decisions

1. **`define` must be primitive** — cannot be a macro because (a) it's not an expression, (b) top-level binding creation is irreducible, (c) internal definitions require body-level restructuring. R7RS Section 7.3 confirms this.

2. **Macros before primitives** — the compiler already has AST infrastructure; macros avoid premature decisions about value representation, closures, and GC; the bootstrapping cycle (implement macros → rewrite kernel → implement primitives with macros) is the most productive path.

3. **Unhygienic first** — DSL-level macros generate LLVM names, not Scheme bindings, so variable capture is not a concern. Hygiene is the hardest part; deferring it gets immediate value.

4. **Python-style docstrings** — first string literal in a multi-expression `define` body serves as documentation. Syntactically valid R7RS. Compiler can detect it via AST node type tags.

5. **`kernel/util.vibe` extraction** — shared AST utilities (`create_cons`, `create_string_node`, etc.) will be extracted from `codegen.vibe` so both `codegen.vibe` and the new `expander.vibe` can use them.

6. **Chat renumbering via GitHub Action** — contributors use `0000-` placeholder; action renumbers on merge. Avoids conflicts from multiple PRs competing for the same number.

## Files Created
- `docs/design/vision.md`
- `docs/design/primitive-forms.md`
- `docs/design/r7rs-compliance.md`
- `docs/design/macro-system.md`
- `docs/pages/index.html`
- `.github/workflows/renumber-chat.yml`
- `CONTRIBUTING.md`
- `LICENSE`
- `docs/chats/0049-design-docs-overhaul-and-contributor-onboarding.md` (this file)

## Files Modified
- `docs/design/bootstrap-plan.md` (archival header)
- `docs/design/narrow-bootstrap-goal.md` (archival header)
- `docs/design/ffi-llvm-integration.md` (archival header)
- `docs/design/cross-compilation-plan.md` (removed bootstrap references)
- `docs/design/llvm-dsl-deferred-methods.md` (removed bootstrap references)
- `AGENTS.md` (comprehensive update)

## Related Documents
- `docs/design/vision.md` — Vibe's mission and goals
- `docs/design/primitive-forms.md` — primitive vs. derived form analysis
- `docs/design/macro-system.md` — macro-first implementation strategy
- `docs/design/r7rs-compliance.md` — R7RS Small compliance tracker
