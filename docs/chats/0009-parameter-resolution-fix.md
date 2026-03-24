# Chat 0009: Parameter Resolution Fix for DSL Builder

**Date**: 2025-12-15  
**Model**: Cursor Composer 1  
**Context**: Continuing work on the LLVM Builder DSL migration. The DSL body generation was working, but parameter resolution was failing. The `name` parameter in `hello_world.vibe` was not being resolved correctly, causing `ERROR: Argument 1 is null!` when trying to call `printf` with the parameter.

## Problem

The `hello_world.vibe` test file defines a function `hello` with a parameter `(name |i8*|)`. When the DSL body tried to resolve the parameter name `name` using `llvm-resolve-param`, it was failing with:
- `ERROR: Argument 1 is null!` when trying to use the parameter in `llvm-call`

## Root Cause

The issue was in how `param_names` list was structured and accessed:

1. **List Structure**: `param_names` is built using `codegen_create_cons`, which creates a list structure like:
   ```
   ((name . (index . nil)) . rest)
   ```
   Each element in the list is a cons cell whose `car` contains the actual `(name . (index . nil))` pair.

2. **Incorrect Access**: In `codegen_dsl_resolve_param`, we were iterating over the list and treating each list element (`pair_val`) as if it were the actual pair. However, `pair_val` is the wrapper cons cell, not the actual pair.

3. **Result**: When trying to access the `cdr` of `pair_val` to get the index, we were getting the `cdr` of the list element (which points to the next element in the list), not the `cdr` of the actual pair (which contains the index).

## Solution

Fixed `codegen_dsl_resolve_param` to correctly extract the actual pair from each list element:

1. **Extract Actual Pair**: Before processing, extract the actual `(name . (index . nil))` pair from the `car` of each list element:
   ```llvm
   %actual_pair_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 4
   %actual_pair = load %ASTNode*, %ASTNode** %actual_pair_ptr
   ```

2. **Use Actual Pair**: Use `actual_pair` instead of `pair_val` when:
   - Checking the pair's `cdr` to get the index
   - Comparing parameter names
   - Accessing the name node

## Changes Made

### `bootstrap/compiler/codegen.ll`

1. **Modified `codegen_dsl_resolve_param`**:
   - Added extraction of actual pair from list element's `car` at the start of `check_pair` label
   - Updated all references from `pair_val` to `actual_pair` when accessing the pair structure
   - Fixed string constant length for `@.str.debug_pair_cdr_null_before_store` from `[41 x i8]` to `[37 x i8]`

## Current Status

✅ **Fixed**: Parameter resolution now correctly extracts the actual pair from the list structure
✅ **Fixed**: The `name` parameter is now found in the parameter list
✅ **Fixed**: The index (0) is correctly retrieved from the pair

❌ **Remaining Issue**: `LLVMGetParam` returns `null` when trying to access the parameter by index, even though:
- The function is created with the correct parameter types
- The entry basic block is created
- The builder is positioned at the end of the entry block
- The parameter count is correct (1 parameter)

This suggests that LLVM function parameters may not be accessible via `LLVMGetParam` until the function is in a more finalized state, or there may be an issue with how the function is being created.

## Debug Output

After the fix, the debug output shows:
```
[CODEGEN] Creating pair with index 0
[DSL-EXPR] Parameter found in list
[DSL-EXPR] Checking pair cdr...OK
[DSL-EXPR] Getting index node...
[DSL-EXPR] Getting parameter at index 0
[DSL-EXPR] ERROR: Parameter value null at index 0
```

This confirms that:
1. The pair is created correctly with the index
2. The parameter is found in the list
3. The pair's `cdr` is correctly accessed (no longer null)
4. The index is correctly extracted
5. But `LLVMGetParam` still returns null

## Next Steps

The parameter resolution structure is now correct. The remaining issue is that `LLVMGetParam` returns null, which is a separate problem that may require:
- Verifying the function type has the correct number of parameters
- Checking if parameters need to be accessed differently
- Investigating if there's a timing issue with when parameters become accessible
- Possibly using a different LLVM API to access parameters

## Related Files

- `bootstrap/compiler/codegen.ll`: Main codegen file with parameter resolution logic
- `test/hello_world.vibe`: Test file that defines the `hello` function with `name` parameter
- `bootstrap/runtime/ffi.ll`: FFI wrappers for LLVM C API functions

## Technical Notes

- The `param_names` list structure is: `((name . (index . nil)) . rest)`
- Each list element is a cons cell created by `codegen_create_cons`
- The actual pair is stored in the `car` of each list element
- The pair structure is: `(name . (index . nil))` where `name` is an AST atom and `index` is an AST atom containing the parameter index
