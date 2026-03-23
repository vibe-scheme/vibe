# Chat 0048: Self-Hosting Complete — Bootstrap Removal

**Date**: 2026-03-17
**Model**: Claude claude-4.6-opus-high-thinking (Cursor Agent)
**Context**: Milestone session — removing the bootstrap compiler and transitioning to a fully self-hosted build.

## Overview

This session marks the completion of Vibe's self-hosting journey. The bootstrap compiler (pure LLVM IR in `bootstrap/*.ll`) has been removed from HEAD, the build system has been simplified to a single self-hosted mode, and a seed compiler binary has been published as a GitHub release for initial bootstrapping on clean checkouts.

## Self-Hosting Assessment

Before making changes, we assessed whether Vibe was truly self-hosting:

- **All modules fully migrated**: Every `.ll` module has a corresponding `.vibe` file that is the canonical source (lexer, parser, ffi, dsl, codegen, main)
- **`types.ll` is unnecessary**: All `.vibe` files define their own types via `llvm:define-type`. The types from `types.ll` that aren't redefined in `.vibe` files (`%VibeValue`, `%VibeCons`, etc.) are unused by the kernel
- **Self-host chain verified**: `vibe_kernel` successfully compiles all its own modules and produces a working binary

## Key Decisions

### Seed Binary Distribution via GitHub Release

Rather than checking a ~57MB binary into git (which would permanently bloat the repository), we chose to publish the seed compiler as a GitHub release asset:

- **Release**: `v0.0.1-seed` at https://github.com/vibe-scheme/vibe/releases/tag/v0.0.1-seed
- **Asset**: `vibe_kernel_seed` (49MB stripped, down from 57MB unstripped)
- **Platform**: arm64-apple-darwin (Apple Silicon macOS)
- **Download**: `build.sh` uses `gh` CLI (preferred) or `curl` (fallback) to fetch the seed

### Bootstrap Files Kept in Git History

The `bootstrap/*.ll` files were deleted from HEAD but remain in git history. This provides a safety net — if the seed binary is ever lost or the GitHub release becomes unavailable, the full bootstrap chain can be reconstructed from a historical commit.

### Cross-Compilation Design Documented

During the assessment, we identified and documented the specific changes needed for cross-compilation support in `docs/design/cross-compilation-plan.md`:
- Hardcoded `arm64-apple-darwin` target triple in `kernel/codegen.vibe`
- AArch64-only target initialization in `kernel/dsl.vibe`
- Phase 1 (runtime detection), Phase 2 (CLI override), Phase 3 (build system)

## Changes Made

### Files Deleted
- `bootstrap/types.ll` — shared type definitions (now inline in each `.vibe` file)
- `bootstrap/lexer.ll` — lexer implementation
- `bootstrap/parser.ll` — parser implementation
- `bootstrap/ffi.ll` — FFI implementation
- `bootstrap/dsl.ll` — LLVM C API wrappers
- `bootstrap/codegen.ll` — code generator
- `bootstrap/main.ll` — compiler driver

### Files Modified

**`build.sh`** — Complete rewrite:
- Removed `bootstrap` and `build_kernel` commands
- Added `download_seed()` function using `gh` CLI (with `curl`/`wget` fallback)
- Single `build` command: downloads seed if needed, then runs self-hosted build
- Simplified usage: `{clean|build|test|install}`

**`CMakeLists.txt`** — Major simplification:
- Removed `BUILD_MODE` variable and all BOOTSTRAP/KERNEL/SELF_HOST conditionals
- Removed `bootstrap_types.bc` generation and all linking references
- Removed `bootstrap_compiler` target entirely
- Removed duplicate `llvm_map_components_to_libnames` block
- Detect target triple from system (sysctl) instead of parsing `types.ll`
- Clean module names: `compile_lexer`, `compile_parser`, etc. (was `bootstrap_lexer`, etc.)
- Single linear build pipeline: compile `.vibe` → link → `llc` → executable

**`AGENTS.md`** — Comprehensive rewrite:
- Updated overview to reflect self-hosted status
- Removed "Minimal Bootstrap" core principle
- Removed entire "Bootstrap/Kernel Sync Strategy" section
- Removed "Synchronizing Bootstrap and Kernel Files" section
- Removed "LLVM IR Code" coding standards section
- Removed three-mode build system explanation
- Updated directory structure (no more `bootstrap/`)
- Updated all technical references to point to `kernel/*.vibe` only
- Updated "Next Steps" to reflect post-self-hosting priorities
- Simplified contribution guide

### Files Created
- `docs/design/cross-compilation-plan.md` — design document for future cross-compilation support
- `docs/chats/0048-self-hosting-bootstrap-removal.md` — this file

## Verification

1. **Clean self-host build**: `./build.sh clean && ./build.sh build` succeeded through full bootstrap → kernel → self-host chain
2. **Compiler output verified**: `vibe_kernel` correctly compiles a test program producing valid LLVM IR
3. **Self-compilation verified**: `vibe_kernel` successfully compiles `kernel/lexer.vibe` and `kernel/parser.vibe`
4. **New build system tested**: Clean checkout with seed download via `gh release download` → CMake → compile → link → working binary
5. **Seed binary stripped**: 57MB → 49MB with `strip`

## Technical Notes

- The LLVM version on this machine is 22.1.1 (CMake warns about >22.0 but builds succeed)
- Linker warnings about duplicate LLVM libraries and missing zstd architecture are cosmetic and pre-existing
- The `codegen.vibe` and `main.vibe` modules output `.ll` text IR (then assembled via `llvm-as`), while lexer/parser/ffi/dsl output `.bc` directly — this inconsistency is carried forward from the original build and works correctly

## Related Documents
- `docs/design/cross-compilation-plan.md` — future cross-compilation support
- `docs/design/bootstrap-plan.md` — historical bootstrap plan (now archived context)
- `docs/design/ffi-llvm-integration.md` — FFI/LLVM integration design
