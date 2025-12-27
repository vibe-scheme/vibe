# Chat 0018: llvm:label Position Fix, Debug Cleanup, and Array Type Parsing

**Date**: 2025-12-26
**Context**: Fixing llvm:label builder position management, cleaning up debug file generation, fixing lexer printf security issue, and investigating array type parsing for constant creation

## Overview

This session addressed multiple issues: fixed a critical bug in `llvm:label` DSL primitive where builder position wasn't being restored, cleaned up extensive debug file generation code that was no longer needed, fixed a security vulnerability in lexer debug output, and began investigating array type parsing for constant creation. During the array type investigation, we identified a fundamental architectural issue with parser/codegen separation.

## Problem 1: llvm:label Builder Position Management

### Issue

The `llvm:label` DSL primitive was incorrectly managing the LLVM IR builder position. When positioning the builder at a label block, subsequent expressions were being generated in the wrong basic block because the builder position wasn't restored after evaluating the label's body.

**Symptoms**:
- Expressions after `llvm:label` were appearing in the label block instead of the original block
- Control flow was incorrect in generated bitcode
- Multiple labels with the same name were being created

### Root Cause

The `codegen_dsl_label` function was:
1. Positioning the builder at the target label block
2. Evaluating the label's body expressions
3. **Not restoring** the builder to its original position

This caused all subsequent expressions to be generated in the label block.

### Solution

**File**: `bootstrap/compiler/codegen.ll`

Implemented a "save/restore builder position" strategy:

1. **Save current position** before positioning at label:
   ```llvm
   %saved_block = call %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder)
   ```

2. **Position builder at label block**:
   ```llvm
   call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %label_block)
   ```

3. **Evaluate label body**:
   ```llvm
   call void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %body)
   ```

4. **Restore builder position**:
   ```llvm
   call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %saved_block)
   ```

**Files Modified**:
- `bootstrap/runtime/ffi.ll`: Added `llvm_get_insert_block` wrapper for `LLVMGetInsertBlock`
- `bootstrap/compiler/codegen.ll`: Added save/restore logic in `codegen_dsl_label`

### Duplicate Label Prevention

Also fixed `codegen_get_or_create_label` to check for existing basic blocks before creating new ones:

1. **Iterate through existing blocks** using `llvm_get_first_basic_block` and `llvm_get_next_basic_block`
2. **Compare block names** using `llvm_get_basic_block_name` and `strncmp`
3. **Reuse existing block** if found, otherwise create new one

**Files Modified**:
- `bootstrap/runtime/ffi.ll`: Added basic block iteration wrappers:
  - `llvm_get_first_basic_block`
  - `llvm_get_next_basic_block`
  - `llvm_get_basic_block_name`
- `bootstrap/compiler/codegen.ll`: Added duplicate checking logic in `codegen_get_or_create_label`

## Problem 2: Debug File Generation Cleanup

### Issue

Extensive debug file generation code was scattered throughout the codebase, generating files like:
- `debug_func_ir.ll`
- `debug_call_lookup.ll`
- `debug_top_level_exprs.ll`
- `debug_module_ir.ll`
- `debug_extract_func_name.ll`
- `debug_output.ll`
- `debug_output.bc`

These files were no longer needed and cluttered the build output.

### Solution

**Files Modified**:
- `bootstrap/compiler/codegen.ll`: Removed all `open`/`write`/`close` calls and conditional branches for debug file generation from:
  - `codegen_define_bitcode_function`
  - `codegen_call`
  - `codegen_append_top_level_exprs`
  - `codegen_parse_function_ir`
  - `codegen_emit_debug_files` (entire function removed)
- `bootstrap/compiler/main.ll`: Removed call to `codegen_emit_debug_files` and its declaration
- Deleted all debug file generation files (6 files removed)

**Result**: Cleaner codebase, no debug file clutter, simpler build output.

## Problem 3: Lexer printf Security Vulnerability

### Issue

The `lex_debug_log_token` function in the lexer was calling `printf` with user-controlled token values directly as the format string:

```llvm
call i32 (i8*, ...) @printf(i8* %buf)  ; UNSAFE!
```

This is a format string injection vulnerability. If a token value contained format specifiers like `%s`, `%x`, `%n`, etc., `printf` would interpret them, potentially causing:
- Crashes (segfaults from invalid pointers)
- Information disclosure (reading arbitrary memory)
- Code execution (with `%n` specifier)

**Symptom**: Segfault when compiling `test/hello_world.vibe` with token values containing `%` characters.

### Solution

**Files Modified**:
- `bootstrap/lexer/lexer.ll`: Changed to use explicit format string:
  ```llvm
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_token_value_fmt, i32 0, i32 0), i8* %buf)
  ```
  Where `@.str.debug_token_value_fmt = private unnamed_addr constant [3 x i8] c"%s\00"`
- `bootstrap/lexer/lexer_no_vibe.ll`: Applied same fix for synchronization

**Result**: Safe string printing, prevents format string injection attacks.

## Problem 4: Array Type Parsing for Constant Creation

### Issue

When compiling `test/hello_world.vibe` with:
```scheme
(llvm:define-constant hello-string |[11 x i8]| #u8(72 101 108 108 111 44 32 37 115 33 0))
```

LLVM reported:
```
Global variable initializer type does not match global variable type!
ptr @hello-string
```

The constant was being created with type `ptr` instead of `[11 x i8]`, causing a type mismatch with the initializer.

### Root Cause

1. **Array Type Parsing Not Implemented**: The `codegen_resolve_type_string` function had a placeholder that always returned `i8*` pointer type for array types instead of parsing `[N x i8]` format.

2. **Constant Creation Issue**: The `dont_null_terminate` parameter was set to `0`, causing `LLVMConstStringInContext` to add an extra null terminator even though bytevectors already include one.

### Solution

**File**: `bootstrap/compiler/codegen.ll`

1. **Implemented Array Type Parsing** (lines ~3746-3926):
   - Added parsing logic in `parse_array_common` block
   - Searches for " x " pattern to extract array size `N`
   - Validates element type is `i8`
   - Creates array type using `llvm_get_array_type`

2. **Fixed Constant Creation** (line ~823):
   - Changed `dont_null_terminate` from `0` to `1`
   - Bytevectors already include null terminators, so we shouldn't add another

3. **Added Debug Output**:
   - Added type length and first character debugging
   - Added format string constants for safe string printing

### Current Status

**Not Working**: The array parsing code was implemented but is not being reached during execution. Debug output shows type string `[11 x i8]` is correctly extracted, but the `check_array` block is never reached, suggesting a control flow issue.

## Architectural Issue: Parser/Codegen Separation

### Problem Discovered

During array type parsing investigation, we identified that `codegen_resolve_type_string` contains extensive logic for handling Scheme syntax:
- Vertical bar stripping: `|%Foo|` → `%Foo`, `|[11 x i8]|` → `[11 x i8]`
- Multiple syntax variations for the same type
- Complex branching logic for different syntax forms

**This violates separation of concerns**:
- **Parser** should normalize syntax and produce clean AST nodes
- **Codegen** should only handle semantic type resolution (mapping type names to LLVM types)

### Current State

The codegen layer handles:
- `|%Foo|` vs `%Foo` (vertical bar syntax)
- `|i8*|` vs `i8*` (pointer syntax with bars)
- `|[11 x i8]|` vs `[11 x i8]` (array syntax with bars)
- Named types, primitive types, array types, pointer types

### Desired State

The parser should:
- Strip vertical bars during tokenization/parsing
- Pass normalized type strings to codegen: `%Foo`, `i8*`, `[11 x i8]`
- Handle all Scheme syntax variations

The codegen should:
- Only handle semantic type resolution
- Map type names to LLVM types
- Parse array format `[N x i8]` (this is semantic, not syntax)
- Look up named types, resolve primitive types

### Benefits

1. **Simpler Codegen**: Remove ~200+ lines of syntax handling code
2. **Better Error Messages**: Parser can report syntax errors with better context
3. **Easier Testing**: Can test parser and codegen independently
4. **Maintainability**: Changes to syntax only affect parser, not codegen
5. **Correctness**: Single source of truth for syntax normalization

## Files Modified

1. **bootstrap/compiler/codegen.ll**:
   - Fixed `llvm:label` builder position management (save/restore pattern)
   - Fixed duplicate label prevention (check existing blocks)
   - Removed all debug file generation code
   - Implemented array type parsing logic
   - Fixed constant creation null terminator handling
   - Added debug output for type resolution

2. **bootstrap/compiler/main.ll**:
   - Removed call to `codegen_emit_debug_files`
   - Removed declaration for `codegen_emit_debug_files`

3. **bootstrap/lexer/lexer.ll** and **bootstrap/lexer/lexer_no_vibe.ll**:
   - Fixed `printf` format string injection vulnerability
   - Added safe format string constant

4. **bootstrap/runtime/ffi.ll**:
   - Added basic block iteration wrappers:
     - `llvm_get_insert_block`
     - `llvm_get_first_basic_block`
     - `llvm_get_next_basic_block`
     - `llvm_get_basic_block_name`

5. **CMakeLists.txt**:
   - Added TODO comment about investigating `LLVMLinkModules2` API for direct bitcode linking

6. **Deleted Files** (debug file generation):
   - `debug_call_lookup.ll`
   - `debug_extract_func_name.ll`
   - `debug_func_ir.ll`
   - `debug_module_ir.ll`
   - `debug_output.ll`
   - `debug_top_level_exprs.ll`

## Related Documentation

- `AGENTS.md` - Updated with Core Principle #6: Parser/Codegen Separation
- `doc/chats/0017-temp-module-disposal-and-dsl-extension-patterns.md` - DSL extension patterns
- `doc/chats/0003-bytevector-and-vertical-bar-syntax.md` - Vertical bar syntax discussion

## Key Learnings

1. **Builder Position Management**: LLVM builder position must be explicitly saved and restored when temporarily positioning at different blocks.

2. **Security Best Practices**: Always use explicit format strings with `printf` to prevent format string injection attacks.

3. **Code Cleanup**: Removing unused debug code improves maintainability and reduces complexity.

4. **Architectural Debt**: Codegen layer has accumulated parsing responsibilities that should be in the parser phase.

5. **Type Resolution Complexity**: Current type resolution logic is complex because it handles both syntax normalization and semantic resolution.

## Next Steps

1. **Parser Normalization** (High Priority):
   - Move vertical bar stripping to parser phase
   - Have parser normalize all type syntax before passing to codegen
   - Update parser to strip `|` bars from type tokens

2. **Simplify Codegen**:
   - Remove syntax handling code from `codegen_resolve_type_string`
   - Simplify type resolution to only handle semantic mapping
   - Keep array parsing (it's semantic, not syntax)

3. **Fix Array Type Parsing**:
   - Once parser normalization is done, verify array parsing works
   - Test with normalized input `[11 x i8]` instead of `|[11 x i8]|`
   - Ensure constant creation uses correct array type

4. **Testing**:
   - Test `llvm:label` with multiple labels to verify position management
   - Test constant creation with array types
   - Verify type resolution works with normalized input

## Success Criteria

1. ✅ Fixed `llvm:label` builder position management
2. ✅ Fixed duplicate label creation
3. ✅ Removed all debug file generation code
4. ✅ Fixed lexer printf security vulnerability
5. ⚠️ Array type parsing implemented but not yet working (control flow issue)
6. ✅ Identified architectural issue with parser/codegen separation
7. ✅ Documented architectural principle in AGENTS.md

## Technical Notes

### Builder Position Save/Restore Pattern

When temporarily positioning the builder at a different block:
1. Save current position with `llvm_get_insert_block`
2. Position at target block
3. Perform operations
4. Restore saved position

This ensures subsequent operations continue in the original block.

### Format String Injection Prevention

Always use explicit format strings:
```llvm
; UNSAFE:
call i32 (i8*, ...) @printf(i8* %user_string)

; SAFE:
call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.fmt, i32 0, i32 0), i8* %user_string)
```

### Array Type Format

The array type format is: `[N x element-type]`
- `N`: Number of elements (parsed as integer)
- `element-type`: Currently only `i8` is supported in parsing logic
- Example: `[11 x i8]` means array of 11 i8 values

### LLVM ConstStringInContext Behavior

- `LLVMConstStringInContext(context, str, len, dont_null_terminate)`:
  - If `dont_null_terminate=0`: Creates `[len+1 x i8]` (adds null terminator)
  - If `dont_null_terminate=1`: Creates `[len x i8]` (no extra null terminator)
- Our bytevectors already include null terminators, so we use `dont_null_terminate=1`
