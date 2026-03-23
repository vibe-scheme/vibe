# Chat 0021: Visitor-Pattern Terminator Validation and Predicate Enum Fix

**Date**: 2026-02-06
**Model**: Claude claude-4.6-opus-high-thinking (via Cursor)
**Context**: Fixing empty entry block in lex_skip_whitespace, adding visitor-pattern terminator validation, and fixing scrambled LLVMIntPredicate enum values

## Session Overview

This session accomplished three major things:

1. **Added model tracking to all past chat documents** (0001-0020) and updated AGENTS.md to require model field in chat documentation
2. **Implemented visitor-pattern terminator validation** for basic blocks in the codegen, catching missing terminators as compilation errors
3. **Fixed scrambled LLVMIntPredicate enum values** in `codegen_map_predicate_string` that were causing `lex_is_eof` to have inverted semantics, making `vibe_kernel` immediately report EOF on any input

## Problem 1: Empty Entry Block in lex_skip_whitespace

### Issue

When compiling `bootstrap/lexer/lexer.vibe`, the `lex_skip_whitespace` function generated an empty `entry:` block with no terminator:

```llvm
define void @lex_skip_whitespace(ptr %0) {
entry:
              ; <-- empty! no terminator!
loop:
  ...
```

This is invalid LLVM IR -- every basic block must end with a terminator instruction.

### Root Cause

The function body started directly with `(llvm:label 'loop ...)`. In `codegen_define_llvm_function`, the entry block was created and the builder positioned there, but when `codegen_dsl_label` was called for the first expression, it moved the builder to the `loop` block without adding any instructions to `entry`.

### Solution: Visitor-Pattern Exit Checks

Rather than silently inserting implicit branches (which could mask errors like code silently dropped after nested labels), we implemented visitor-pattern exit checks:

1. **Label exit check** (`codegen_dsl_label`): After evaluating a label's body, check the label's own block for a terminator. Report `"error: label 'X' has no terminator"` if missing.

2. **Entry block exit check** (`codegen_define_llvm_function`): After evaluating the entire DSL body, check the entry block for a terminator. Report `"error: entry block of function 'Y' has no terminator"` if missing.

3. **Explicit branch in lexer.vibe**: Added `(llvm:br 'loop)` before the first label in `lex_skip_whitespace` to mirror the expected LLVM IR exactly.

### Why Not Implicit Branches

We considered automatically inserting `br` instructions when the current block is unterminated and a label is encountered, but rejected this because:
- It could silently drop code after nested labels
- The `.vibe` DSL should mirror LLVM IR 1-to-1 with explicit control flow
- The exit checks are self-hosting friendly (purely local, no hidden state)
- Missing terminators are caught as compilation errors rather than papered over

### New FFI Wrapper

Added `llvm_get_basic_block_terminator` wrapper in `bootstrap/runtime/ffi.ll` for `LLVMGetBasicBlockTerminator`, which returns the terminator instruction of a block or null if none exists.

## Problem 2: Scrambled LLVMIntPredicate Enum Values

### Issue

After fixing the entry block issue and building `vibe_kernel`, running it on `lexer.vibe` produced only an empty module header and immediately printed `[LEXER] EOF token`. The lexer was treating any non-empty file as immediately at EOF.

### Root Cause

The `codegen_map_predicate_string` function had **wrong enum values** for 8 out of 10 `LLVMIntPredicate` mappings:

| Predicate | Before (wrong) | After (correct) |
|-----------|----------------|-----------------|
| `eq`  | 32 | 32 (was correct) |
| `ne`  | 33 | 33 (was correct) |
| `ugt` | 37 | 34 |
| `uge` | 36 | 35 |
| `ult` | 35 | 36 |
| `ule` | 34 | 37 |
| `sgt` | 15 | 38 |
| `sge` | 14 | 39 |
| `slt` | 13 | 40 |
| `sle` | 12 | 41 |

The unsigned predicates were mapped in reversed order, and the signed predicates had completely invalid values (12-15 instead of 38-41).

### Impact Chain

1. `lex_is_eof` in `lexer.vibe` uses `(llvm:icmp 'uge pos len)` -- intended to return 1 when `pos >= len` (at EOF)
2. Codegen mapped `'uge` to 36 (`LLVMIntULT`) instead of 35 (`LLVMIntUGE`)
3. Compiled code did `icmp ult pos len` -- returns 1 when `pos < len` (NOT at EOF)
4. Callers in `lexer_no_vibe.ll` check `icmp ne %is_eof, 0` and branch to EOF path
5. On any non-empty file, `pos=0 < len`, so `lex_is_eof` returns 1 and the caller immediately takes the EOF branch

### Solution

Corrected all predicate values to match the `LLVMIntPredicate` enum from LLVM's C API (`LLVMIntEQ=32` through `LLVMIntSLE=41`).

## Problem 3: Model Tracking in Chat Documents

Added `**Model**: Cursor Composer 1` to all 20 existing chat documents and updated AGENTS.md to require the model field in future chat documentation.

## Files Modified

1. **`bootstrap/runtime/ffi.ll`**:
   - Added `LLVMGetBasicBlockTerminator` external declaration
   - Added `llvm_get_basic_block_terminator` wrapper function

2. **`bootstrap/compiler/codegen.ll`**:
   - Added `llvm_get_basic_block_terminator` declaration
   - Added error message string constants for missing terminators
   - Added visitor-pattern exit check in `codegen_dsl_label` (check label block for terminator after body evaluation)
   - Added visitor-pattern exit check in `codegen_define_llvm_function` (check entry block for terminator after DSL body evaluation)
   - Fixed all 8 incorrect `LLVMIntPredicate` enum values in `codegen_map_predicate_string`

3. **`bootstrap/lexer/lexer.vibe`**:
   - Added explicit `(llvm:br 'loop)` in `lex_skip_whitespace` before first label

4. **`AGENTS.md`**:
   - Updated chat documentation format to require model tracking

5. **`docs/chats/0001-0020`**:
   - Added `**Model**: Cursor Composer 1` to all existing chat documents

## Verification

- Bootstrap compiler rebuilds successfully
- Compiling `lexer.vibe` produces correct LLVM IR for all 5 functions
- `lex_skip_whitespace` generates `entry: br label %loop` (was empty)
- `lex_is_eof` generates `icmp uge` (was `icmp ult`)
- No terminator errors reported (all blocks properly terminated)
- `vibe_kernel` builds successfully

## Key Technical Insights

1. **Visitor pattern for validation**: Checking invariants when *leaving* an AST node (not when entering the next one) is a clean, principled approach that catches all issues systematically.

2. **Check the label's own block, not the current insert block**: After processing a label body, nested labels may have moved the builder. The terminator check must be on `%block` (the label we're validating), not `%current_insert_block`.

3. **Enum values must be verified against the source**: The `LLVMIntPredicate` enum values were likely transcribed incorrectly during initial implementation. When mapping string names to enum integers, always verify against the official LLVM C API headers.

4. **Semantic inversion bugs are subtle**: `lex_is_eof` returning the opposite of its name sounds like it would be catastrophic, but it only surfaced when the Vibe-compiled version (with the wrong predicate) was linked against `lexer_no_vibe.ll` (which expected the correct semantics).

## Related Documentation

- `docs/chats/0020-memory-leaks-visitor-pattern-and-label-handling.md` - Previous session's work on label handling
- `docs/design/bootstrap-plan.md` - Overall bootstrap compiler architecture
- `AGENTS.md` - Updated with model tracking requirement

## Next Steps

1. Test `vibe_kernel` on `lexer.vibe` to see how far it gets now that the predicate fix is in place
2. Continue migrating more lexer functions from `lexer_no_vibe.ll` to `lexer.vibe`
3. Investigate the "Invalid instruction with no BB" error noted in chat 0020 (may now be resolved by the terminator validation)
4. Work toward self-hosting: `./build.sh build` (vibe_kernel compiling itself)
