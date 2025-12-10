# Chat 0005: Migrate LLVM IR Generation to C API

**Date**: 2025-12-06
**Context**: Migrating from text-based LLVM IR generation to direct LLVM C API calls for programmatic bitcode generation

## Overview

This conversation focused on implementing the migration from string-based LLVM IR generation to direct calls to the LLVM C API. The goal is to enable programmatic bitcode generation using statically linked LLVM libraries, moving away from text IR strings. This is a critical step toward enabling the `define-bitcode-*` primitives to work with parsed IR bodies and eventually support self-hosting.

## Implementation Plan

The migration was planned in 6 phases:

1. **Phase 1**: Implement LLVM C API wrappers in `ffi.ll`
2. **Phase 2**: Extend CodeGen structure and update initialization
3. **Phase 3**: Replace codegen functions with LLVM API calls (types, constants, functions, main, calls)
4. **Phase 4**: Replace output mechanism with bitcode writing
5. **Phase 5**: Implement IR body parsing helper using `LLVMParseIRInContext`
6. **Phase 6**: Testing and validation

## Phase 1: LLVM C API Wrappers

### External Declarations

Added external declarations for over 30 LLVM C API functions in `bootstrap/runtime/ffi.ll`:

- Context management: `LLVMContextCreate`, `LLVMContextDispose`
- Module management: `LLVMModuleCreateWithNameInContext`, `LLVMModuleDispose`, `LLVMSetTarget`
- Type creation: `LLVMInt8TypeInContext`, `LLVMInt32TypeInContext`, `LLVMInt64TypeInContext`, `LLVMVoidTypeInContext`, `LLVMPointerType`, `LLVMArrayType`, `LLVMStructTypeInContext`, `LLVMFunctionType`
- Constant creation: `LLVMConstStringInContext`, `LLVMConstInt`, `LLVMConstNull`
- Function management: `LLVMAddFunction`, `LLVMGetParam`, `LLVMSetValueName`
- Basic block management: `LLVMAppendBasicBlock`
- Builder management: `LLVMCreateBuilderInContext`, `LLVMDisposeBuilder`, `LLVMPositionBuilderAtEnd`
- Instruction building: `LLVMBuildRetVoid`, `LLVMBuildRet`, `LLVMBuildCall2`, `LLVMBuildGEP2`
- Global variable management: `LLVMAddGlobal`, `LLVMSetInitializer`, `LLVMSetGlobalConstant`, `LLVMSetLinkage`
- IR parsing: `LLVMParseIRInContext`, `LLVMCreateMemoryBufferWithMemoryRangeCopy`, `LLVMDisposeMemoryBuffer`
- Bitcode writing: `LLVMWriteBitcodeToFile`

### Opaque Pointer Types

Defined LLVM opaque pointer types:
- `%LLVMContextRef`, `%LLVMModuleRef`, `%LLVMTypeRef`, `%LLVMValueRef`, `%LLVMBasicBlockRef`, `%LLVMBuilderRef`, `%LLVMMemoryBufferRef`

### Wrapper Functions

Implemented wrapper functions for all LLVM operations, providing a consistent interface and error handling.

## Phase 2: CodeGen Structure Extension

### Extended Structure

Updated `%CodeGen` type to include:
```llvm
%CodeGen = type { 
    i8*,              ; ir_buffer (text IR for backward compatibility)
    i64,              ; buffer_size
    i64,              ; buffer_pos
    i32,              ; string_counter
    i32,              ; label_counter
    %LLVMContextRef,  ; llvm_context
    %LLVMModuleRef,   ; llvm_module
    %LLVMBuilderRef   ; llvm_builder (for generating instructions)
}
```

### Initialization

Updated `codegen_init()` to:
- Initialize LLVM FFI
- Create LLVM context
- Create LLVM module with name "vibe"
- Set target triple via LLVM API
- Initialize builder pointer to null (created when needed)

### Cleanup

Added `codegen_dispose()` to properly:
- Dispose builder (if created)
- Dispose module
- Dispose context
- Free text IR buffer
- Free CodeGen structure

## Phase 3: Codegen Function Migration

### Phase 3.5: String Literal Generation

Updated `codegen_string_literal()` to use LLVM API:
- Creates string constant using `llvm_create_constant_string()`
- Adds global variable using `llvm_add_global()`
- Sets initializer, constant flag, and linkage
- Maintains text IR generation for backward compatibility

### Phase 3.4: Main Function Generation

Completely rewrote `codegen_main()` to use LLVM API:
- Gets i32 type for return type
- Creates function type `i32 ()` (no parameters)
- Adds main function to module
- Creates entry basic block (with name "entry" - **critical fix**)
- Creates builder and positions it at end of entry block
- Stores builder in CodeGen structure for use by call generation
- Generates return i32 0 instruction
- Maintains text IR generation for backward compatibility

### Phase 3.3: Function Definition Parsing

Started implementation of `codegen_parse_function_ir()`:
- Wraps function IR in minimal module (with target triple)
- Parses IR using `LLVMParseIRInContext`
- Currently creates temporary module (function merging not yet implemented)
- Disabled in `codegen_define_bitcode_function()` until merging is complete

### Phase 3.1-3.2: Types and Constants

Not yet implemented - still using text IR generation.

### Phase 3.6: Call Generation

Not yet implemented - still using text IR generation. Requires:
- Function lookup by name
- Argument value generation
- Builder-based call instruction generation

## Phase 4: Bitcode Output

### Implementation

Updated `codegen_write_bitcode()` to:
- Get LLVM module from CodeGen structure
- Call `llvm_write_bitcode_to_file()` directly
- Write bitcode format instead of text IR

### Main Function Updates

Updated `main.ll` to:
- Call `codegen_write_bitcode()` instead of `codegen_get_ir()` and `write_file()`
- Handle `.bc` file extension
- Call `codegen_dispose()` for cleanup

### Test Script Updates

Updated `test/run_test.sh` to:
- Expect `.bc` output instead of `.ll`
- Remove `llvm-as` step (compiler now generates bitcode directly)
- Update file existence checks

## Critical Bug Fix: LLVMAppendBasicBlock Segfault

### Problem

The compiler was segfaulting in `LLVMAppendBasicBlock` with:
```
EXC_BAD_ACCESS (code=1, address=0x0)
frame #0: LLVMAppendBasicBlock + 102
```

### Root Cause

`LLVMAppendBasicBlock` requires a **non-null block name**, even though the LLVM C API documentation suggests `null` is acceptable. Passing `null` caused an internal null pointer dereference.

### Solution

Changed from:
```llvm
%entry_block = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %main_func, i8* null)
```

To:
```llvm
%entry_block_name = bitcast [6 x i8]* @.str.entry_block_name to i8*  ; "entry"
%entry_block = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %main_func, i8* %entry_block_name)
```

### Impact

This fix enabled:
- Basic block creation
- Builder positioning
- Instruction generation
- Complete main function generation via LLVM API

## Memory Buffer Safety

### Improvements

Added safety checks in `llvm_parse_ir_in_context()`:
- Null checks before disposing memory buffers
- Proper error handling for buffer creation failures
- Separate error paths for parse failures vs. buffer disposal

## Results

### Before Migration

- Text-based IR generation only
- Required `llvm-as` to convert text IR to bitcode
- No programmatic control over LLVM structures

### After Migration

- ✅ LLVM context and module initialization working
- ✅ Main function creation via LLVM API working
- ✅ Basic block creation working
- ✅ Builder creation and positioning working
- ✅ Return statement generation working
- ✅ Bitcode file generation working
- ✅ Valid bitcode output verified with `llvm-dis`

### Generated Bitcode Example

```llvm
; ModuleID = 'test/hello_world.bc'
source_filename = "vibe"
target triple = "x86_64-apple-macosx10.15.0"

define i32 @main() {
entry:
  ret i32 0
}
```

## Files Modified

### Core Implementation
- `bootstrap/runtime/ffi.ll`: Added LLVM C API wrappers and declarations
- `bootstrap/compiler/codegen.ll`: Extended CodeGen structure, migrated main function and string literal generation
- `bootstrap/compiler/main.ll`: Updated to use bitcode output and cleanup

### Test Infrastructure
- `test/run_test.sh`: Updated to handle `.bc` files directly

### New String Constants
- `@.str.module_name`: `"vibe"`
- `@.str.target_triple_value`: `"x86_64-apple-macosx10.15.0"`
- `@.str.main_name`: `"main"`
- `@.str.entry_block_name`: `"entry"`
- `@.str.target_triple_prefix`: `"target triple = \""`
- `@.str.target_triple_suffix`: `"\"\n\n"`

## Technical Challenges

### String Constant Handling

LLVM IR string constants require careful handling:
- Must use `bitcast` to convert array pointers to `i8*` for API calls
- Proper escaping in string literals (`\22` for quotes)
- Correct array sizes including null terminators

### Function Type Creation

For functions with no parameters:
- Pass `null` for `param_types` array pointer
- Pass `0` for `param_count`
- LLVM handles this correctly

### Module State Management

- Module must have target triple set before adding functions
- Functions must have basic blocks before generating instructions
- Builder must be positioned at end of basic block before building instructions

## Remaining Work

### High Priority
1. **Phase 3.6**: Replace `codegen_call()` with LLVM API calls
   - Function lookup by name (`LLVMGetNamedFunction`)
   - Argument value generation (string constants, etc.)
   - Builder-based call instruction generation

2. **Function Merging**: Implement extraction of functions from parsed temporary modules into main module
   - Currently `codegen_parse_function_ir()` creates temp modules that are disposed
   - Need to iterate over functions in temp module and clone to main module

### Medium Priority
3. **Phase 3.1**: Replace `codegen_define_bitcode_type()` with LLVM API calls
   - Parse type field strings to LLVM types
   - Create struct types programmatically

4. **Phase 3.2**: Replace `codegen_define_bitcode_constant()` with LLVM API calls
   - Parse constant type strings
   - Create constants programmatically
   - Handle bytevector constants

### Low Priority
5. **IR Body Parsing**: Complete implementation of instruction extraction from parsed IR
   - Currently parses but doesn't extract instructions
   - Need to iterate over basic blocks and instructions

6. **Error Handling**: Improve error messages and validation
   - Better validation of LLVM API return values
   - More informative error messages

## Related Documentation

- LLVM C API documentation
- Previous chat: `0004-string-constant-generation-fix.md`
- Design document: `doc/design/ffi-llvm-integration.md` (if exists)

## Lessons Learned

1. **API Documentation Can Be Misleading**: `LLVMAppendBasicBlock` documentation suggests `null` is acceptable for block name, but implementation requires non-null.

2. **Hybrid Approach Works**: Maintaining text IR generation alongside LLVM API calls provides backward compatibility and allows incremental migration.

3. **Memory Management**: LLVM C API requires careful attention to object lifetimes. Always dispose objects in reverse order of creation.

4. **Type Safety**: LLVM opaque pointer types (`%LLVMValueRef`, etc.) require careful null checking and validation.

5. **Incremental Migration**: Migrating one function at a time allows testing and validation at each step.

## Next Steps

1. Implement function call generation via LLVM API (Phase 3.6)
2. Implement function merging from parsed modules
3. Complete type and constant generation migration
4. Add comprehensive error handling and validation
5. Performance testing and optimization
