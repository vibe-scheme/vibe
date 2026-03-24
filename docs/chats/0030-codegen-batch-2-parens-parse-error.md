# Chat 0030: Codegen Batch 2, Parentheses Handling, Parse Error Exit

**Date**: 2026-03-10  
**Model**: Cursor Composer 1.5  

## Overview

This session covered: (1) codegen migration Batch 2 (four functions to kernel/codegen.vibe), (2) bug fix for EOF infinite loop caused by a missing closing paren in codegen_map_predicate_string, (3) parentheses error detection and reporting in the parser, (4) making parse_error abort compilation with exit(1) instead of looping, and (5) AGENTS.md updates for LLVM upgrade and parentheses care.

## Work Completed

### 1. Codegen Migration Batch 2

Migrated four functions from `bootstrap/codegen_no_vibe.ll` to `kernel/codegen.vibe`:

**Declarations** (added to kernel/codegen.vibe):
- `realloc` - `llvm:declare-function` (resolves at link time from libc, same pattern as malloc)
- `codegen_define_string_constant_only` - forward declaration (defined in codegen_no_vibe.ll)
- `codegen_collect_string_constants` and `codegen_collect_string_constants_from_args` - mutual forward declarations for recursion

**codegen_append**: Buffer append with realloc growth. Uses CodeGen fields: buffer (0), buffer_len (1), buffer_cap (2). Implements grow-then-append logic with memcpy for the copy step.

**codegen_collect_string_constants**: Recursive AST traversal; for each list expression, calls codegen_collect_string_constants_from_args on its arguments, then recurses on cdr.

**codegen_collect_string_constants_from_args**: Recursive arg traversal; for string literal args (atom_type=3), calls codegen_define_string_constant_only; recurses on cdr.

**codegen_map_predicate_string**: Maps predicate strings to LLVMIntPredicate enum. Added 10 `llvm:define-constant` entries (eq, ne, uge, ult, ugt, ule, sge, slt, sgt, sle) following the pattern from `kernel/dsl.vibe`. Uses `llvm:get-global` and `llvm:gep` to obtain pointers for codegen_dsl_check_primitive calls.

**codegen_no_vibe.ll sync**: Replaced the four function definitions with `declare` statements; removed 10 `@.str.pred_*` constant definitions (moved to codegen.vibe).

Total migrated: 21 functions (~66 remaining).

### 2. EOF Loop Bug Fix

Missing closing `)` in `codegen_map_predicate_string` (around line 788) caused the parser to stay in `parse_list_tail`, treat EOF as an atom, and loop. Fixed by adding the missing `)` to close the `define-function` form.

### 3. Parentheses Error Detection

Added checks at the start of `parse_expr` in both `bootstrap/parser.ll` and `kernel/parser.vibe`:
- **EOF**: Report "error: unexpected end of file (unclosed parentheses)"
- **Unexpected RPAREN**: Report "error: unexpected ) (too many closing parens)"

`parse_error` prints the message to stderr (fd 2) via `write` before handling the error.

### 4. Parse Error Abort (Fix Infinite Loop)

When the parser detected unexpected EOF or unexpected RPAREN, it called `parse_error` which printed the message and returned null. Callers (parse_list_tail, parse_list) did not check for null, so they continued recursing—causing an infinite loop.

**Solution**: Make `parse_error` call `exit(1)` instead of returning. The process terminates immediately after printing the error.

**bootstrap/parser.ll**:
- Changed `parse_error` to call `exit(1)` after writing to stderr
- Added `unreachable` after the exit call (exit never returns)
- Added `declare void @exit(i32)`
- Fixed string constant array sizes: EOF message [52→54], RPAREN message [48→47] (LLVM requires exact match)

**kernel/parser.vibe**:
- Added `(llvm:declare-function (exit (status |i32|)) |void|)`
- Changed `parse_error` to call `exit(1)` after writing; kept `llvm:ret` for type satisfaction (dead code)

### 5. AGENTS.md Updates

**Build System** (after "Never test with an outdated binary"):
- Added: Run `./build.sh clean` first after upgrading LLVM so CMake reconfigures and finds new paths

**Code Style** (new bullet):
- **Parentheses**: Keep parentheses balanced in Vibe source. Unclosed `)` causes infinite parse loops; extra `)` can trigger spurious main generation. The compiler reports "unexpected end of file (unclosed parentheses)" or "unexpected ) (too many closing parens)" when it detects imbalance.

**Chat Documentation Format**:
- Added "including migrated functions and methods" to the feature implementations bullet

### 6. Test Files

Created for verification:
- `test/unclosed_paren.vibe` – unclosed `(define y 2`
- `test/extra_rparen.vibe` – extra `)` after `(define x 1)`

## Key Decisions

1. **realloc via declare**: Same as malloc - `llvm:declare-function` resolves at link time from libc. No FFI needed.

2. **Predicate constants via llvm:define-constant**: Used existing DSL support (as in dsl.vibe for .str.arm64/.str.aarch64) rather than runtime string construction.

3. **memcpy for codegen_append**: Used C library memcpy (already declared) instead of LLVM intrinsic; equivalent for byte copying.

4. **exit(1) over null propagation**: Simpler and more direct than adding null checks throughout the parse call chain. Ensures immediate abort.

5. **String constant sizes**: LLVM IR requires the array type to exactly match the string literal length. The compiler reported "constant expression type mismatch" until sizes were corrected.

## Files Modified

- `kernel/codegen.vibe` – Batch 2: codegen_append, codegen_collect_string_constants, codegen_collect_string_constants_from_args, codegen_map_predicate_string; realloc/forward declarations; 10 predicate constants
- `bootstrap/codegen_no_vibe.ll` – Replaced 4 function definitions with declares; removed predicate constants
- `bootstrap/parser.ll` – EOF/RPAREN checks in parse_expr; parse_error calls exit(1); exit declare; string constant sizes (54, 47)
- `kernel/parser.vibe` – EOF/RPAREN checks; parse_error calls exit(1); exit declare
- `AGENTS.md` – LLVM clean note, parentheses note, migration status (21 functions), chat doc format update
- `test/unclosed_paren.vibe` – new
- `test/extra_rparen.vibe` – new

## Verification

- Bootstrap and kernel builds succeed
- Both compilers exit with code 1 on unclosed paren and extra rparen
- Error messages printed to stderr before exit
