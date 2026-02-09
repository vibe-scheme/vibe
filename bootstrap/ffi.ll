; Bootstrap FFI System for Vibe
; Foreign Function Interface for calling C libraries
; Platform abstraction layer for POSIX and Windows
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%LibraryHandle = type opaque
%FunctionPtr = type i8*

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

; External declarations for POSIX dynamic library functions
declare i8* @dlopen(i8*, i32)
declare i8* @dlsym(i8*, i8*)

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
declare %LLVMTypeRef @LLVMStructCreateNamed(%LLVMContextRef, i8*)
declare void @LLVMStructSetBody(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)
declare %LLVMTypeRef @LLVMFunctionType(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)

; Type introspection
declare %LLVMTypeRef @LLVMTypeOf(%LLVMValueRef)
declare %LLVMTypeRef @LLVMGetElementType(%LLVMTypeRef)

; Constant creation
declare %LLVMValueRef @LLVMConstStringInContext(%LLVMContextRef, i8*, i32, i32)
declare %LLVMValueRef @LLVMConstInt(%LLVMTypeRef, i64, i32)
declare %LLVMValueRef @LLVMConstNull(%LLVMTypeRef)

; Function management
declare %LLVMValueRef @LLVMAddFunction(%LLVMModuleRef, i8*, %LLVMTypeRef)
declare i32 @LLVMCountParams(%LLVMValueRef)
declare %LLVMValueRef @LLVMGetParam(%LLVMValueRef, i32)
declare void @LLVMSetValueName(%LLVMValueRef, i8*)

; Basic block management
declare %LLVMBasicBlockRef @LLVMAppendBasicBlock(%LLVMValueRef, i8*)
declare %LLVMBasicBlockRef @LLVMGetFirstBasicBlock(%LLVMValueRef)
declare %LLVMBasicBlockRef @LLVMGetNextBasicBlock(%LLVMBasicBlockRef)
declare i8* @LLVMGetBasicBlockName(%LLVMBasicBlockRef)
declare %LLVMValueRef @LLVMGetBasicBlockTerminator(%LLVMBasicBlockRef)

; Builder management
declare %LLVMBuilderRef @LLVMCreateBuilderInContext(%LLVMContextRef)
declare void @LLVMDisposeBuilder(%LLVMBuilderRef)
declare void @LLVMPositionBuilderAtEnd(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMBasicBlockRef @LLVMGetInsertBlock(%LLVMBuilderRef)

; Instruction building
declare %LLVMValueRef @LLVMBuildRetVoid(%LLVMBuilderRef)
declare %LLVMValueRef @LLVMBuildRet(%LLVMBuilderRef, %LLVMValueRef)
declare %LLVMValueRef @LLVMBuildCall2(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @LLVMBuildGEP2(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @LLVMBuildBitCast(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare void @LLVMBuildStore(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef)
declare %LLVMValueRef @LLVMBuildLoad2(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildICmp(%LLVMBuilderRef, i32, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildBr(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @LLVMBuildCondBr(%LLVMBuilderRef, %LLVMValueRef, %LLVMBasicBlockRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @LLVMBuildZExt(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @LLVMBuildAdd(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildSub(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildMul(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildAnd(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildOr(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildAlloca(%LLVMBuilderRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @LLVMBuildTrunc(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @LLVMBuildSelect(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildPhi(%LLVMBuilderRef, %LLVMTypeRef, i8*)
declare void @LLVMAddIncoming(%LLVMValueRef, %LLVMValueRef*, %LLVMBasicBlockRef*, i32)
declare %LLVMValueRef @LLVMGetUndef(%LLVMTypeRef)
declare %LLVMValueRef @LLVMBuildInsertValue(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i32, i8*)
declare %LLVMValueRef @LLVMBuildExtractValue(%LLVMBuilderRef, %LLVMValueRef, i32, i8*)

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

; Module verification and debugging
declare i32 @LLVMVerifyModule(%LLVMModuleRef, i32, i8**)
declare i32 @LLVMPrintModuleToFile(%LLVMModuleRef, i8*, i8**)

; Standard library functions for debugging
declare i32 @printf(i8*, ...)
declare i32 @fprintf(%struct.__sFILE*, i8*, ...)
%struct.__sFILE = type opaque

; Standard library memory management
declare void @free(i8*)

; String comparison function (from C standard library)
declare i32 @strncmp(i8*, i8*, i64)

; TargetMachine API
; Native target initialization functions (must be called before using TargetMachine API)
; Note: We only declare functions for the architecture we're building for.
; The target triple at the top of this file determines which functions are available.
; For arm64 builds, only AArch64 functions are declared.
; For x86_64 builds, only X86 functions are declared.

; AArch64 target initialization functions (for arm64 target)
declare void @LLVMInitializeAArch64TargetInfo()
declare void @LLVMInitializeAArch64Target()
declare void @LLVMInitializeAArch64TargetMC()
declare void @LLVMInitializeAArch64AsmPrinter()
declare void @LLVMInitializeAArch64AsmParser()

; X86-specific initialization functions (for x86_64 target)
; These are only available when building for x86_64, so we use a runtime check
; to avoid calling them on arm64. However, the linker will still try to resolve
; them if they're declared. We'll handle this by making the calls conditional
; and ensuring the linker doesn't require these symbols on arm64.
; For now, we'll comment them out and use a different approach.
; declare void @LLVMInitializeX86TargetInfo()
; declare void @LLVMInitializeX86Target()
; declare void @LLVMInitializeX86TargetMC()
; declare void @LLVMInitializeX86AsmPrinter()
; declare void @LLVMInitializeX86AsmParser()

declare i8* @LLVMGetDefaultTargetTriple()
declare i32 @LLVMGetTargetFromTriple(i8*, %LLVMTargetRef*, i8**)
declare %LLVMTargetMachineRef @LLVMCreateTargetMachine(%LLVMTargetRef, i8*, i8*, i8*, i32, i32, i32)
declare i32 @LLVMTargetMachineEmitToFile(%LLVMTargetMachineRef, %LLVMModuleRef, i8*, i32, i8**)
declare void @LLVMDisposeTargetMachine(%LLVMTargetMachineRef)

; Function lookup
declare %LLVMValueRef @LLVMGetNamedFunction(%LLVMModuleRef, i8*)

; Function iteration
declare %LLVMValueRef @LLVMGetFirstFunction(%LLVMModuleRef)
declare %LLVMValueRef @LLVMGetNextFunction(%LLVMValueRef)

; Note: LLVMCloneFunctionInto and LLVMValueIsAFunction are not available in LLVM 21 C API
; We'll use module linking instead, which handles symbol resolution automatically

; Global variable lookup
declare %LLVMValueRef @LLVMGetNamedGlobal(%LLVMModuleRef, i8*)

; Module linking
declare i32 @LLVMLinkModules2(%LLVMModuleRef, %LLVMModuleRef)

; String constants for target triple comparison
@.str.arm64 = private unnamed_addr constant [6 x i8] c"arm64\00"
@.str.aarch64 = private unnamed_addr constant [8 x i8] c"aarch64\00"

; Check if target triple is ARM64/AArch64
; is_arm64_target: Check if target triple indicates ARM64 architecture
; Parameters:
;   triple: Target triple string (null-terminated)
; Returns: 1 if ARM64, 0 otherwise
define i32 @is_arm64_target(i8* %triple) {
entry:
    ; Check if triple starts with "arm64"
    %arm64_str = getelementptr [6 x i8], [6 x i8]* @.str.arm64, i32 0, i32 0
    %arm64_cmp = call i32 @strncmp(i8* %triple, i8* %arm64_str, i64 5)
    %is_arm64 = icmp eq i32 %arm64_cmp, 0
    br i1 %is_arm64, label %return_arm64, label %check_aarch64

check_aarch64:
    ; Check if triple starts with "aarch64"
    %aarch64_str = getelementptr [8 x i8], [8 x i8]* @.str.aarch64, i32 0, i32 0
    %aarch64_cmp = call i32 @strncmp(i8* %triple, i8* %aarch64_str, i64 7)
    %is_aarch64 = icmp eq i32 %aarch64_cmp, 0
    br i1 %is_aarch64, label %return_arm64, label %return_x86

return_arm64:
    ret i32 1

return_x86:
    ret i32 0
}

; Initialize native target
; llvm_initialize_native_target: Initialize native target for TargetMachine API
; This must be called before using TargetMachine functions
; Automatically detects the target architecture and initializes the appropriate components
; Note: Since this file is built for arm64, we only initialize AArch64 components.
; For x86_64 builds, a separate version of this function would initialize X86 components.
define void @llvm_initialize_native_target() {
entry:
    ; Get default target triple
    %triple = call i8* @LLVMGetDefaultTargetTriple()
    
    ; Check if target is ARM64
    %is_arm64 = call i32 @is_arm64_target(i8* %triple)
    %is_arm64_bool = icmp ne i32 %is_arm64, 0
    br i1 %is_arm64_bool, label %init_arm64, label %error_unsupported

init_arm64:
    ; Initialize AArch64 target components
    call void @LLVMInitializeAArch64TargetInfo()
    call void @LLVMInitializeAArch64Target()
    call void @LLVMInitializeAArch64TargetMC()
    call void @LLVMInitializeAArch64AsmPrinter()
    call void @LLVMInitializeAArch64AsmParser()
    br label %done

error_unsupported:
    ; If we're not on ARM64, this build doesn't support the target architecture
    ; This should not happen if the file is built for the correct architecture
    ; For now, we'll just skip initialization (this is a build configuration error)
    br label %done

done:
    ; Free the target triple string returned by LLVMGetDefaultTargetTriple()
    call void @free(i8* %triple)
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

; Get type of a value
; llvm_type_of: Get the type of an LLVM value
; Parameters:
;   value: LLVMValueRef
; Returns: LLVMTypeRef for the value's type
define %LLVMTypeRef @llvm_type_of(%LLVMValueRef %value) {
entry:
    %type = call %LLVMTypeRef @LLVMTypeOf(%LLVMValueRef %value)
    ret %LLVMTypeRef %type
}

; Get element type of a pointer type
; llvm_get_element_type: Get the element type of a pointer type
; Parameters:
;   ptr_type: LLVMTypeRef for pointer type
; Returns: LLVMTypeRef for element type
define %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %ptr_type) {
entry:
    %element_type = call %LLVMTypeRef @LLVMGetElementType(%LLVMTypeRef %ptr_type)
    ret %LLVMTypeRef %element_type
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

; llvm_create_named_struct_type: Create a named struct type (opaque initially)
; Parameters:
;   context: LLVMContextRef
;   name: Type name (null-terminated string)
; Returns: LLVMTypeRef for struct type, or null on error
define %LLVMTypeRef @llvm_create_named_struct_type(%LLVMContextRef %context, i8* %name) {
entry:
    %struct_type = call %LLVMTypeRef @LLVMStructCreateNamed(%LLVMContextRef %context, i8* %name)
    ret %LLVMTypeRef %struct_type
}

; llvm_set_struct_body: Set the body of a struct type
; Parameters:
;   struct_type: LLVMTypeRef for the struct type
;   field_types: Array of LLVMTypeRef for field types
;   field_count: Number of fields
;   packed: 1 if packed, 0 otherwise
define void @llvm_set_struct_body(%LLVMTypeRef %struct_type, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed) {
entry:
    call void @LLVMStructSetBody(%LLVMTypeRef %struct_type, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed)
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

; Count function parameters
; llvm_count_params: Count the number of parameters in a function
; Parameters:
;   func: LLVMValueRef for function
; Returns: Number of parameters (i32)
define i32 @llvm_count_params(%LLVMValueRef %func) {
entry:
    %count = call i32 @LLVMCountParams(%LLVMValueRef %func)
    ret i32 %count
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

; Get current insert block from builder
; llvm_get_insert_block: Get the basic block that the builder is currently positioned at
; Parameters:
;   builder: LLVMBuilderRef
; Returns: LLVMBasicBlockRef for current insert block, or null if builder is not positioned
define %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder) {
entry:
    %block = call %LLVMBasicBlockRef @LLVMGetInsertBlock(%LLVMBuilderRef %builder)
    ret %LLVMBasicBlockRef %block
}

; Get first basic block in function
; llvm_get_first_basic_block: Get the first basic block in a function
; Parameters:
;   func: LLVMValueRef for function
; Returns: LLVMBasicBlockRef for first basic block, or null if function has no blocks
define %LLVMBasicBlockRef @llvm_get_first_basic_block(%LLVMValueRef %func) {
entry:
    %block = call %LLVMBasicBlockRef @LLVMGetFirstBasicBlock(%LLVMValueRef %func)
    ret %LLVMBasicBlockRef %block
}

; Get next basic block
; llvm_get_next_basic_block: Get the next basic block after the given one
; Parameters:
;   block: LLVMBasicBlockRef
; Returns: LLVMBasicBlockRef for next basic block, or null if this is the last block
define %LLVMBasicBlockRef @llvm_get_next_basic_block(%LLVMBasicBlockRef %block) {
entry:
    %next = call %LLVMBasicBlockRef @LLVMGetNextBasicBlock(%LLVMBasicBlockRef %block)
    ret %LLVMBasicBlockRef %next
}

; Get basic block name
; llvm_get_basic_block_name: Get the name of a basic block
; Parameters:
;   block: LLVMBasicBlockRef
; Returns: i8* pointer to null-terminated name string, or null if block has no name
define i8* @llvm_get_basic_block_name(%LLVMBasicBlockRef %block) {
entry:
    %name = call i8* @LLVMGetBasicBlockName(%LLVMBasicBlockRef %block)
    ret i8* %name
}

; llvm_get_basic_block_terminator: Get the terminator instruction of a basic block
; Parameters:
;   block: LLVMBasicBlockRef
; Returns: LLVMValueRef for terminator instruction, or null if block has no terminator
define %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef %block) {
entry:
    %term = call %LLVMValueRef @LLVMGetBasicBlockTerminator(%LLVMBasicBlockRef %block)
    ret %LLVMValueRef %term
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

; llvm_build_bitcast: Build a bitcast instruction
; Parameters:
;   builder: LLVMBuilderRef
;   value: LLVMValueRef to cast
;   target_type: LLVMTypeRef for target type
;   name: Name for the instruction
; Returns: LLVMValueRef for bitcast instruction
define %LLVMValueRef @llvm_build_bitcast(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name) {
entry:
    %bitcast = call %LLVMValueRef @LLVMBuildBitCast(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name)
    ret %LLVMValueRef %bitcast
}

; llvm_build_store: Build a store instruction
; Parameters:
;   builder: LLVMBuilderRef
;   value: LLVMValueRef to store
;   pointer: LLVMValueRef for the pointer to store to
; Returns: void (store instruction has no return value)
define void @llvm_build_store(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMValueRef %pointer) {
entry:
    call void @LLVMBuildStore(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMValueRef %pointer)
    ret void
}

; llvm_build_load: Build a load instruction
; Parameters:
;   builder: LLVMBuilderRef
;   type: LLVMTypeRef for the type being loaded
;   pointer: LLVMValueRef for the pointer to load from
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for load instruction
define %LLVMValueRef @llvm_build_load(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, i8* %name) {
entry:
    %load = call %LLVMValueRef @LLVMBuildLoad2(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, i8* %name)
    ret %LLVMValueRef %load
}

; llvm_build_icmp: Build an integer comparison instruction
; Parameters:
;   builder: LLVMBuilderRef
;   pred: LLVMIntPredicate enum value (i32)
;   lhs: LLVMValueRef for left-hand side
;   rhs: LLVMValueRef for right-hand side
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef (i1 boolean) for comparison result
define %LLVMValueRef @llvm_build_icmp(%LLVMBuilderRef %builder, i32 %pred, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %icmp = call %LLVMValueRef @LLVMBuildICmp(%LLVMBuilderRef %builder, i32 %pred, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %icmp
}

; llvm_build_br: Build an unconditional branch instruction
; Parameters:
;   builder: LLVMBuilderRef
;   dest: LLVMBasicBlockRef for destination block
; Returns: LLVMValueRef for branch instruction
define %LLVMValueRef @llvm_build_br(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %dest) {
entry:
    %br = call %LLVMValueRef @LLVMBuildBr(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %dest)
    ret %LLVMValueRef %br
}

; llvm_build_cond_br: Build a conditional branch instruction
; Parameters:
;   builder: LLVMBuilderRef
;   cond: LLVMValueRef (i1 boolean) for condition
;   then_block: LLVMBasicBlockRef for then branch
;   else_block: LLVMBasicBlockRef for else branch
; Returns: LLVMValueRef for branch instruction
define %LLVMValueRef @llvm_build_cond_br(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMBasicBlockRef %then_block, %LLVMBasicBlockRef %else_block) {
entry:
    %cond_br = call %LLVMValueRef @LLVMBuildCondBr(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMBasicBlockRef %then_block, %LLVMBasicBlockRef %else_block)
    ret %LLVMValueRef %cond_br
}

; llvm_build_zext: Build a zero extension instruction
; Parameters:
;   builder: LLVMBuilderRef
;   value: LLVMValueRef to extend
;   target_type: LLVMTypeRef for target type
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for extended value
define %LLVMValueRef @llvm_build_zext(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name) {
entry:
    %zext = call %LLVMValueRef @LLVMBuildZExt(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name)
    ret %LLVMValueRef %zext
}

; llvm_build_add: Build an addition instruction
; Parameters:
;   builder: LLVMBuilderRef
;   lhs: LLVMValueRef for left-hand side
;   rhs: LLVMValueRef for right-hand side
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for sum
define %LLVMValueRef @llvm_build_add(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %add = call %LLVMValueRef @LLVMBuildAdd(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %add
}

; llvm_build_or: Build a bitwise OR instruction
; Parameters:
;   builder: LLVMBuilderRef
;   lhs: LLVMValueRef for left-hand side
;   rhs: LLVMValueRef for right-hand side
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for result
define %LLVMValueRef @llvm_build_or(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %or = call %LLVMValueRef @LLVMBuildOr(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %or
}

; llvm_build_sub: Build a subtraction instruction
; Parameters:
;   builder: LLVMBuilderRef
;   lhs: LLVMValueRef for left-hand side
;   rhs: LLVMValueRef for right-hand side
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for difference
define %LLVMValueRef @llvm_build_sub(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %sub = call %LLVMValueRef @LLVMBuildSub(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %sub
}

; llvm_build_mul: Build a multiplication instruction
; Parameters:
;   builder: LLVMBuilderRef
;   lhs: LLVMValueRef for left-hand side
;   rhs: LLVMValueRef for right-hand side
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for product
define %LLVMValueRef @llvm_build_mul(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %mul = call %LLVMValueRef @LLVMBuildMul(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %mul
}

; llvm_build_and: Build a bitwise AND instruction
; Parameters:
;   builder: LLVMBuilderRef
;   lhs: LLVMValueRef for left-hand side
;   rhs: LLVMValueRef for right-hand side
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for result
define %LLVMValueRef @llvm_build_and(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %and = call %LLVMValueRef @LLVMBuildAnd(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %and
}

; llvm_build_alloca: Build a stack allocation instruction
; Parameters:
;   builder: LLVMBuilderRef
;   ty: LLVMTypeRef for type to allocate
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for allocated pointer
define %LLVMValueRef @llvm_build_alloca(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name) {
entry:
    %alloca = call %LLVMValueRef @LLVMBuildAlloca(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name)
    ret %LLVMValueRef %alloca
}

; llvm_build_trunc: Build an integer truncation instruction
; Parameters:
;   builder: LLVMBuilderRef
;   value: LLVMValueRef to truncate
;   target_type: LLVMTypeRef for target type
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for truncated value
define %LLVMValueRef @llvm_build_trunc(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name) {
entry:
    %trunc = call %LLVMValueRef @LLVMBuildTrunc(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name)
    ret %LLVMValueRef %trunc
}

; llvm_build_select: Build a select instruction
; Parameters:
;   builder: LLVMBuilderRef
;   cond: LLVMValueRef for condition (i1)
;   then_val: LLVMValueRef for true value
;   else_val: LLVMValueRef for false value
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for selected value
define %LLVMValueRef @llvm_build_select(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMValueRef %then_val, %LLVMValueRef %else_val, i8* %name) {
entry:
    %sel = call %LLVMValueRef @LLVMBuildSelect(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMValueRef %then_val, %LLVMValueRef %else_val, i8* %name)
    ret %LLVMValueRef %sel
}

; llvm_build_phi: Build a phi node instruction
; Parameters:
;   builder: LLVMBuilderRef
;   ty: LLVMTypeRef for the phi node type
;   name: Name for instruction (null-terminated, can be null)
; Returns: LLVMValueRef for phi node (use llvm_add_incoming to add values)
define %LLVMValueRef @llvm_build_phi(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name) {
entry:
    %phi = call %LLVMValueRef @LLVMBuildPhi(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name)
    ret %LLVMValueRef %phi
}

; llvm_add_incoming: Add incoming values to a phi node
; Parameters:
;   phi: LLVMValueRef for phi node
;   values: Array of LLVMValueRef incoming values
;   blocks: Array of LLVMBasicBlockRef incoming blocks
;   count: Number of incoming values
define void @llvm_add_incoming(%LLVMValueRef %phi, %LLVMValueRef* %values, %LLVMBasicBlockRef* %blocks, i32 %count) {
entry:
    call void @LLVMAddIncoming(%LLVMValueRef %phi, %LLVMValueRef* %values, %LLVMBasicBlockRef* %blocks, i32 %count)
    ret void
}

; Get undef value
; llvm_get_undef: Get an undef value of the given type
; Parameters:
;   type: LLVMTypeRef for the desired type
; Returns: LLVMValueRef for undef value
define %LLVMValueRef @llvm_get_undef(%LLVMTypeRef %type) {
entry:
    %undef_val = call %LLVMValueRef @LLVMGetUndef(%LLVMTypeRef %type)
    ret %LLVMValueRef %undef_val
}

; Insert value into aggregate
; llvm_build_insert_value: Insert a value into an aggregate (struct/array) at given index
; Parameters:
;   builder: LLVMBuilderRef
;   agg: LLVMValueRef for aggregate value
;   val: LLVMValueRef for element value to insert
;   index: Index within the aggregate
;   name: Name for instruction (null-terminated, can be empty)
; Returns: LLVMValueRef for new aggregate with value inserted
define %LLVMValueRef @llvm_build_insert_value(%LLVMBuilderRef %builder, %LLVMValueRef %agg, %LLVMValueRef %val, i32 %index, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildInsertValue(%LLVMBuilderRef %builder, %LLVMValueRef %agg, %LLVMValueRef %val, i32 %index, i8* %name)
    ret %LLVMValueRef %result
}

; Extract value from aggregate
; llvm_build_extract_value: Extract a value from an aggregate (struct/array) at given index
; Parameters:
;   builder: LLVMBuilderRef
;   agg: LLVMValueRef for aggregate value
;   index: Index within the aggregate
;   name: Name for instruction (null-terminated, can be empty)
; Returns: LLVMValueRef for extracted element
define %LLVMValueRef @llvm_build_extract_value(%LLVMBuilderRef %builder, %LLVMValueRef %agg, i32 %index, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildExtractValue(%LLVMBuilderRef %builder, %LLVMValueRef %agg, i32 %index, i8* %name)
    ret %LLVMValueRef %result
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
; NOTE: LLVMParseIRInContext can parse IR with undeclared symbols. The function
; structure will be created, and references to undeclared symbols will remain
; unresolved until the module is linked to the main module where those symbols
; are already defined.
define i32 @llvm_parse_ir_in_context(%LLVMContextRef %context, i8* %ir_text, i64 %ir_len, %LLVMModuleRef* %module) {
entry:
    ; Create memory buffer from IR text
    %buffer = call %LLVMMemoryBufferRef @LLVMCreateMemoryBufferWithMemoryRangeCopy(i8* %ir_text, i64 %ir_len, i8* null)
    %buffer_null = icmp eq %LLVMMemoryBufferRef %buffer, null
    br i1 %buffer_null, label %error, label %parse
    
parse:
    ; Parse IR from buffer (handles undeclared symbols gracefully)
    %error_msg = alloca i8*
    store i8* null, i8** %error_msg
    %parse_result = call i32 @LLVMParseIRInContext(%LLVMContextRef %context, %LLVMMemoryBufferRef %buffer, %LLVMModuleRef* %module, i8** %error_msg)
    
    ; Check parse result
    %parse_failed = icmp ne i32 %parse_result, 0
    br i1 %parse_failed, label %error_no_dispose, label %success_dispose
    
success_dispose:
    ; Dispose buffer on success (LLVMParseIRInContext does NOT take ownership)
    ; NOTE: Disposing the buffer immediately after parsing causes a segfault
    ; The buffer appears to be used internally by LLVM even after parsing completes
    ; For now, we skip disposal to avoid crashes - this causes a small memory leak
    ; TODO: Investigate if buffer can be safely disposed after module is fully linked/used
    ; call void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef %buffer)
    ret i32 0
    
error_no_dispose:
    ; On error, don't dispose buffer - it may be corrupted
    ; This causes a memory leak, but prevents crash
    ; TODO: Investigate why buffer gets corrupted on parse error
    ; Note: error_msg contains the error message, but we can't easily print it from LLVM IR
    ; The caller should check the return value and handle errors appropriately
    ret i32 -1
    
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
; Note: LLVMWriteBitcodeToFile produces bitcode that llvm-link/llvm-dis reject
; for multi-function modules. We work around this by writing IR text and using
; llvm-as to convert it, which produces bitcode in the correct format.
define i32 @llvm_write_bitcode_to_file(%LLVMModuleRef %module, i8* %path) {
entry:
    ; For now, use LLVMWriteBitcodeToFile directly
    ; TODO: Implement workaround that writes IR text and calls llvm-as
    ; This requires system call support which is complex from LLVM IR
    ; The build system could handle this conversion as a post-processing step
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

; Note: Function cloning APIs (LLVMCloneFunctionInto, LLVMValueIsAFunction) are not available
; in LLVM 21 C API. We use module linking instead, which automatically resolves symbols.

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

; Link modules
; llvm_link_modules2: Link source module into destination module
; Parameters:
;   dest: Destination module (main module)
;   src: Source module (temp module with parsed function)
; Returns: 0 on success, non-zero on error
; Note: In LLVM 21, LLVMLinkModules2 automatically moves contents from src to dest
; The source module becomes empty but should still be disposed
define i32 @llvm_link_modules2(%LLVMModuleRef %dest, %LLVMModuleRef %src) {
entry:
    %result = call i32 @LLVMLinkModules2(%LLVMModuleRef %dest, %LLVMModuleRef %src)
    ret i32 %result
}

; Module verification
; llvm_verify_module: Verify a module for correctness
; Parameters:
;   module: Module to verify
;   action: Verification action (0 = abort on error, 1 = return message, 2 = print to stderr)
;   error_msg: Pointer to i8* for error message (output parameter)
; Returns: 0 if valid, non-zero if invalid
define i32 @llvm_verify_module(%LLVMModuleRef %module, i32 %action, i8** %error_msg) {
entry:
    %result = call i32 @LLVMVerifyModule(%LLVMModuleRef %module, i32 %action, i8** %error_msg)
    ret i32 %result
}

; Print module to file
; llvm_print_module_to_file: Print module IR to a file
; Parameters:
;   module: Module to print
;   filename: Output filename (null-terminated string)
;   error_msg: Pointer to i8* for error message (output parameter)
; Returns: 0 on success, non-zero on error
define i32 @llvm_print_module_to_file(%LLVMModuleRef %module, i8* %filename, i8** %error_msg) {
entry:
    %result = call i32 @LLVMPrintModuleToFile(%LLVMModuleRef %module, i8* %filename, i8** %error_msg)
    ret i32 %result
}

