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
; LLVM C API Wrappers
; ============================================================================
; These functions provide wrappers around LLVM C API functions.
; They will be used by the code generator to create bitcode programmatically.
;
; Since LLVM is statically linked, we can declare LLVM C API functions as
; external and call them directly without dynamic loading.
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

; LLVM Memory Buffer type (opaque pointer)
%LLVMMemoryBufferRef = type i8*

; LLVM Target type (opaque pointer)
%LLVMTargetRef = type i8*

; LLVM TargetMachine type (opaque pointer)
%LLVMTargetMachineRef = type i8*

; External declarations for LLVM C API functions
; Context management
declare %LLVMContextRef @LLVMContextCreate()
declare void @LLVMContextDispose(%LLVMContextRef)

; Module management
declare %LLVMModuleRef @LLVMModuleCreateWithNameInContext(i8*, %LLVMContextRef)
declare void @LLVMDisposeModule(%LLVMModuleRef)
declare void @LLVMSetTarget(%LLVMModuleRef, i8*)
declare void @LLVMSetDataLayout(%LLVMModuleRef, i8*)

; Type creation
declare %LLVMTypeRef @LLVMInt8TypeInContext(%LLVMContextRef)
declare %LLVMTypeRef @LLVMInt32TypeInContext(%LLVMContextRef)
declare %LLVMTypeRef @LLVMInt64TypeInContext(%LLVMContextRef)
declare %LLVMTypeRef @LLVMVoidTypeInContext(%LLVMContextRef)
declare %LLVMTypeRef @LLVMPointerType(%LLVMTypeRef, i32)
declare %LLVMTypeRef @LLVMArrayType(%LLVMTypeRef, i32)
declare %LLVMTypeRef @LLVMStructTypeInContext(%LLVMContextRef, %LLVMTypeRef*, i32, i32)
declare %LLVMTypeRef @LLVMFunctionType(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)

; Constant creation
declare %LLVMValueRef @LLVMConstStringInContext(%LLVMContextRef, i8*, i32, i32)
declare %LLVMValueRef @LLVMConstInt(%LLVMTypeRef, i64, i32)
declare %LLVMValueRef @LLVMConstNull(%LLVMTypeRef)

; Function management
declare %LLVMValueRef @LLVMAddFunction(%LLVMModuleRef, i8*, %LLVMTypeRef)
declare %LLVMValueRef @LLVMGetParam(%LLVMValueRef, i32)
declare void @LLVMSetValueName(%LLVMValueRef, i8*)

; Basic block management
declare %LLVMBasicBlockRef @LLVMAppendBasicBlock(%LLVMValueRef, i8*)

; Builder management
declare %LLVMBuilderRef @LLVMCreateBuilderInContext(%LLVMContextRef)
declare void @LLVMDisposeBuilder(%LLVMBuilderRef)
declare void @LLVMPositionBuilderAtEnd(%LLVMBuilderRef, %LLVMBasicBlockRef)

; Instruction building
declare %LLVMValueRef @LLVMBuildRetVoid(%LLVMBuilderRef)
declare %LLVMValueRef @LLVMBuildRet(%LLVMBuilderRef, %LLVMValueRef)
declare %LLVMValueRef @LLVMBuildCall2(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @LLVMBuildGEP2(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)

; Global variable management
declare %LLVMValueRef @LLVMAddGlobal(%LLVMModuleRef, %LLVMTypeRef, i8*)
declare void @LLVMSetInitializer(%LLVMValueRef, %LLVMValueRef)
declare void @LLVMSetGlobalConstant(%LLVMValueRef, i32)
declare void @LLVMSetLinkage(%LLVMValueRef, i32)

; IR parsing
declare i32 @LLVMParseIRInContext(%LLVMContextRef, %LLVMMemoryBufferRef, %LLVMModuleRef*, i8**)
declare %LLVMMemoryBufferRef @LLVMCreateMemoryBufferWithMemoryRangeCopy(i8*, i64, i8*)
declare void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef)

; Bitcode writing
declare i32 @LLVMWriteBitcodeToFile(%LLVMModuleRef, i8*)

; TargetMachine API
; Native target initialization functions (must be called before using TargetMachine API)
; These are X86-specific initialization functions (for x86_64 target)
declare void @LLVMInitializeX86TargetInfo()
declare void @LLVMInitializeX86Target()
declare void @LLVMInitializeX86TargetMC()
declare void @LLVMInitializeX86AsmPrinter()
declare void @LLVMInitializeX86AsmParser()

declare i8* @LLVMGetDefaultTargetTriple()
declare i32 @LLVMGetTargetFromTriple(i8*, %LLVMTargetRef*, i8**)
declare %LLVMTargetMachineRef @LLVMCreateTargetMachine(%LLVMTargetRef, i8*, i8*, i8*, i32, i32, i32)
declare i32 @LLVMTargetMachineEmitToFile(%LLVMTargetMachineRef, %LLVMModuleRef, i8*, i32, i8**)
declare void @LLVMDisposeTargetMachine(%LLVMTargetMachineRef)

; Function lookup
declare %LLVMValueRef @LLVMGetNamedFunction(%LLVMModuleRef, i8*)

; Global variable lookup
declare %LLVMValueRef @LLVMGetNamedGlobal(%LLVMModuleRef, i8*)

; Initialize native target
; llvm_initialize_native_target: Initialize native target for TargetMachine API
; This must be called before using TargetMachine functions
; For x86_64 target, this initializes X86 target components
define void @llvm_initialize_native_target() {
entry:
    ; Initialize X86 target components
    call void @LLVMInitializeX86TargetInfo()
    call void @LLVMInitializeX86Target()
    call void @LLVMInitializeX86TargetMC()
    call void @LLVMInitializeX86AsmPrinter()
    call void @LLVMInitializeX86AsmParser()
    ret void
}

; Load LLVM library and initialize function pointers
; llvm_ffi_init: Initialize LLVM FFI and native target
; Returns: 0 on success, -1 on error
; Note: Since LLVM is statically linked, we call initialization functions directly.
define i32 @llvm_ffi_init() {
entry:
    ; Initialize native target (required for TargetMachine API)
    call void @llvm_initialize_native_target()
    ret i32 0
}

; Create LLVM context
; llvm_create_context: Create a new LLVM context
; Returns: LLVMContextRef, or null on error
define %LLVMContextRef @llvm_create_context() {
entry:
    %context = call %LLVMContextRef @LLVMContextCreate()
    ret %LLVMContextRef %context
}

; Dispose LLVM context
; llvm_dispose_context: Dispose an LLVM context
; Parameters:
;   context: LLVMContextRef to dispose
define void @llvm_dispose_context(%LLVMContextRef %context) {
entry:
    call void @LLVMContextDispose(%LLVMContextRef %context)
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
    %module = call %LLVMModuleRef @LLVMModuleCreateWithNameInContext(i8* %module_id, %LLVMContextRef %context)
    ret %LLVMModuleRef %module
}

; Dispose LLVM module
; llvm_dispose_module: Dispose an LLVM module
; Parameters:
;   module: LLVMModuleRef to dispose
define void @llvm_dispose_module(%LLVMModuleRef %module) {
entry:
    call void @LLVMDisposeModule(%LLVMModuleRef %module)
    ret void
}

; Set target triple for module
; llvm_set_target: Set the target triple for a module
; Parameters:
;   module: LLVMModuleRef
;   triple: Target triple string (null-terminated)
define void @llvm_set_target(%LLVMModuleRef %module, i8* %triple) {
entry:
    call void @LLVMSetTarget(%LLVMModuleRef %module, i8* %triple)
    ret void
}

; Set data layout for module
; llvm_set_data_layout: Set the data layout for a module
; Parameters:
;   module: LLVMModuleRef
;   data_layout: Data layout string (null-terminated)
define void @llvm_set_data_layout(%LLVMModuleRef %module, i8* %data_layout) {
entry:
    call void @LLVMSetDataLayout(%LLVMModuleRef %module, i8* %data_layout)
    ret void
}

; Get i8 type
; llvm_get_int8_type: Get i8 type from context
; Parameters:
;   context: LLVMContextRef
; Returns: LLVMTypeRef for i8 type
define %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt8TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

; Get i32 type
; llvm_get_int32_type: Get i32 type from context
; Parameters:
;   context: LLVMContextRef
; Returns: LLVMTypeRef for i32 type
define %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt32TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

; Get i64 type
; llvm_get_int64_type: Get i64 type from context
; Parameters:
;   context: LLVMContextRef
; Returns: LLVMTypeRef for i64 type
define %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt64TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

; Get void type
; llvm_get_void_type: Get void type from context
; Parameters:
;   context: LLVMContextRef
; Returns: LLVMTypeRef for void type
define %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMVoidTypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

; Create pointer type
; llvm_get_pointer_type: Create a pointer type
; Parameters:
;   element_type: LLVMTypeRef for element type
;   address_space: Address space (0 for default)
; Returns: LLVMTypeRef for pointer type
define %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %element_type, i32 %address_space) {
entry:
    %ptr_type = call %LLVMTypeRef @LLVMPointerType(%LLVMTypeRef %element_type, i32 %address_space)
    ret %LLVMTypeRef %ptr_type
}

; Create array type
; llvm_get_array_type: Create an array type
; Parameters:
;   element_type: LLVMTypeRef for element type
;   element_count: Number of elements
; Returns: LLVMTypeRef for array type
define %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %element_type, i32 %element_count) {
entry:
    %array_type = call %LLVMTypeRef @LLVMArrayType(%LLVMTypeRef %element_type, i32 %element_count)
    ret %LLVMTypeRef %array_type
}

; Create struct type
; llvm_get_struct_type: Create a struct type from field types
; Parameters:
;   context: LLVMContextRef
;   field_types: Array of LLVMTypeRef for field types
;   field_count: Number of fields
;   packed: 1 if packed, 0 otherwise
; Returns: LLVMTypeRef for struct type, or null on error
define %LLVMTypeRef @llvm_get_struct_type(%LLVMContextRef %context, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed) {
entry:
    %struct_type = call %LLVMTypeRef @LLVMStructTypeInContext(%LLVMContextRef %context, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed)
    ret %LLVMTypeRef %struct_type
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
    %func_type = call %LLVMTypeRef @LLVMFunctionType(%LLVMTypeRef %return_type, %LLVMTypeRef* %param_types, i32 %param_count, i32 %is_vararg)
    ret %LLVMTypeRef %func_type
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
    %const_str = call %LLVMValueRef @LLVMConstStringInContext(%LLVMContextRef %context, i8* %str, i32 %len, i32 %dont_null_terminate)
    ret %LLVMValueRef %const_str
}

; Create constant integer
; llvm_create_constant_int: Create a constant integer value
; Parameters:
;   type: LLVMTypeRef for integer type
;   value: Integer value
;   sign_extend: 1 if sign-extended, 0 otherwise
; Returns: LLVMValueRef for constant integer
define %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %type, i64 %value, i32 %sign_extend) {
entry:
    %const_int = call %LLVMValueRef @LLVMConstInt(%LLVMTypeRef %type, i64 %value, i32 %sign_extend)
    ret %LLVMValueRef %const_int
}

; Create null constant
; llvm_create_constant_null: Create a null constant
; Parameters:
;   type: LLVMTypeRef for type
; Returns: LLVMValueRef for null constant
define %LLVMValueRef @llvm_create_constant_null(%LLVMTypeRef %type) {
entry:
    %null_const = call %LLVMValueRef @LLVMConstNull(%LLVMTypeRef %type)
    ret %LLVMValueRef %null_const
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
    %func = call %LLVMValueRef @LLVMAddFunction(%LLVMModuleRef %module, i8* %name, %LLVMTypeRef %function_type)
    ret %LLVMValueRef %func
}

; Get function parameter
; llvm_get_param: Get a function parameter by index
; Parameters:
;   func: LLVMValueRef for function
;   index: Parameter index (0-based)
; Returns: LLVMValueRef for parameter
define %LLVMValueRef @llvm_get_param(%LLVMValueRef %func, i32 %index) {
entry:
    %param = call %LLVMValueRef @LLVMGetParam(%LLVMValueRef %func, i32 %index)
    ret %LLVMValueRef %param
}

; Set value name
; llvm_set_value_name: Set the name of a value
; Parameters:
;   value: LLVMValueRef
;   name: Name string (null-terminated)
define void @llvm_set_value_name(%LLVMValueRef %value, i8* %name) {
entry:
    call void @LLVMSetValueName(%LLVMValueRef %value, i8* %name)
    ret void
}

; Append basic block
; llvm_append_basic_block: Append a basic block to a function
; Parameters:
;   func: LLVMValueRef for function
;   name: Block name (null-terminated string, can be null)
; Returns: LLVMBasicBlockRef for basic block
define %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %func, i8* %name) {
entry:
    %bb = call %LLVMBasicBlockRef @LLVMAppendBasicBlock(%LLVMValueRef %func, i8* %name)
    ret %LLVMBasicBlockRef %bb
}

; Create builder
; llvm_create_builder: Create an IR builder
; Parameters:
;   context: LLVMContextRef
; Returns: LLVMBuilderRef
define %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef %context) {
entry:
    %builder = call %LLVMBuilderRef @LLVMCreateBuilderInContext(%LLVMContextRef %context)
    ret %LLVMBuilderRef %builder
}

; Dispose builder
; llvm_dispose_builder: Dispose an IR builder
; Parameters:
;   builder: LLVMBuilderRef to dispose
define void @llvm_dispose_builder(%LLVMBuilderRef %builder) {
entry:
    call void @LLVMDisposeBuilder(%LLVMBuilderRef %builder)
    ret void
}

; Position builder at end of basic block
; llvm_position_builder_at_end: Position builder at end of basic block
; Parameters:
;   builder: LLVMBuilderRef
;   bb: LLVMBasicBlockRef
define void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %bb) {
entry:
    call void @LLVMPositionBuilderAtEnd(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %bb)
    ret void
}

; Build return void
; llvm_build_ret_void: Build a return void instruction
; Parameters:
;   builder: LLVMBuilderRef
; Returns: LLVMValueRef for instruction
define %LLVMValueRef @llvm_build_ret_void(%LLVMBuilderRef %builder) {
entry:
    %inst = call %LLVMValueRef @LLVMBuildRetVoid(%LLVMBuilderRef %builder)
    ret %LLVMValueRef %inst
}

; Build return
; llvm_build_ret: Build a return instruction with value
; Parameters:
;   builder: LLVMBuilderRef
;   value: LLVMValueRef to return
; Returns: LLVMValueRef for instruction
define %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef %builder, %LLVMValueRef %value) {
entry:
    %inst = call %LLVMValueRef @LLVMBuildRet(%LLVMBuilderRef %builder, %LLVMValueRef %value)
    ret %LLVMValueRef %inst
}

; Build function call
; llvm_build_call: Build a function call instruction
; Parameters:
;   builder: LLVMBuilderRef
;   func_type: LLVMTypeRef for function type
;   func: LLVMValueRef for function to call
;   args: Array of LLVMValueRef for arguments
;   arg_count: Number of arguments
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for call instruction
define %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args, i32 %arg_count, i8* %name) {
entry:
    %call = call %LLVMValueRef @LLVMBuildCall2(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args, i32 %arg_count, i8* %name)
    ret %LLVMValueRef %call
}

; Build getelementptr
; llvm_build_gep: Build a getelementptr instruction
; Parameters:
;   builder: LLVMBuilderRef
;   type: LLVMTypeRef for source type
;   pointer: LLVMValueRef for pointer
;   indices: Array of LLVMValueRef for indices
;   index_count: Number of indices
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for gep instruction
define %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, %LLVMValueRef* %indices, i32 %index_count, i8* %name) {
entry:
    %gep = call %LLVMValueRef @LLVMBuildGEP2(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, %LLVMValueRef* %indices, i32 %index_count, i8* %name)
    ret %LLVMValueRef %gep
}

; Add global variable
; llvm_add_global: Add a global variable to module
; Parameters:
;   module: LLVMModuleRef
;   type: LLVMTypeRef for variable type
;   name: Variable name (null-terminated string)
; Returns: LLVMValueRef for global variable
define %LLVMValueRef @llvm_add_global(%LLVMModuleRef %module, %LLVMTypeRef %type, i8* %name) {
entry:
    %global = call %LLVMValueRef @LLVMAddGlobal(%LLVMModuleRef %module, %LLVMTypeRef %type, i8* %name)
    ret %LLVMValueRef %global
}

; Set global initializer
; llvm_set_initializer: Set the initializer for a global variable
; Parameters:
;   global: LLVMValueRef for global variable
;   initializer: LLVMValueRef for initializer value
define void @llvm_set_initializer(%LLVMValueRef %global, %LLVMValueRef %initializer) {
entry:
    call void @LLVMSetInitializer(%LLVMValueRef %global, %LLVMValueRef %initializer)
    ret void
}

; Set global constant
; llvm_set_global_constant: Set whether a global is constant
; Parameters:
;   global: LLVMValueRef for global variable
;   is_constant: 1 if constant, 0 otherwise
define void @llvm_set_global_constant(%LLVMValueRef %global, i32 %is_constant) {
entry:
    call void @LLVMSetGlobalConstant(%LLVMValueRef %global, i32 %is_constant)
    ret void
}

; Set linkage
; llvm_set_linkage: Set linkage type for a global
; Parameters:
;   global: LLVMValueRef for global
;   linkage: Linkage type (LLVMLinkage enum value)
define void @llvm_set_linkage(%LLVMValueRef %global, i32 %linkage) {
entry:
    call void @LLVMSetLinkage(%LLVMValueRef %global, i32 %linkage)
    ret void
}

; Parse IR in context
; llvm_parse_ir_in_context: Parse IR text into a module
; Parameters:
;   context: LLVMContextRef
;   ir_text: IR text string
;   ir_len: Length of IR text
;   module: Pointer to LLVMModuleRef (output parameter)
; Returns: 0 on success, non-zero on error
define i32 @llvm_parse_ir_in_context(%LLVMContextRef %context, i8* %ir_text, i64 %ir_len, %LLVMModuleRef* %module) {
entry:
    ; Create memory buffer from IR text
    %buffer = call %LLVMMemoryBufferRef @LLVMCreateMemoryBufferWithMemoryRangeCopy(i8* %ir_text, i64 %ir_len, i8* null)
    %buffer_null = icmp eq %LLVMMemoryBufferRef %buffer, null
    br i1 %buffer_null, label %error, label %parse
    
parse:
    ; Parse IR from buffer
    %error_msg = alloca i8*
    store i8* null, i8** %error_msg
    %parse_result = call i32 @LLVMParseIRInContext(%LLVMContextRef %context, %LLVMMemoryBufferRef %buffer, %LLVMModuleRef* %module, i8** %error_msg)
    
    ; Check parse result before disposing buffer
    %parse_failed = icmp ne i32 %parse_result, 0
    br i1 %parse_failed, label %dispose_and_error, label %dispose_and_success
    
dispose_and_success:
    ; Dispose buffer only if parsing succeeded
    ; Note: LLVMParseIRInContext does NOT take ownership, we must dispose
    ; Double-check buffer is not null before disposing
    %buffer_check = icmp ne %LLVMMemoryBufferRef %buffer, null
    br i1 %buffer_check, label %dispose_success, label %success
    
dispose_success:
    call void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef %buffer)
    br label %success
    
dispose_and_error:
    ; Dispose buffer even on error, but check it's not null
    %buffer_check_err = icmp ne %LLVMMemoryBufferRef %buffer, null
    br i1 %buffer_check_err, label %dispose_error, label %error
    
dispose_error:
    call void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef %buffer)
    br label %error
    
success:
    ret i32 0
    
error:
    ret i32 -1
}

; Write bitcode to file
; llvm_write_bitcode_to_file: Write module bitcode to file
; Parameters:
;   module: LLVMModuleRef
;   path: Output file path (null-terminated string)
; Returns: 0 on success, non-zero on error
define i32 @llvm_write_bitcode_to_file(%LLVMModuleRef %module, i8* %path) {
entry:
    %result = call i32 @LLVMWriteBitcodeToFile(%LLVMModuleRef %module, i8* %path)
    ret i32 %result
}

; Get default target triple
; llvm_get_default_target_triple: Get default target triple string
; Returns: Target triple string (caller must free with free())
define i8* @llvm_get_default_target_triple() {
entry:
    %triple = call i8* @LLVMGetDefaultTargetTriple()
    ret i8* %triple
}

; Get target from triple
; llvm_get_target_from_triple: Get target from triple string
; Parameters:
;   triple: Target triple string (null-terminated)
;   target: Pointer to LLVMTargetRef (output parameter)
; Returns: 0 on success, non-zero on error (error message in error_msg if provided)
define i32 @llvm_get_target_from_triple(i8* %triple, %LLVMTargetRef* %target, i8** %error_msg) {
entry:
    %result = call i32 @LLVMGetTargetFromTriple(i8* %triple, %LLVMTargetRef* %target, i8** %error_msg)
    ret i32 %result
}

; Create target machine
; llvm_create_target_machine: Create a target machine
; Parameters:
;   target: LLVMTargetRef
;   triple: Target triple string (null-terminated)
;   cpu: CPU name (null-terminated, can be empty string)
;   features: Feature string (null-terminated, can be empty string)
;   level: Optimization level (0=CodeGenLevelNone, 1=CodeGenLevelLess, 2=CodeGenLevelDefault, 3=CodeGenLevelAggressive)
;   reloc: Relocation model (0=RelocDefault, 1=RelocStatic, 2=RelocPIC, 3=RelocDynamicNoPic)
;   code_model: Code model (0=CodeModelDefault, 1=CodeModelJITDefault, 2=CodeModelSmall, 3=CodeModelKernel, 4=CodeModelMedium, 5=CodeModelLarge)
; Returns: LLVMTargetMachineRef, or null on error
define %LLVMTargetMachineRef @llvm_create_target_machine(%LLVMTargetRef %target, i8* %triple, i8* %cpu, i8* %features, i32 %level, i32 %reloc, i32 %code_model) {
entry:
    %tm = call %LLVMTargetMachineRef @LLVMCreateTargetMachine(%LLVMTargetRef %target, i8* %triple, i8* %cpu, i8* %features, i32 %level, i32 %reloc, i32 %code_model)
    ret %LLVMTargetMachineRef %tm
}

; Emit module to file
; llvm_target_machine_emit_to_file: Emit module to file using target machine
; Parameters:
;   tm: LLVMTargetMachineRef
;   module: LLVMModuleRef
;   filename: Output file path (null-terminated string)
;   codegen: Code generation type (0=AssemblyFile, 1=ObjectFile, 2=...)
;   error_msg: Pointer to i8* for error message (output parameter, can be null)
; Returns: 0 on success, non-zero on error
define i32 @llvm_target_machine_emit_to_file(%LLVMTargetMachineRef %tm, %LLVMModuleRef %module, i8* %filename, i32 %codegen, i8** %error_msg) {
entry:
    %result = call i32 @LLVMTargetMachineEmitToFile(%LLVMTargetMachineRef %tm, %LLVMModuleRef %module, i8* %filename, i32 %codegen, i8** %error_msg)
    ret i32 %result
}

; Dispose target machine
; llvm_dispose_target_machine: Dispose a target machine
; Parameters:
;   tm: LLVMTargetMachineRef to dispose
define void @llvm_dispose_target_machine(%LLVMTargetMachineRef %tm) {
entry:
    call void @LLVMDisposeTargetMachine(%LLVMTargetMachineRef %tm)
    ret void
}

; Get named function
; llvm_get_named_function: Get a function by name from module
; Parameters:
;   module: LLVMModuleRef
;   name: Function name (null-terminated string)
; Returns: LLVMValueRef for function, or null if not found
define %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %name) {
entry:
    %func = call %LLVMValueRef @LLVMGetNamedFunction(%LLVMModuleRef %module, i8* %name)
    ret %LLVMValueRef %func
}

; Get named global
; llvm_get_named_global: Get a global variable by name from module
; Parameters:
;   module: LLVMModuleRef
;   name: Global name (null-terminated string)
; Returns: LLVMValueRef for global, or null if not found
define %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef %module, i8* %name) {
entry:
    %global = call %LLVMValueRef @LLVMGetNamedGlobal(%LLVMModuleRef %module, i8* %name)
    ret %LLVMValueRef %global
}
