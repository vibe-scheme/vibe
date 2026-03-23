# Chat 0011: LLVM Call Segfault Investigation

**Date**: 2025-12-17
**Model**: Cursor Composer 1
**Context**: Investigating segfault in `LLVMBuildCall2` when building function calls in DSL codegen

## Overview

After fixing the constant lookup issue in the previous session, a new segfault was discovered when attempting to build LLVM call instructions via the `llvm-call` DSL primitive. The segfault occurs in `llvm::IRBuilderBase::CreateCall` when trying to access the function type's vtable.

## Problem

The segfault manifests as:
```
EXC_BAD_ACCESS (code=1, address=0x1)
frame #0: llvm::IRBuilderBase::CreateCall(...) + 254
-> movq   (%rax), %rsi
```

The crash happens when LLVM tries to dereference a pointer at offset 0x10 of the function type, suggesting the function type passed to `LLVMBuildCall2` is invalid or incorrectly formatted.

## Investigation

### Key Findings

1. **Function Type Extraction**: Initially attempted to use `LLVMGetElementType` on the result of `LLVMTypeOf`, but this was incorrect - `LLVMGetElementType` on a function type returns the return type, not the function type itself.

2. **LLVM C API Behavior**: In the LLVM C API, `LLVMTypeOf` on a function value should return the function type directly (not a pointer type), so we should use it as-is.

3. **Function Type Storage**: The codebase has infrastructure to store function types when functions are created (e.g., `printf` in `codegen_init`), but `codegen_dsl_call` was not using these stored types.

4. **C Example Reference**: The user provided a C example showing that `printf` is created with a specific function type, and that exact type should be used when calling `LLVMBuildCall2`.

### Changes Made

1. **Added function type storage in `codegen_init`**: Store the `printf` function type when it's created so it can be retrieved later.

2. **Modified `codegen_dsl_get_function`**: Store both the function value and type when a function is retrieved, so `llvm-call` can use the stored type.

3. **Simplified `codegen_dsl_call`**: Use `LLVMTypeOf` directly on the function value to get the function type, removing the incorrect `LLVMGetElementType` extraction.

4. **Added debug logging**: Extensive debug logging was added to trace:
   - Function value retrieval
   - Function type extraction
   - Argument array construction
   - All parameters passed to `LLVMBuildCall2`

### Debug Output Analysis

The debug output shows:
- Builder: valid pointer (0x6000025a4000)
- Function type: valid pointer (0x6000016a4020) 
- Function value: valid pointer (0x6000026a8008)
- Arguments array: valid pointer (0x6000037a4140)
- Both arguments stored correctly with valid pointers

Despite all parameters appearing valid, the segfault still occurs when LLVM tries to access the function type's internal structure.

## Root Cause Hypothesis

The most likely issue is that `LLVMTypeOf` on a function value might not return the exact `FunctionType*` that was used to create the function. The LLVM C API might be returning a different type representation, or there might be a mismatch between how the function was created and how its type is being retrieved.

## Remaining Work

1. **Use stored function type**: Instead of using `LLVMTypeOf`, retrieve the stored function type that was saved when the function was created or retrieved via `llvm-get-function`.

2. **Function type lookup in `llvm-call`**: Modify `codegen_dsl_call` to look up the stored function type based on the function value or function name, rather than extracting it via `LLVMTypeOf`.

3. **Alternative approach**: Consider storing the function type alongside the function value in the DSL evaluation result, so `llvm-call` has direct access to it.

## Files Modified

- `bootstrap/compiler/codegen.ll`:
  - Added function type storage in `codegen_init` for `printf`
  - Modified `codegen_dsl_get_function` to store function and type
  - Simplified `codegen_dsl_call` to use `LLVMTypeOf` directly
  - Added extensive debug logging throughout the call building process

## Technical Notes

- The segfault address `0x746e696f50` ("Point" in ASCII) suggests we might be reading from a string literal, indicating incorrect type handling.
- `LLVMBuildCall2` expects a `FunctionType*` that exactly matches the type used to create the function.
- The stored function type approach aligns with the C example pattern where the exact function type is used.

## Related Documentation

- Previous chat: `0010-parameter-resolution-fix.md` - Fixed constant lookup issue
- Design docs: `docs/design/bootstrap-plan.md` - Overall bootstrap compiler architecture
