; Bootstrap FFI System for Vibe
; Foreign Function Interface for calling C libraries
; Platform abstraction layer for POSIX and Windows
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; FFI type enum
; FFI_TYPE_VOID = 0
; FFI_TYPE_INT8 = 1
; FFI_TYPE_INT16 = 2
; FFI_TYPE_INT32 = 3
; FFI_TYPE_INT64 = 4
; FFI_TYPE_FLOAT = 5
; FFI_TYPE_DOUBLE = 6
; FFI_TYPE_POINTER = 7
; FFI_TYPE_STRING = 8

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%LibraryHandle = type opaque
%FunctionPtr = type i8*
%FFICallSignature = type { i32, i32*, i32 }

; Load dynamic library
; ffi_load_library: Load a dynamic library
; Parameters:
;   path: Library path (null-terminated string)
; Returns: Library handle, or null on error
define %LibraryHandle* @ffi_load_library(i8* %path) {
entry:
    ; Platform-specific implementation
    ; On macOS: use dlopen
    ; On Linux: use dlopen
    ; On Windows: use LoadLibrary
    
    ; For now, declare as external - will be implemented in platform-specific code
    ; This is a placeholder that will call the actual platform function
    %handle = call %LibraryHandle* @ffi_dlopen(i8* %path)
    ret %LibraryHandle* %handle
}

; Get symbol from library
; ffi_get_symbol: Get a symbol (function pointer) from a library
; Parameters:
;   handle: Library handle
;   symbol: Symbol name (null-terminated string)
; Returns: Function pointer, or null on error
define %FunctionPtr @ffi_get_symbol(%LibraryHandle* %handle, i8* %symbol) {
entry:
    ; Platform-specific implementation
    ; On macOS/Linux: use dlsym
    ; On Windows: use GetProcAddress
    
    %func = call %FunctionPtr @ffi_dlsym(%LibraryHandle* %handle, i8* %symbol)
    ret %FunctionPtr %func
}

; Close library
; ffi_close_library: Close a dynamic library
; Parameters:
;   handle: Library handle
; Returns: 0 on success, non-zero on error
define i32 @ffi_close_library(%LibraryHandle* %handle) {
entry:
    ; Platform-specific implementation
    ; On macOS/Linux: use dlclose
    ; On Windows: use FreeLibrary
    
    %result = call i32 @ffi_dlclose(%LibraryHandle* %handle)
    ret i32 %result
}

; Call foreign function (simple version for common types)
; ffi_call: Call a foreign function
; Parameters:
;   func: Function pointer
;   return_type: Return type
;   args: Array of argument values (as i64)
;   arg_count: Number of arguments
; Returns: Return value (as i64, cast appropriately)
define i64 @ffi_call(%FunctionPtr %func, i32 %return_type, i64* %args, i32 %arg_count) {
entry:
    ; This is a simplified FFI call mechanism
    ; In a full implementation, this would use libffi or similar
    ; For bootstrap, we'll provide a basic mechanism
    
    ; Convert function pointer to appropriate type based on signature
    ; For now, assume simple calling convention
    
    ; This is a placeholder - actual implementation would:
    ; 1. Set up argument registers/stack based on calling convention
    ; 2. Call the function
    ; 3. Extract return value
    ; 4. Convert return value to VibeValue
    
    ; For bootstrap purposes, return 0
    ret i64 0
}

; Define FFI type mapping
; ffi_define_type: Define a mapping from Vibe type to FFI type
; Parameters:
;   vibe_type: Vibe type identifier
;   ffi_type: FFI type identifier
; Returns: 0 on success, -1 on error
define i32 @ffi_define_type(i32 %vibe_type, i32 %ffi_type) {
entry:
    ; In a full implementation, this would maintain a type mapping table
    ; For bootstrap, this is a placeholder
    ret i32 0
}

; Convert VibeValue to C integer
; ffi_value_to_int: Convert VibeValue to C integer
; Parameters:
;   value: VibeValue (must be integer type)
; Returns: C integer value
define i64 @ffi_value_to_int(i32 %type, i64 %data) {
entry:
    ; If type is VALUE_INTEGER, return data directly
    %is_int = icmp eq i32 %type, 0  ; VALUE_INTEGER
    br i1 %is_int, label %return_int, label %return_zero

return_int:
    ret i64 %data

return_zero:
    ret i64 0
}

; Convert C integer to VibeValue
; ffi_int_to_value: Convert C integer to VibeValue
; Parameters:
;   i: C integer value
; Returns: VibeValue (type and data packed)
define i64 @ffi_int_to_value(i64 %i) {
entry:
    ; Pack type and value
    ; For simplicity, return data directly (type will be set by caller)
    ret i64 %i
}

; Convert VibeValue to C string
; ffi_value_to_string: Convert VibeValue to C string pointer
; Parameters:
;   value: VibeValue (must be string type)
; Returns: C string pointer (null-terminated)
define i8* @ffi_value_to_string(i32 %type, i64 %data) {
entry:
    ; If type is VALUE_STRING, extract string pointer
    %is_string = icmp eq i32 %type, 2  ; VALUE_STRING
    br i1 %is_string, label %return_string, label %return_null

return_string:
    %str_ptr = inttoptr i64 %data to i8*
    ret i8* %str_ptr

return_null:
    ret i8* null
}

; Convert C string to VibeValue
; ffi_string_to_value: Convert C string to VibeValue data
; Parameters:
;   str: C string pointer
; Returns: VibeValue data (pointer as i64)
define i64 @ffi_string_to_value(i8* %str) {
entry:
    %str_int = ptrtoint i8* %str to i64
    ret i64 %str_int
}

; Platform-specific function declarations
; These call the actual system functions

; dlopen wrapper (macOS/Linux) - calls actual dlopen from libdl
; dlopen flags: RTLD_LAZY = 1, RTLD_NOW = 2
define %LibraryHandle* @ffi_dlopen(i8* %path) {
entry:
    %handle = call i8* @dlopen(i8* %path, i32 1)  ; RTLD_LAZY
    %handle_ptr = bitcast i8* %handle to %LibraryHandle*
    ret %LibraryHandle* %handle_ptr
}

; dlsym wrapper (macOS/Linux) - calls actual dlsym from libdl
define %FunctionPtr @ffi_dlsym(%LibraryHandle* %handle, i8* %symbol) {
entry:
    %handle_ptr = bitcast %LibraryHandle* %handle to i8*
    %func = call i8* @dlsym(i8* %handle_ptr, i8* %symbol)
    ret %FunctionPtr %func
}

; dlclose wrapper (macOS/Linux) - calls actual dlclose from libdl
define i32 @ffi_dlclose(%LibraryHandle* %handle) {
entry:
    %handle_ptr = bitcast %LibraryHandle* %handle to i8*
    %result = call i32 @dlclose(i8* %handle_ptr)
    ret i32 %result
}

; External declarations for POSIX dynamic library functions
declare i8* @dlopen(i8*, i32)
declare i8* @dlsym(i8*, i8*)
declare i32 @dlclose(i8*)

; Note: On Windows, these would call:
; LoadLibraryA, GetProcAddress, FreeLibrary

; Error handling
; ffi_get_error: Get last FFI error message
; Returns: Error message string, or null if no error
define i8* @ffi_get_error() {
entry:
    ; Platform-specific implementation
    ; On macOS/Linux: use dlerror
    %error = call i8* @dlerror()
    ret i8* %error
}

; External declaration for dlerror
declare i8* @dlerror()

; ============================================================================
; LLVM C API Wrappers via FFI
; ============================================================================
; These functions provide wrappers around LLVM C API functions.
; They will be used by the code generator to create bitcode programmatically.
;
; Note: Full implementation of all LLVM C API wrappers is a large task.
; This section provides the foundation and key wrappers. Additional wrappers
; can be added incrementally as needed.
; ============================================================================

; LLVM Context type (opaque pointer)
%LLVMContextRef = type i8*

; LLVM Module type (opaque pointer)
%LLVMModuleRef = type i8*

; LLVM Type type (opaque pointer)
%LLVMTypeRef = type i8*

; LLVM Value type (opaque pointer)
%LLVMValueRef = type i8*

; LLVM Basic Block type (opaque pointer)
%LLVMBasicBlockRef = type i8*

; LLVM Builder type (opaque pointer)
%LLVMBuilderRef = type i8*

; Load LLVM library and initialize function pointers
; llvm_ffi_init: Initialize LLVM FFI by loading LLVM libraries
; Returns: 0 on success, -1 on error
; Note: This function loads the LLVM library and resolves function symbols.
; In a full implementation, this would cache function pointers for all LLVM C API functions.
define i32 @llvm_ffi_init() {
entry:
    ; TODO: Load LLVM library (e.g., libLLVM.dylib on macOS, libLLVM-21.so on Linux)
    ; TODO: Resolve LLVM C API function symbols
    ; TODO: Store function pointers for later use
    ; For now, return success (assuming LLVM libraries are linked statically or via CMake)
    ret i32 0
}

; Create LLVM context
; llvm_create_context: Create a new LLVM context
; Returns: LLVMContextRef, or null on error
define %LLVMContextRef @llvm_create_context() {
entry:
    ; TODO: Call LLVMContextCreate() via FFI
    ; For now, return null as placeholder
    ; In full implementation: call LLVMContextCreate() function pointer
    ret %LLVMContextRef null
}

; Dispose LLVM context
; llvm_dispose_context: Dispose an LLVM context
; Parameters:
;   context: LLVMContextRef to dispose
define void @llvm_dispose_context(%LLVMContextRef %context) {
entry:
    ; TODO: Call LLVMContextDispose() via FFI
    ; In full implementation: call LLVMContextDispose() function pointer
    ret void
}

; Create LLVM module
; llvm_create_module: Create a new LLVM module
; Parameters:
;   context: LLVMContextRef
;   module_id: Module identifier (null-terminated string)
; Returns: LLVMModuleRef, or null on error
define %LLVMModuleRef @llvm_create_module(%LLVMContextRef %context, i8* %module_id) {
entry:
    ; TODO: Call LLVMModuleCreateWithNameInContext() via FFI
    ; For now, return null as placeholder
    ret %LLVMModuleRef null
}

; Dispose LLVM module
; llvm_dispose_module: Dispose an LLVM module
; Parameters:
;   module: LLVMModuleRef to dispose
define void @llvm_dispose_module(%LLVMModuleRef %module) {
entry:
    ; TODO: Call LLVMDisposeModule() via FFI
    ret void
}

; Set target triple for module
; llvm_set_target: Set the target triple for a module
; Parameters:
;   module: LLVMModuleRef
;   triple: Target triple string (null-terminated)
define void @llvm_set_target(%LLVMModuleRef %module, i8* %triple) {
entry:
    ; TODO: Call LLVMSetTarget() via FFI
    ret void
}

; Create function type
; llvm_create_function_type: Create a function type
; Parameters:
;   return_type: LLVMTypeRef for return type
;   param_types: Array of LLVMTypeRef for parameters
;   param_count: Number of parameters
;   is_vararg: 1 if varargs, 0 otherwise
; Returns: LLVMTypeRef for function type, or null on error
define %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type, %LLVMTypeRef* %param_types, i32 %param_count, i32 %is_vararg) {
entry:
    ; TODO: Call LLVMFunctionType() via FFI
    ret %LLVMTypeRef null
}

; Create constant string
; llvm_create_constant_string: Create a constant string value
; Parameters:
;   context: LLVMContextRef
;   str: String data
;   len: String length
;   dont_null_terminate: 1 to not add null terminator, 0 to add it
; Returns: LLVMValueRef for constant string, or null on error
define %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef %context, i8* %str, i32 %len, i32 %dont_null_terminate) {
entry:
    ; TODO: Call LLVMConstStringInContext() via FFI
    ret %LLVMValueRef null
}

; Add function to module
; llvm_add_function: Add a function to a module
; Parameters:
;   module: LLVMModuleRef
;   name: Function name (null-terminated string)
;   function_type: LLVMTypeRef for function type
; Returns: LLVMValueRef for function, or null on error
define %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %name, %LLVMTypeRef %function_type) {
entry:
    ; TODO: Call LLVMAddFunction() via FFI
    ret %LLVMValueRef null
}

; Write bitcode to file
; llvm_write_bitcode_to_file: Write module bitcode to file
; Parameters:
;   module: LLVMModuleRef
;   path: Output file path (null-terminated string)
; Returns: 0 on success, non-zero on error
define i32 @llvm_write_bitcode_to_file(%LLVMModuleRef %module, i8* %path) {
entry:
    ; TODO: Call LLVMWriteBitcodeToFile() via FFI
    ; For now, return error as placeholder
    ret i32 -1
}

; Note: Additional LLVM C API wrappers should be added here as needed:
; - Type creation functions (Int8Type, Int32Type, VoidType, PointerType, ArrayType, StructType)
; - Builder functions (CreateBuilder, PositionBuilderAtEnd, BuildRet, BuildCall, BuildGEP)
; - Basic block functions (AppendBasicBlock)
; - Parameter functions (GetParam, SetValueName)
; - And other LLVM C API functions as required
