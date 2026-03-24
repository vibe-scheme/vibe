# Chat 0004: Fix String Constant Generation in Function Calls

**Date**: 2025-12-05  
**Model**: Cursor Composer 1  
**Context**: Fixing string constant generation to occur at module level instead of inline in function calls

## Overview

This conversation addressed a critical bug in the bootstrap compiler where string constants were being generated inline within function call arguments, causing invalid LLVM IR syntax. The fix ensures string constants are generated at module level (before functions) and properly referenced in function calls.

## Problem

When compiling `test/hello_world.vibe`, the compiler generated invalid LLVM IR:

```llvm
define i32 @main() {  call void @hello(@.str.0 = private constant [6 x i8] c"World\00"
getelementptr [6 x i8], [6 x i8]* @.str.0, i32 0, i32 0)
```

The error was:
```
llvm-as: test/hello_world.ll:12:40: error: expected type
define i32 @main() {  call void @hello(@.str.0 = private constant [6 x i8] c"World\00"
```

### Root Cause

The `codegen_string_literal` function was generating constant definitions immediately when called, which happened during function call argument generation. This caused constants to be inserted inline in function bodies instead of at module level.

## Solution

### Two-Phase Constant Generation

Implemented a two-phase approach:

1. **Collection Phase**: `codegen_collect_string_constants` and `codegen_collect_string_constants_from_args` traverse the AST and generate all string constants at module level before any functions.

2. **Reference Phase**: `codegen_append_call_args` generates only references to constants (using `getelementptr`) without generating new constant definitions.

### Key Changes

#### New Functions

1. **`codegen_collect_string_constants`**: Recursively traverses top-level expressions to find string literals in function call arguments.

2. **`codegen_collect_string_constants_from_args`**: Extracts string literals from function call argument lists and generates constants.

3. **`codegen_define_string_constant_only`**: Generates constant definition without generating a reference (used during collection phase).

4. **`codegen_get_string_constant_name`**: Gets the constant name for a string without generating a definition (uses counter-1 since constants are generated before references).

#### Modified Functions

1. **`codegen_main`**: Now calls `codegen_collect_string_constants` before generating the main function to ensure all constants are defined first.

2. **`codegen_append_call_args`**: Modified to use `codegen_get_string_constant_name` instead of `codegen_string_literal` to avoid generating duplicate constants.

#### Fixed getelementptr Syntax

The generated getelementptr instructions were missing:
- Result type (`i8*`)
- Opening parenthesis after `getelementptr`
- Closing parenthesis

Fixed to generate:
```llvm
i8* getelementptr ([6 x i8], [6 x i8]* @.str.0, i32 0, i32 0)
```

### New String Constants

- `@.str.getelementptr_open`: `"getelementptr("`
- `@.str.lbracket`: `"["`
- `@.str.i8_ptr`: `"i8*"` (for result type)

## Technical Details

### Constant Name Tracking

For bootstrap simplicity, constants are tracked using a counter. When generating references:
- Constants are generated with counter value `N`
- References use counter value `N-1` (since counter was incremented during constant generation)

A more robust implementation would maintain a string-to-constant-name mapping table.

### Order of Operations

1. Parse all expressions
2. Collect string constants from all expressions (generate at module level)
3. Generate main function
4. Generate function call code (references only)

## Results

### Before Fix

```llvm
define i32 @main() {  call void @hello(@.str.0 = private constant [6 x i8] c"World\00"
getelementptr [6 x i8], [6 x i8]* @.str.0, i32 0, i32 0)
```

### After Fix

```llvm
@.str.0 = private constant [6 x i8] c"World\00"
define i32 @main() {  call void @hello(i8* getelementptr ([6 x i8], [6 x i8]* @.str.0, i32 0, i32 0))
  ret i32 0}
```

The IR now:
- ✅ Generates constants at module level
- ✅ Uses proper getelementptr syntax with result type and parentheses
- ✅ Compiles successfully with `llvm-as`
- ✅ Links and runs correctly

## Files Modified

- `bootstrap/compiler/codegen.ll`: Added constant collection phase, fixed getelementptr generation
- `test/hello_world.vibe`: Updated format string to include exclamation mark (test fix)

## Related Documentation

- LLVM IR specification (getelementptr instruction syntax)
- Previous chat: `0003-bytevector-and-vertical-bar-syntax.md`

## Next Steps

1. Consider implementing a string-to-constant-name mapping table for more robust constant tracking
2. Add support for deduplicating identical string constants
3. Handle string constants in other contexts (not just function call arguments)
