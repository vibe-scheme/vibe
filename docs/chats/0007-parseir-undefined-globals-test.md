# Chat 0007: Testing LLVM parseIR Behavior with Undefined Globals

**Date**: 2025-12-11
**Model**: Cursor Composer 1
**Context**: Testing whether LLVM's `LLVMParseIRInContext` automatically creates implicit external declarations for undefined globals, or requires explicit declarations

## Overview

This session tested the behavior of LLVM's IR parser when encountering undefined global references. The goal was to verify whether the parser automatically creates placeholder externals (as suggested in some documentation) or requires explicit declarations (as currently implemented in the bootstrap compiler).

## Question

Does LLVM's `llvm_parse_ir_in_context` (parseIR) automatically create implicit external declarations for undefined globals, or does it require explicit declarations?

## Test Approach

### Step 1: Command Line Test with llvm-as

Created a minimal test IR file (`test_undefined_global.ll`) that references `@hello_string` without declaring it:

```llvm
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

declare i32 @printf(i8* nocapture, ...)

define void @hello(i8* %name) {
  %format = getelementptr [14 x i8], [14 x i8]* @hello_string, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* %format, i8* %name)
  ret void
}
```

**Result**: `llvm-as` failed with error:
```
error: use of undefined value '@hello_string'
```

### Step 2: Programmatic Test with LLVM C API

Created a C test program (`test_parseir.c`) that:
1. Creates an LLVM context
2. Creates a memory buffer from the IR string
3. Calls `LLVMParseIRInContext` to parse the IR
4. Checks the parse result

**Result**: `LLVMParseIRInContext` returned `1` (failure), indicating the parser does NOT automatically create implicit externals.

## Conclusion

**Both `llvm-as` and `LLVMParseIRInContext` require explicit external declarations for undefined globals.**

The parser does NOT automatically create placeholder GlobalVariables with external linkage. This confirms:

1. **Current implementation is correct**: The bootstrap compiler's `codegen.ll` correctly adds explicit external declarations for referenced globals (like `@hello_string` and `@printf`).

2. **Comments are accurate**: The comments in `codegen.ll` stating "LLVM's IR parser requires explicit external declarations for undefined globals" are correct.

3. **No changes needed**: The current approach that manually adds external declarations is the correct implementation.

## Technical Details

- **LLVM Version**: 21.1.6
- **Test Platform**: macOS (x86_64-apple-macosx10.15.0)
- **API Used**: `LLVMParseIRInContext` from `llvm-c/IRReader.h`

## Files Modified

- `CMakeLists.txt` - Temporarily added `test_parseir` target (removed during cleanup)

## Files Created (and cleaned up)

- `test_undefined_global.ll` - Test IR file (deleted)
- `test_parseir.c` - C test program (deleted)
- `test_parseir_results.md` - Test results documentation (deleted)

All test files were removed after confirming the results, as they were temporary investigation files.

## Related Documentation

- `bootstrap/compiler/codegen.ll` - Contains comments about explicit external declarations (lines 2154, 2214)
- `docs/chats/0005-llvm-c-api-migration.md` - Previous work on LLVM C API integration

## Key Takeaway

The bootstrap compiler's current approach of explicitly declaring external symbols is correct and necessary. LLVM's IR parser is strict about undefined references and does not create implicit externals, matching the behavior of `llvm-as`.
