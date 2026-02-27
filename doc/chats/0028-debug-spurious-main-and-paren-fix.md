# Chat 0028: Debug Spurious Main and Paren Fix

**Date**: 2026-02-09
**Model**: Cursor Composer 1.5

## Overview

This session implemented printf-based debug logging to trace the spurious `main` generation that caused "Linking globals named 'main': symbol multiply defined!" when building the kernel. The debug output revealed the root cause: two extra closing parentheses in `kernel/codegen.vibe` were being parsed as top-level expressions with empty form car, which were added to `exprs_list` and triggered main generation. The session also fixed those parentheses and documented a future task to remove the implicit main-insertion logic.

## Work Completed

### 1. Debug Plan Implementation

Added printf-based logging at three points per the debug plan:

**`bootstrap/main.ll`**
- **add_to_list**: Log every form added to `exprs_list` (forms that don't match any handler), including extraction and printing of form identifier (car for lists, value for atoms) with null checks
- **generate_code**: Log whether `exprs` is null or non-null before calling `codegen_main`
- Added `declare i32 @printf(i8*, ...)` and debug string constants
- Resolved LLVM IR issues: SSA name collisions (prefixed with `atl_` / `add_to_list_ast_null`), string constant size mismatches (corrected to 41, 25, 62, 63 bytes per llvm-as)

**`bootstrap/codegen_no_vibe.ll`**
- **done_no_main**: Log when skipping main (`[CODEGEN] codegen_main: exprs null or empty - skipping main`)
- **has_exprs**: Log when generating main (`[CODEGEN] codegen_main: exprs has content - generating main`)

### 2. Root Cause Identification

Running `bootstrap_compiler kernel/codegen.vibe -o /tmp/out.ll 2>&1 | grep -E '\[MAIN\]|\[CODEGEN\].*codegen_main'` produced:

```
[MAIN] add_to_list: form added to exprs
[MAIN]   form car: 
[MAIN] add_to_list: form added to exprs
[MAIN]   form car: 
...
[MAIN] generate_code: exprs=non-null (main will be generated)
```

The empty "form car" (zero-length identifier) indicated two stray top-level forms. These were caused by **two extra closing parentheses** at the end of `codegen_get_function_type` in `kernel/codegen.vibe` line 591. The extra `)` tokens were parsed as separate top-level expressions with empty atom car, fell through all handlers to `add_to_list`, and triggered main generation.

### 3. Paren Fix

Removed two extra closing parentheses from `codegen_get_function_type`:

- **Before**: `(llvm:ret (llvm:const-null |i8*|))))))` (6 closers)
- **After**: `(llvm:ret (llvm:const-null |i8*|))))` (4 closers)

The correct structure needs: `)` for const-null, `)` for ret, `)` for llvm:label, `)` for define-function.

### 4. Future Task Note

The implicit main-insertion logic (`codegen_main` generating `main` when `exprs_list` has top-level expressions) should be removed at some point. The design direction is to require an explicit `main` function in exactly one compilation unit when building an executable, rather than implicitly inserting one. This can be revisited after self-hosting is complete. For now, the code remains in place.

## Key Decisions

- **Leave main insertion for now**: Per user preference, do not remove `codegen_main` or the implicit main logic; document the future removal
- **Fix at source**: The fix was correcting the mismatched parens in the source, not adding heuristics to distinguish library vs. program modules

## Files Modified

- `bootstrap/main.ll`: Debug logging (add_to_list, generate_code), printf declare, string constants, SSA name fixes
- `bootstrap/codegen_no_vibe.ll`: Debug logging (done_no_main, has_exprs), string constants
- `kernel/codegen.vibe`: Removed 2 extra closing parentheses from `codegen_get_function_type`

## Related

- Plan: `.cursor/plans/Debug Spurious Main-353461fe.plan.md`
- Chat 0027: Codegen migration batch 1 (established kernel codegen structure)
- AGENTS.md: Bootstrap/Kernel sync strategy, build modes
