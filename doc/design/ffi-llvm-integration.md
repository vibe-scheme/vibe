# FFI-Based LLVM Integration Design

## Overview

This document describes the design for integrating LLVM C API into the Vibe bootstrap compiler using FFI (Foreign Function Interface). This approach allows the bootstrap compiler to generate bitcode programmatically via LLVM C API calls while maintaining a pure LLVM IR bootstrap (no C++ dependency).

## Motivation

### Why FFI Instead of C++ Wrapper?

1. **Pure LLVM IR Bootstrap**: The bootstrap compiler is written entirely in LLVM IR. Using FFI allows calling LLVM C API functions without introducing C++ dependencies.

2. **Runtime Flexibility**: FFI enables loading LLVM libraries at runtime, allowing different LLVM versions to be used without recompiling the bootstrap compiler.

3. **Platform Abstraction**: FFI provides a unified interface for loading libraries across platforms (macOS/Linux/Windows).

4. **Future-Proof**: Aligns with the goal of converting bootstrap .ll files to `define-bitcode-*` methods in the 2nd generation bootstrap.

5. **Direct Bitcode Generation**: Instead of generating text IR strings and parsing them, we can generate bitcode directly via LLVM API, which is more efficient and provides better error handling.

## Architecture

### Components

1. **FFI System** (`bootstrap/runtime/ffi.ll`)
   - Library loading (`ffi_load_library`)
   - Symbol resolution (`ffi_get_symbol`)
   - Function calling (`ffi_call`)
   - Platform abstraction (dlopen/dlsym on POSIX, LoadLibrary/GetProcAddress on Windows)

2. **LLVM C API Wrappers** (via FFI)
   - Context management (`llvm_create_context`, `llvm_dispose_context`)
   - Module management (`llvm_create_module`, `llvm_dispose_module`)
   - Type creation (`llvm_create_function_type`, `llvm_create_struct_type`)
   - Function creation (`llvm_create_function`)
   - Constant creation (`llvm_create_constant_string`)
   - Bitcode writing (`llvm_write_bitcode_to_file`)

3. **Code Generator Integration**
   - CodeGen structure extended to store LLVM context/module handles
   - Text IR generation kept as fallback/debugging option
   - LLVM API calls used for primary bitcode generation

## Required LLVM C API Functions

### Context Management
- `LLVMContextRef LLVMContextCreate()`
- `void LLVMContextDispose(LLVMContextRef C)`

### Module Management
- `LLVMModuleRef LLVMModuleCreateWithNameInContext(const char *ModuleID, LLVMContextRef C)`
- `void LLVMDisposeModule(LLVMModuleRef M)`
- `void LLVMSetTarget(LLVMModuleRef M, const char *Triple)`

### Type Creation
- `LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType, LLVMTypeRef *ParamTypes, unsigned ParamCount, int IsVarArg)`
- `LLVMTypeRef LLVMStructType(LLVMTypeRef *ElementTypes, unsigned ElementCount, int Packed)`
- `LLVMTypeRef LLVMInt8TypeInContext(LLVMContextRef C)`
- `LLVMTypeRef LLVMInt32TypeInContext(LLVMContextRef C)`
- `LLVMTypeRef LLVMInt64TypeInContext(LLVMContextRef C)`
- `LLVMTypeRef LLVMVoidTypeInContext(LLVMContextRef C)`
- `LLVMTypeRef LLVMPointerType(LLVMTypeRef ElementType, unsigned AddressSpace)`
- `LLVMTypeRef LLVMArrayType(LLVMTypeRef ElementType, unsigned ElementCount)`

### Function Creation
- `LLVMValueRef LLVMAddFunction(LLVMModuleRef M, const char *Name, LLVMTypeRef FunctionType)`
- `LLVMValueRef LLVMGetParam(LLVMValueRef Fn, unsigned Index)`
- `void LLVMSetValueName(LLVMValueRef Val, const char *Name)`

### Constant Creation
- `LLVMValueRef LLVMConstStringInContext(LLVMContextRef C, const char *Str, unsigned Length, int DontNullTerminate)`
- `LLVMValueRef LLVMConstInt(LLVMTypeRef IntTy, unsigned long long N, int SignExtend)`
- `LLVMValueRef LLVMConstNull(LLVMTypeRef Ty)`

### Basic Block and Instruction Creation
- `LLVMBasicBlockRef LLVMAppendBasicBlock(LLVMValueRef Fn, const char *Name)`
- `LLVMBuilderRef LLVMCreateBuilderInContext(LLVMContextRef C)`
- `void LLVMDisposeBuilder(LLVMBuilderRef Builder)`
- `void LLVMPositionBuilderAtEnd(LLVMBuilderRef Builder, LLVMBasicBlockRef Block)`
- `LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef Builder)`
- `LLVMValueRef LLVMBuildRet(LLVMBuilderRef Builder, LLVMValueRef V)`
- `LLVMValueRef LLVMBuildCall2(LLVMBuilderRef Builder, LLVMTypeRef FnType, LLVMValueRef Fn, LLVMValueRef *Args, unsigned NumArgs, const char *Name)`
- `LLVMValueRef LLVMBuildGEP2(LLVMBuilderRef Builder, LLVMTypeRef Ty, LLVMValueRef Ptr, LLVMValueRef *Indices, unsigned NumIndices, const char *Name)`

### Bitcode Writing
- `int LLVMWriteBitcodeToFile(LLVMModuleRef M, const char *Path)`

## Implementation Approach

### Phase 1: FFI Infrastructure
1. Implement platform-specific library loading (dlopen/dlsym on POSIX)
2. Implement symbol resolution
3. Implement function pointer calling mechanism
4. Test with simple C library functions

### Phase 2: LLVM Library Loading
1. Load LLVM libraries at runtime via FFI
2. Resolve LLVM C API function symbols
3. Create function pointer wrappers for LLVM functions
4. Test library loading and symbol resolution

### Phase 3: LLVM API Wrappers
1. Implement wrappers for context management
2. Implement wrappers for module management
3. Implement wrappers for type creation
4. Implement wrappers for function creation
5. Implement wrappers for constant creation
6. Implement wrappers for bitcode writing

### Phase 4: Code Generator Integration
1. Extend CodeGen structure to store LLVM context/module handles
2. Initialize LLVM context in `codegen_init()`
3. Create LLVM module in `codegen_init()`
4. Replace text IR generation with LLVM API calls:
   - `codegen_define_bitcode_type` → use `llvm_create_struct_type()`
   - `codegen_define_bitcode_constant` → use `llvm_create_constant_string()`
   - `codegen_define_bitcode_function` → use `llvm_create_function()`
   - `codegen_main` → use `llvm_create_function()` for main
5. Replace `codegen_get_ir()` with `llvm_write_bitcode_to_file()`

### Phase 5: Migration Strategy
1. Keep text IR generation working (current state)
2. Add LLVM API calls alongside text IR (parallel implementation)
3. Switch to LLVM API by default (new default)
4. Keep text IR as fallback (for debugging)

## Migration Path

### Current State (1st Gen Bootstrap)
- Text IR generation: CodeGen generates LLVM IR as text strings
- Output: `.ll` files (text IR)
- Compilation: Text IR → bitcode via `llvm-as`

### Target State (1st Gen Bootstrap with FFI)
- LLVM API generation: CodeGen uses LLVM C API to generate bitcode
- Output: `.bc` files (bitcode) directly
- Compilation: Direct bitcode generation, no text IR intermediate

### Future State (2nd Gen Bootstrap)
- Bootstrap .ll files converted to `define-bitcode-*` methods
- FFI used for LLVM C API calls from Vibe code
- Self-hosted compiler written in Vibe itself

## Platform-Specific Considerations

### macOS
- Use `dlopen`/`dlsym` (built into libc)
- LLVM libraries typically in `/opt/homebrew/opt/llvm/lib` or `/usr/local/opt/llvm/lib`
- Library names: `libLLVM.dylib` or component libraries

### Linux
- Use `dlopen`/`dlsym` (requires libdl)
- LLVM libraries typically in `/usr/lib/llvm-21/lib` or similar
- Library names: `libLLVM-21.so` or component libraries

### Windows (Future)
- Use `LoadLibrary`/`GetProcAddress`
- LLVM libraries typically in LLVM installation directory
- Library names: `LLVM.dll` or component DLLs

## Error Handling

- FFI functions should return error codes or null pointers on failure
- LLVM API errors should be checked and reported
- Error messages should include context (function name, parameters)
- Fallback to text IR generation if LLVM API fails

## Testing Strategy

1. Test FFI library loading with simple C libraries
2. Test LLVM library loading and symbol resolution
3. Test LLVM API wrappers individually
4. Test code generator integration with simple programs
5. Compare output from text IR vs LLVM API generation
6. Test error handling and fallback mechanisms

## Benefits

1. **Pure LLVM IR Bootstrap**: No C++ dependency, maintains pure LLVM IR bootstrap
2. **Runtime Flexibility**: Can load different LLVM versions at runtime
3. **Platform Abstraction**: FFI handles platform differences
4. **Future-Proof**: Aligns with 2nd gen bootstrap goals
5. **Direct Bitcode Generation**: More efficient than text IR → bitcode conversion
6. **Better Error Handling**: LLVM API provides better validation and error reporting
7. **No Text Parsing**: Avoids parsing text IR, which is error-prone

## Challenges

1. **Function Pointer Calling**: Need to handle calling conventions correctly
2. **Type Mapping**: Map Vibe types to LLVM types correctly
3. **Memory Management**: LLVM objects need proper disposal
4. **Error Handling**: Need robust error handling for FFI calls
5. **Platform Differences**: Handle platform-specific library loading

## References

- [LLVM C API Documentation](https://llvm.org/doxygen/group__LLVMC.html)
- [LLVM C API Examples](https://llvm.org/docs/tutorial/MyFirstLanguageFrontend/LangImpl03.html)
- POSIX dlopen/dlsym documentation
- Windows LoadLibrary/GetProcAddress documentation
