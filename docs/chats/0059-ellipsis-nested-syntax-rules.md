# Session: Ellipsis and nested `syntax-rules` patterns

**Date**: 2026-03-27  
**Model**: Cursor agent (Composer 2)  
**Context**: Implement the plan for R7RS-aligned **`syntax-rules`** extensions: nested list subpatterns after the keyword, final **`...`** in patterns (including **`(x y ...)`** greedy tail), ellipsis-bound variables as proper-list ASTs, template replication/splicing for **`(subtemplate ...)`**, generalized validation (unique vars across subpatterns, **`...`** placement), **`test/macro_ellipsis_nested.vibe`** + **`run_test.sh`**, and design-doc updates. Self-host verified with two consecutive **`./build.sh build`** runs sandwiching **`./build.sh test`**. Same session: publish bootstrap seed **`v0.0.4-seed`** (so clean clones can compile ellipsis/nested macros), bump default **`SEED_TAG`** and related docs, and refresh **GitHub Pages** **`docs/pages/index.html`**.

## Overview

### Expander (`kernel/expander.vibe`)

- **Validation**: Generalized pattern validation beyond flat tails: recurse into nested lists; enforce unique pattern variables across the whole pattern; validate that **`...`** appears only as the ellipsis identifier immediately after a complete subpattern and ends the list tail (no non-final split-the-middle **`...`**).
- **Matching**: Replaced linear-only matching with a structure-aware matcher: nested **`car`/`cdr`** recursion with merged binding lists; final-segment ellipsis with right-anchored splitting for patterns like **`(kw x y ...)`**; ellipsis repetitions produce **proper list AST** values via **`create_cons`** for bound variables.
- **Substitution**: Extended template walk to detect terminal **`(subtemplate ...)`** and replicate/splice using ellipsis-bound variables at the appropriate depth.
- **Driver**: **`expander_expand_expr`** wired to pass ellipsis-slot metadata where needed for accumulation and substitution.

### Codegen fix (`kernel/codegen.vibe`)

- **`llvm:label`** AST is **`(llvm:label 'name expr …)`**. **`codegen_dsl_label`** / **`position_builder`** previously passed the full **`args` cdr** into **`codegen_eval_dsl_body`**, so the **quoted label name** was treated as the first body expression. That produced invalid IR for label blocks with multiple successors (e.g. expander helpers using **`llvm:br`** between blocks that only **`ret`**).
- **Fix**: **`label_body_for_eval_ptr`** plus small **`pb_*`** blocks: if the body is a list whose **`car`** is a quote node, skip it and evaluate the remainder; otherwise evaluate from **`body0`** as before.

### Expander IR robustness

- **`expander_ell_acc_init_elt`**: Refactored to **alloca + join** (single return after **`llvm:load`**) so both control-flow paths share one terminator shape, avoiding fragile codegen on multi-block **`ret`-only** successors.

### Tests and design docs

- **`test/macro_ellipsis_nested.vibe`**: **`pair-add-m`** with nested **`(a b)`**; **`sum-m`** with **`x y ...`**; exit **64** = **(4+5) + (10+20+25)**.
- **`test/run_test.sh`**: New macro canary block (Test 5), exit **64**.
- **`docs/design/macro-system.md`**: Implemented vs deferred (non-final **`...`**, template validation depth, expansion depth limit).
- **`docs/design/r7rs-compliance.md`**: **`syntax-rules`** marked partial with nested patterns + final ellipsis.

### Bootstrap seed **`v0.0.4-seed`** and GitHub Pages

- **`docs/release-notes/v0.0.4-seed.md`**: Rationale vs. **`v0.0.3-seed`** (kernels using ellipsis/nested patterns cannot bootstrap from v0.0.3); asset **`vibe_kernel_seed`**; older seeds summarized.
- **`build.sh`**: Default **`SEED_TAG`** **`v0.0.4-seed`**; **`release-seed`** default tag and help text aligned.
- **`RELEASING.md`**, **`AGENTS.md`**, **`README.md`**: Default seed narrative, links, when to use **`v0.0.3-seed`** / older seeds; seed table includes **`v0.0.4-seed`**; next example tag **`v0.0.5-seed`**.
- **`.github/workflows/release-seed.yml`**: Manual dispatch default **`v0.0.4-seed`**.
- **`./build.sh release-seed v0.0.4-seed`**: Published [v0.0.4-seed](https://github.com/vibe-scheme/vibe/releases/tag/v0.0.4-seed).
- **`docs/pages/index.html`**: “Macro expander today” reflects nested subpatterns, final **`...`**, and versioned seeds on GitHub Releases.

## Verification

- **`./build.sh build`**: success (compile with existing seed/self-hosted kernel).
- **`./build.sh test`**: all tests passed including **`macro_ellipsis_nested`**.
- **Second `./build.sh build`**: success (self-host with new expander + codegen).
- **Bootstrap from new seed**: removed **`build/bin/vibe_kernel`**, **`./build.sh build`** downloaded **`v0.0.4-seed`** and completed.

## Files touched

| File | Changes |
|------|---------|
| **`kernel/expander.vibe`** | Generalized validation, ellipsis matching, list bindings, template **`...`**, expander wiring |
| **`kernel/codegen.vibe`** | Label body skips leading quote for DSL eval in **`position_builder`** |
| **`test/macro_ellipsis_nested.vibe`** | New canary |
| **`test/run_test.sh`** | Register Test 5 |
| **`docs/design/macro-system.md`** | Capability and gap bullets |
| **`docs/design/r7rs-compliance.md`** | **`syntax-rules`** row / roadmap |
| **`docs/release-notes/v0.0.4-seed.md`** | New seed release notes |
| **`build.sh`** | Default **`v0.0.4-seed`** |
| **`RELEASING.md`**, **`AGENTS.md`**, **`README.md`** | Seed defaults and tables |
| **`.github/workflows/release-seed.yml`** | Dispatch default **`v0.0.4-seed`** |
| **`docs/pages/index.html`** | Current status / macro blurb |

## Notes

- **`...`** is matched as the string atom **`...`** (same convention as other pattern literals).
- Non-final ellipsis patterns (**`(m x ... y)`**) remain out of scope unless added later.
- **`v0.0.3-seed`** remains for kernels without ellipsis or nested macro patterns.
