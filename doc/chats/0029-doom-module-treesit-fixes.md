# Chat 0029: Tree-sitter Grammar, Emacs Modes, and Doom Module

**Date**: 2025-03-03
**Model**: Cursor Composer 1.5

## Overview

This session created the full Tree-sitter and Emacs integration for Vibe from scratch: a tree-sitter grammar, vibe-mode and vibe-ts-mode, and a Doom Emacs module. During setup, we fixed symlink path resolution (so the grammar loads when the module is symlinked) and replaced Doom's `treesit-ready-p` with `treesit-language-available-p` so syntax highlighting works.

## Work Completed

### 1. Tree-sitter Grammar (`tree-sitter-vibe/`)

- **grammar.js** – Grammar for S-expressions, vertical-bar symbols (`|i8*|`), bytevectors, vectors, abbreviations, comments
- **build.sh** – Builds `libtree-sitter-vibe.so` (Linux) or `libtree-sitter-vibe.dylib` (macOS) from `parser.c`; no external tree-sitter lib, uses tree-sitter-cli only for `generate`
- **package.json** – tree-sitter-cli dependency; install script overrides node-gyp to avoid nan errors
- **src/** – Generated parser.c, grammar.json, node-types.json, tree_sitter/parser.h
- **test/corpus/basic.vibe.txt** – Test corpus
- **README.md** – Build and test instructions

### 2. Emacs Modes (`emacs/`)

- **vibe-mode.el** – Derived from scheme-mode with custom indentation for Vibe define-like forms (`llvm:define-function`, `llvm:define-type`, etc.) via `vibe-indent-specs` and `scheme-indent-function`
- **vibe-ts.el** – Tree-sitter mode derived from vibe-mode: font-lock (comments, strings, constants, types, keywords, function calls), indent rules, defun navigation
- **README.md** – Installation for vibe-mode

### 3. Doom Module (`doom-modules/lang/vibe/`)

- **config.el** – Adds `tree-sitter-vibe/build/` to `treesit-extra-load-path`; uses `file-truename` so paths resolve when the module is symlinked
- **packages.el** – `package!` for vibe-mode and vibe-ts with `:local-repo` pointing at the vibe emacs directory
- **README.org** – Prerequisites, installation (clone, build grammar, symlink, add to init.el), troubleshooting

### 4. Symlink Path Resolution Fix

When the module is symlinked at `~/.config/doom/modules/lang/vibe`, `../../..` from the symlink resolved to `~/.config/doom/modules/` instead of the Vibe repo. Wrapped the module dir in `file-truename` so `vibe-root-dir` and `vibe-grammar-dir` point to the real repo.

### 5. Tree-sitter Font-lock Fix

`vibe-ts-mode` used `(treesit-ready-p 'vibe)` (Doom-specific), which returned nil even when the grammar was available. Replaced with `treesit-language-available-p` so font-lock is applied.

### 6. .gitignore

Added `tree-sitter-vibe/node_modules/` and `tree-sitter-vibe/build/`.

## Files Created/Modified

| Path | Change |
|------|--------|
| `tree-sitter-vibe/grammar.js` | New |
| `tree-sitter-vibe/build.sh` | New |
| `tree-sitter-vibe/package.json` | New |
| `tree-sitter-vibe/README.md` | New |
| `tree-sitter-vibe/src/*` | New (generated) |
| `tree-sitter-vibe/test/corpus/basic.vibe.txt` | New |
| `emacs/vibe-mode.el` | New |
| `emacs/vibe-ts.el` | New |
| `emacs/README.md` | New |
| `doom-modules/lang/vibe/config.el` | New |
| `doom-modules/lang/vibe/packages.el` | New |
| `doom-modules/lang/vibe/README.org` | New |
| `.gitignore` | Added tree-sitter entries |

## Next Session

Return to migrating the parser to Vibe.
