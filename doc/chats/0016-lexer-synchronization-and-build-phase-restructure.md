# Chat 0016: Lexer Synchronization Fix and Build Phase Restructure

**Date**: 2025-12-22
**Context**: Fixing number parsing issue by synchronizing `lexer_no_vibe.ll` with `lexer.ll`, and restructuring build phases to support self-hosting

## Overview

Fixed the root cause of number parsing failures by synchronizing `lexer_no_vibe.ll` with the fixes that were already present in `lexer.ll`. Also restructured the build system to add a third build phase that enables self-hosting compilation using `vibe_kernel` itself.

## Problem

1. **Number Parsing Still Broken**: Despite fixing number parsing in `lexer.ll` (from chat 0015), numbers were still being parsed as identifiers when building `vibe_kernel`. The issue was that `build_kernel` uses `lexer_no_vibe.ll` + `lexer.vibe`, not `lexer.ll`. The `lexer_no_vibe.ll` file was last synchronized before the number parsing fixes were implemented.

2. **Build Phase Confusion**: The build system had two phases (`bootstrap` and `build`), but the goal is to eventually have `vibe_kernel` compile itself. We needed a clear distinction between:
   - Building `vibe_kernel` using `bootstrap_compiler` (current `build`)
   - Building `vibe_kernel` using `vibe_kernel` itself (self-hosting, future goal)

## Solution

### 1. Synchronized lexer_no_vibe.ll with lexer.ll

**File**: `bootstrap/lexer/lexer_no_vibe.ll`

Applied the same number parsing fixes that were already in `lexer.ll`:
- Added digit checking logic in `lex_read_identifier`
- Added `check_all_digits` block to verify all characters are digits
- Updated token type determination to return `TOKEN_NUMBER` (type 2) for numeric tokens
- Added `set_token_type` phi node to handle both identifier and number cases

**Key Insight**: When building `vibe_kernel` in KERNEL mode, CMake uses `lexer_no_vibe.ll` + compiled `lexer.vibe`, not `lexer.ll`. Any fixes to `lexer.ll` must be synchronized to `lexer_no_vibe.ll` until the function is fully migrated to `lexer.vibe`.

### 2. Added Synchronization Note to AGENTS.md

**File**: `AGENTS.md`

Added a new section "Synchronizing `*_no_vibe.ll` Files" under "LLVM IR Code" that documents:
- When to synchronize: Any time you modify a function in a `.ll` file that also exists in `*_no_vibe.ll`
- What to synchronize: Function implementations, type definitions, constants, logic changes
- Future goal: Eventually all code will be migrated to `.vibe` files

### 3. Restructured Build Phases

**File**: `build.sh`

Renamed and added build phases:
- `bootstrap`: Builds `bootstrap_compiler` using `.ll` files only (unchanged)
- `build_kernel`: Builds `vibe_kernel` using `.vibe` files + `_no_vibe.ll` files, compiled with `bootstrap_compiler` (renamed from `build`)
- `build`: Builds `vibe_kernel` using `vibe_kernel` itself (self-hosting, new, default)

The new `build` phase:
1. Ensures `vibe_kernel` exists (runs `build_kernel` if needed)
2. Configures CMake with `BUILD_MODE=SELF_HOST`
3. Uses `vibe_kernel` to compile `.vibe` files instead of `bootstrap_compiler`

**File**: `CMakeLists.txt`

Added support for `SELF_HOST` build mode:
- Added `USE_VIBE_KERNEL` flag to distinguish between KERNEL and SELF_HOST modes
- Modified `.vibe` file compilation to use `vibe_kernel` when `USE_VIBE_KERNEL` is ON
- Handled circular dependency by requiring `vibe_kernel` to exist before configuring (enforced by `build.sh`)

## Implementation Details

### Build Phase Flow

```
bootstrap → build_kernel → build
   ↓            ↓            ↓
bootstrap_  vibe_kernel  vibe_kernel
compiler    (using       (using
            bootstrap)   vibe_kernel)
```

### Circular Dependency Handling

In SELF_HOST mode, `vibe_kernel` needs to exist to compile `.vibe` files, but we're building `vibe_kernel` itself. This creates a circular dependency that we handle by:
1. `build.sh` ensures `vibe_kernel` exists before configuring CMake (runs `build_kernel` first)
2. CMake does NOT add a dependency on `vibe_kernel` to avoid the cycle
3. The existing `vibe_kernel` is used to rebuild itself

### Number Parsing Fix

The fix ensures that tokens starting with digits are recognized as numbers:
- First character check: Is it a digit (0-9)?
- If yes, check all characters: Are they all digits?
- If all digits, return `TOKEN_NUMBER` (type 2)
- Otherwise, treat as identifier or symbol

This follows R7RS specification: any token starting with a digit must be a number.

## Results

1. **Number Parsing Fixed**: Single-digit and multi-digit numbers are now correctly parsed as `TOKEN_NUMBER` (type 2) instead of `TOKEN_IDENTIFIER` (type 1)

2. **Build Phases Working**: All three build phases work correctly:
   - `./build.sh bootstrap` - builds bootstrap compiler
   - `./build.sh build_kernel` - builds vibe_kernel using bootstrap_compiler
   - `./build.sh build` - builds vibe_kernel using vibe_kernel itself (self-hosting)

3. **Self-Hosting Ready**: The infrastructure is now in place for `vibe_kernel` to compile itself, moving toward the goal of full self-hosting.

## Files Modified

1. `bootstrap/lexer/lexer_no_vibe.ll` - Synchronized number parsing fixes from `lexer.ll`
2. `AGENTS.md` - Added synchronization note for `*_no_vibe.ll` files
3. `build.sh` - Restructured build phases (renamed `build` to `build_kernel`, added new `build`)
4. `CMakeLists.txt` - Added `SELF_HOST` build mode support with `USE_VIBE_KERNEL` flag

## Related Documentation

- `doc/chats/0015-llvm-gep-explicit-type-and-lexer-number-fix.md` - Original number parsing fix in `lexer.ll`
- `AGENTS.md` - Synchronization requirements and build phase documentation

## Key Learnings

1. **Synchronization is Critical**: When working with both `.ll` and `*_no_vibe.ll` files, changes must be synchronized until migration to `.vibe` is complete. The build system uses different files depending on the build mode.

2. **Build Phase Clarity**: Having distinct phases (`bootstrap`, `build_kernel`, `build`) makes it clear what compiler is being used at each stage, which is essential for self-hosting goals.

3. **Circular Dependencies**: Self-hosting creates circular dependencies that can be handled by ensuring the compiler exists before configuration, rather than adding CMake dependencies.

## Next Steps

Next session will focus on moving more of the Lexer to Vibe code, continuing the migration from `.ll` files to `.vibe` files.
