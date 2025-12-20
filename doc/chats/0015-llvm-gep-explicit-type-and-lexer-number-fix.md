# Chat 0015: llvm:gep Explicit Type Argument and Lexer Number Recognition Fix

**Date**: 2025-12-20
**Context**: Updating `llvm:gep` DSL to require explicit type argument (matching 1-to-1 LLVM IR translation goal) and fixing lexer to properly recognize numeric literals

## Overview

Successfully updated the `llvm:gep` DSL primitive to require an explicit type argument as the first parameter, matching the goal of 1-to-1 translation with LLVM IR syntax. Also fixed the root cause of a segfault by updating the lexer to properly recognize numeric literals as `TOKEN_NUMBER` instead of `TOKEN_IDENTIFIER`.

## Problem

1. **llvm:gep Type Argument**: The `llvm:gep` DSL was using type inference (from chat 0014), but this didn't match the 1-to-1 LLVM IR translation goal. LLVM IR syntax is `getelementptr <type>, <type>* <pointer>, <index1>, <index2>, ...`, so the DSL should be `(llvm:gep type pointer index1 index2 ...)`.

2. **Lexer Number Recognition**: The lexer was tokenizing numeric literals like `0`, `1`, `2` as `TOKEN_IDENTIFIER` instead of `TOKEN_NUMBER`. This caused segfaults when evaluating GEP indices, as the codegen tried to look up "0" as a variable name instead of treating it as a constant integer.

## Solution

### 1. Updated llvm:gep DSL Signature

**File**: `bootstrap/lexer/lexer.vibe`

Updated all `llvm:gep` calls to include the struct type as the first argument:
- `(llvm:gep lexer_ptr 0 0)` → `(llvm:gep |%Lexer| lexer_ptr 0 0)`
- Similar updates for all other GEP calls (indices 1-4)

The type `|%Lexer|` is the struct type (not the pointer type `|%Lexer*|`), matching LLVM IR syntax where GEP takes the pointee type.

**File**: `bootstrap/compiler/codegen.ll`

Modified `codegen_dsl_gep` to:
1. Extract type as first argument (`args.car`)
2. Resolve type string using `codegen_resolve_type_string` (same pattern as `codegen_dsl_bitcast`)
3. Extract pointer as second argument (`args.cdr.car`)
4. Extract indices from remaining arguments (`args.cdr.cdr`)
5. Removed type inference logic that inferred type from pointer
6. Updated function comment to reflect new signature: `(llvm:gep type pointer index1 index2 ...)`

### 2. Fixed Lexer Number Recognition

**File**: `bootstrap/lexer/lexer.ll`

Updated `lex_read_identifier` to detect numeric identifiers:
1. Check if first character is a digit (0-9)
2. If yes, check if all characters in the token are digits
3. If all digits, return `TOKEN_NUMBER` (type 2) instead of `TOKEN_IDENTIFIER`
4. Otherwise, treat as identifier or symbol as before

**File**: `bootstrap/compiler/codegen.ll`

Added handling for `TOKEN_NUMBER` atoms in `codegen_eval_dsl_expr`:
- Check if atom type is `TOKEN_NUMBER` (type 2) before symbol resolution
- Parse integer using `codegen_parse_int_from_ast`
- Create constant i32 integer using `llvm_create_constant_int`
- Return the constant integer value

Removed workaround fallback code that tried to detect numeric identifiers after constant lookup failed, since the lexer now handles numbers correctly.

## Implementation Details

### Argument Structure
The new argument structure for `(llvm:gep type pointer index1 index2 ...)`:
- `args.car` = type node (ASTNode with type string like `|%Lexer|`)
- `args.cdr.car` = pointer node (ASTNode with pointer expression)
- `args.cdr.cdr` = indices list (ASTNode list containing index expressions)

### Type Resolution
Uses the existing `codegen_resolve_type_string` function (same pattern as `codegen_dsl_bitcast`) to resolve type strings like `|%Lexer|` to `LLVMTypeRef`.

### Number Recognition
The lexer now properly recognizes numeric literals at tokenization time, ensuring they're handled correctly throughout the compilation pipeline. This follows the principle of "fix at the source" rather than adding workarounds downstream.

## Results

Successfully generated bitcode from `lexer.vibe`! The generated LLVM IR shows:

```llvm
define ptr @lex_init(ptr %0, i64 %1) {
entry:
  %2 = call ptr @malloc(i64 40)
  %3 = getelementptr %Lexer, ptr %2, i32 0, i32 0
  %4 = getelementptr %Lexer, ptr %2, i32 0, i32 1
  %5 = getelementptr %Lexer, ptr %2, i32 0, i32 2
  %6 = getelementptr %Lexer, ptr %2, i32 0, i32 3
  %7 = getelementptr %Lexer, ptr %2, i32 0, i32 4
  store ptr %0, ptr %3, align 8
  store i64 %1, ptr %4, align 8
  store i64 0, ptr %5, align 8
  store i32 1, ptr %6, align 4
  store i32 1, ptr %7, align 4
  ret ptr %2
}
```

### Notes on Generated Code

1. **Opaque Pointers**: LLVM 21 uses opaque pointers (`ptr`), so bitcasts between pointer types are no-ops and get optimized away. The bitcast in the source (`lexer_ptr = bitcast lexer to %Lexer*`) is semantically correct but optimized away, which is expected behavior.

2. **Return Type**: In opaque pointer mode, all pointers are `ptr`, so no explicit cast is needed on the return value. The function signature `define ptr @lex_init(ptr %0, i64 %1)` is correct.

3. **GEP Instructions**: All GEP instructions correctly use the explicit type `%Lexer` as the first argument, matching LLVM IR syntax.

## Files Modified

1. `bootstrap/lexer/lexer.vibe` - Updated all `llvm:gep` calls to include type argument
2. `bootstrap/compiler/codegen.ll` - Updated `codegen_dsl_gep` function implementation and added `TOKEN_NUMBER` handling
3. `bootstrap/lexer/lexer.ll` - Added number recognition logic to `lex_read_identifier`
4. `AGENTS.md` - Added note about fixing issues at the source

## Related Documentation

- `doc/chats/0014-llvm-gep-type-inference.md` - Previous attempt at type inference (reversed)
- `doc/chats/0013-let-star-binding-storage-and-retrieval.md` - Context on `let*` work
- `AGENTS.md` - Goal of 1-to-1 LLVM IR translation and "fix at source" principle

## Key Learnings

1. **Fix at the Source**: Always fix issues at their root cause rather than adding workarounds. In this case, fixing the lexer to recognize numbers was the correct approach, not adding fallback logic in codegen.

2. **1-to-1 Translation Goal**: The DSL should match LLVM IR syntax as closely as possible. Requiring explicit type arguments in `llvm:gep` matches this goal.

3. **Opaque Pointers**: LLVM 21 uses opaque pointers, which means bitcasts between pointer types are no-ops. This is expected behavior and the generated code is correct.

## Next Steps

Next session will focus on getting the bootstrap compiler to link the generated bitcode successfully.
