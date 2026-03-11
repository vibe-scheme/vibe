; Bootstrap LLVM DSL for Vibe - LLVM C API wrappers and target initialization
; Provides the llvm_* function layer used by the code generator
; All LLVM C API functions are statically linked via CMake
; This is the bootstrap (.ll) equivalent of kernel/dsl.vibe

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

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
declare %LLVMTypeRef @LLVMInt1TypeInContext(%LLVMContextRef)
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

; New arithmetic/conversion instructions for codegen migration
declare %LLVMValueRef @LLVMBuildURem(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildUDiv(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @LLVMBuildPtrToInt(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)

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

; ============================================================================
; String constants for target triple comparison
; ============================================================================
@.str.arm64 = private unnamed_addr constant [6 x i8] c"arm64\00"
@.str.aarch64 = private unnamed_addr constant [8 x i8] c"aarch64\00"

; ============================================================================
; Target initialization functions
; ============================================================================

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

; ============================================================================
; LLVM C API wrapper functions
; These provide a stable interface used by codegen.ll
; ============================================================================

; Context management
define %LLVMContextRef @llvm_create_context() {
entry:
    %context = call %LLVMContextRef @LLVMContextCreate()
    ret %LLVMContextRef %context
}

define void @llvm_dispose_context(%LLVMContextRef %context) {
entry:
    call void @LLVMContextDispose(%LLVMContextRef %context)
    ret void
}

; Module management
; Note: parameter order swap - wrapper takes (context, name), LLVM API takes (name, context)
define %LLVMModuleRef @llvm_create_module(%LLVMContextRef %context, i8* %module_id) {
entry:
    %module = call %LLVMModuleRef @LLVMModuleCreateWithNameInContext(i8* %module_id, %LLVMContextRef %context)
    ret %LLVMModuleRef %module
}

define void @llvm_dispose_module(%LLVMModuleRef %module) {
entry:
    call void @LLVMDisposeModule(%LLVMModuleRef %module)
    ret void
}

define void @llvm_set_target(%LLVMModuleRef %module, i8* %triple) {
entry:
    call void @LLVMSetTarget(%LLVMModuleRef %module, i8* %triple)
    ret void
}

define void @llvm_set_data_layout(%LLVMModuleRef %module, i8* %data_layout) {
entry:
    call void @LLVMSetDataLayout(%LLVMModuleRef %module, i8* %data_layout)
    ret void
}

; Type creation
define %LLVMTypeRef @llvm_get_int1_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt1TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

define %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt8TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

define %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt32TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

define %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMInt64TypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

define %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef %context) {
entry:
    %type = call %LLVMTypeRef @LLVMVoidTypeInContext(%LLVMContextRef %context)
    ret %LLVMTypeRef %type
}

define %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %element_type, i32 %address_space) {
entry:
    %ptr_type = call %LLVMTypeRef @LLVMPointerType(%LLVMTypeRef %element_type, i32 %address_space)
    ret %LLVMTypeRef %ptr_type
}

define %LLVMTypeRef @llvm_type_of(%LLVMValueRef %value) {
entry:
    %type = call %LLVMTypeRef @LLVMTypeOf(%LLVMValueRef %value)
    ret %LLVMTypeRef %type
}

define %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %ptr_type) {
entry:
    %element_type = call %LLVMTypeRef @LLVMGetElementType(%LLVMTypeRef %ptr_type)
    ret %LLVMTypeRef %element_type
}

define %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %element_type, i32 %element_count) {
entry:
    %array_type = call %LLVMTypeRef @LLVMArrayType(%LLVMTypeRef %element_type, i32 %element_count)
    ret %LLVMTypeRef %array_type
}

define %LLVMTypeRef @llvm_get_struct_type(%LLVMContextRef %context, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed) {
entry:
    %struct_type = call %LLVMTypeRef @LLVMStructTypeInContext(%LLVMContextRef %context, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed)
    ret %LLVMTypeRef %struct_type
}

define %LLVMTypeRef @llvm_create_named_struct_type(%LLVMContextRef %context, i8* %name) {
entry:
    %struct_type = call %LLVMTypeRef @LLVMStructCreateNamed(%LLVMContextRef %context, i8* %name)
    ret %LLVMTypeRef %struct_type
}

define void @llvm_set_struct_body(%LLVMTypeRef %struct_type, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed) {
entry:
    call void @LLVMStructSetBody(%LLVMTypeRef %struct_type, %LLVMTypeRef* %field_types, i32 %field_count, i32 %packed)
    ret void
}

define %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type, %LLVMTypeRef* %param_types, i32 %param_count, i32 %is_vararg) {
entry:
    %func_type = call %LLVMTypeRef @LLVMFunctionType(%LLVMTypeRef %return_type, %LLVMTypeRef* %param_types, i32 %param_count, i32 %is_vararg)
    ret %LLVMTypeRef %func_type
}

; Constant creation
define %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef %context, i8* %str, i32 %len, i32 %dont_null_terminate) {
entry:
    %const_str = call %LLVMValueRef @LLVMConstStringInContext(%LLVMContextRef %context, i8* %str, i32 %len, i32 %dont_null_terminate)
    ret %LLVMValueRef %const_str
}

define %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %type, i64 %value, i32 %sign_extend) {
entry:
    %const_int = call %LLVMValueRef @LLVMConstInt(%LLVMTypeRef %type, i64 %value, i32 %sign_extend)
    ret %LLVMValueRef %const_int
}

define %LLVMValueRef @llvm_create_constant_null(%LLVMTypeRef %type) {
entry:
    %null_const = call %LLVMValueRef @LLVMConstNull(%LLVMTypeRef %type)
    ret %LLVMValueRef %null_const
}

; Function management
define %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %name, %LLVMTypeRef %function_type) {
entry:
    %func = call %LLVMValueRef @LLVMAddFunction(%LLVMModuleRef %module, i8* %name, %LLVMTypeRef %function_type)
    ret %LLVMValueRef %func
}

define i32 @llvm_count_params(%LLVMValueRef %func) {
entry:
    %count = call i32 @LLVMCountParams(%LLVMValueRef %func)
    ret i32 %count
}

define %LLVMValueRef @llvm_get_param(%LLVMValueRef %func, i32 %index) {
entry:
    %param = call %LLVMValueRef @LLVMGetParam(%LLVMValueRef %func, i32 %index)
    ret %LLVMValueRef %param
}

define void @llvm_set_value_name(%LLVMValueRef %value, i8* %name) {
entry:
    call void @LLVMSetValueName(%LLVMValueRef %value, i8* %name)
    ret void
}

; Basic block management
define %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %func, i8* %name) {
entry:
    %bb = call %LLVMBasicBlockRef @LLVMAppendBasicBlock(%LLVMValueRef %func, i8* %name)
    ret %LLVMBasicBlockRef %bb
}

define %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef %context) {
entry:
    %builder = call %LLVMBuilderRef @LLVMCreateBuilderInContext(%LLVMContextRef %context)
    ret %LLVMBuilderRef %builder
}

define void @llvm_dispose_builder(%LLVMBuilderRef %builder) {
entry:
    call void @LLVMDisposeBuilder(%LLVMBuilderRef %builder)
    ret void
}

define void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %bb) {
entry:
    call void @LLVMPositionBuilderAtEnd(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %bb)
    ret void
}

define %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder) {
entry:
    %block = call %LLVMBasicBlockRef @LLVMGetInsertBlock(%LLVMBuilderRef %builder)
    ret %LLVMBasicBlockRef %block
}

define %LLVMBasicBlockRef @llvm_get_first_basic_block(%LLVMValueRef %func) {
entry:
    %block = call %LLVMBasicBlockRef @LLVMGetFirstBasicBlock(%LLVMValueRef %func)
    ret %LLVMBasicBlockRef %block
}

define %LLVMBasicBlockRef @llvm_get_next_basic_block(%LLVMBasicBlockRef %block) {
entry:
    %next = call %LLVMBasicBlockRef @LLVMGetNextBasicBlock(%LLVMBasicBlockRef %block)
    ret %LLVMBasicBlockRef %next
}

define i8* @llvm_get_basic_block_name(%LLVMBasicBlockRef %block) {
entry:
    %name = call i8* @LLVMGetBasicBlockName(%LLVMBasicBlockRef %block)
    ret i8* %name
}

define %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef %block) {
entry:
    %term = call %LLVMValueRef @LLVMGetBasicBlockTerminator(%LLVMBasicBlockRef %block)
    ret %LLVMValueRef %term
}

; Instruction building
define %LLVMValueRef @llvm_build_ret_void(%LLVMBuilderRef %builder) {
entry:
    %inst = call %LLVMValueRef @LLVMBuildRetVoid(%LLVMBuilderRef %builder)
    ret %LLVMValueRef %inst
}

define %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef %builder, %LLVMValueRef %value) {
entry:
    %inst = call %LLVMValueRef @LLVMBuildRet(%LLVMBuilderRef %builder, %LLVMValueRef %value)
    ret %LLVMValueRef %inst
}

define %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args, i32 %arg_count, i8* %name) {
entry:
    %call = call %LLVMValueRef @LLVMBuildCall2(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args, i32 %arg_count, i8* %name)
    ret %LLVMValueRef %call
}

define %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, %LLVMValueRef* %indices, i32 %index_count, i8* %name) {
entry:
    %gep = call %LLVMValueRef @LLVMBuildGEP2(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, %LLVMValueRef* %indices, i32 %index_count, i8* %name)
    ret %LLVMValueRef %gep
}

define %LLVMValueRef @llvm_build_bitcast(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name) {
entry:
    %bitcast = call %LLVMValueRef @LLVMBuildBitCast(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name)
    ret %LLVMValueRef %bitcast
}

define void @llvm_build_store(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMValueRef %pointer) {
entry:
    call void @LLVMBuildStore(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMValueRef %pointer)
    ret void
}

define %LLVMValueRef @llvm_build_load(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, i8* %name) {
entry:
    %load = call %LLVMValueRef @LLVMBuildLoad2(%LLVMBuilderRef %builder, %LLVMTypeRef %type, %LLVMValueRef %pointer, i8* %name)
    ret %LLVMValueRef %load
}

define %LLVMValueRef @llvm_build_icmp(%LLVMBuilderRef %builder, i32 %pred, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %icmp = call %LLVMValueRef @LLVMBuildICmp(%LLVMBuilderRef %builder, i32 %pred, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %icmp
}

define %LLVMValueRef @llvm_build_br(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %dest) {
entry:
    %br = call %LLVMValueRef @LLVMBuildBr(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %dest)
    ret %LLVMValueRef %br
}

define %LLVMValueRef @llvm_build_cond_br(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMBasicBlockRef %then_block, %LLVMBasicBlockRef %else_block) {
entry:
    %cond_br = call %LLVMValueRef @LLVMBuildCondBr(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMBasicBlockRef %then_block, %LLVMBasicBlockRef %else_block)
    ret %LLVMValueRef %cond_br
}

define %LLVMValueRef @llvm_build_zext(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name) {
entry:
    %zext = call %LLVMValueRef @LLVMBuildZExt(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name)
    ret %LLVMValueRef %zext
}

define %LLVMValueRef @llvm_build_add(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %add = call %LLVMValueRef @LLVMBuildAdd(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %add
}

define %LLVMValueRef @llvm_build_or(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %or_val = call %LLVMValueRef @LLVMBuildOr(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %or_val
}

define %LLVMValueRef @llvm_build_sub(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %sub = call %LLVMValueRef @LLVMBuildSub(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %sub
}

define %LLVMValueRef @llvm_build_mul(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %mul = call %LLVMValueRef @LLVMBuildMul(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %mul
}

define %LLVMValueRef @llvm_build_and(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %and_val = call %LLVMValueRef @LLVMBuildAnd(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %and_val
}

define %LLVMValueRef @llvm_build_alloca(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name) {
entry:
    %alloca = call %LLVMValueRef @LLVMBuildAlloca(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name)
    ret %LLVMValueRef %alloca
}

define %LLVMValueRef @llvm_build_trunc(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name) {
entry:
    %trunc = call %LLVMValueRef @LLVMBuildTrunc(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name)
    ret %LLVMValueRef %trunc
}

define %LLVMValueRef @llvm_build_select(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMValueRef %then_val, %LLVMValueRef %else_val, i8* %name) {
entry:
    %sel = call %LLVMValueRef @LLVMBuildSelect(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMValueRef %then_val, %LLVMValueRef %else_val, i8* %name)
    ret %LLVMValueRef %sel
}

define %LLVMValueRef @llvm_build_phi(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name) {
entry:
    %phi = call %LLVMValueRef @LLVMBuildPhi(%LLVMBuilderRef %builder, %LLVMTypeRef %ty, i8* %name)
    ret %LLVMValueRef %phi
}

define void @llvm_add_incoming(%LLVMValueRef %phi, %LLVMValueRef* %values, %LLVMBasicBlockRef* %blocks, i32 %count) {
entry:
    call void @LLVMAddIncoming(%LLVMValueRef %phi, %LLVMValueRef* %values, %LLVMBasicBlockRef* %blocks, i32 %count)
    ret void
}

define %LLVMValueRef @llvm_get_undef(%LLVMTypeRef %type) {
entry:
    %undef_val = call %LLVMValueRef @LLVMGetUndef(%LLVMTypeRef %type)
    ret %LLVMValueRef %undef_val
}

define %LLVMValueRef @llvm_build_insert_value(%LLVMBuilderRef %builder, %LLVMValueRef %agg, %LLVMValueRef %val, i32 %index, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildInsertValue(%LLVMBuilderRef %builder, %LLVMValueRef %agg, %LLVMValueRef %val, i32 %index, i8* %name)
    ret %LLVMValueRef %result
}

define %LLVMValueRef @llvm_build_extract_value(%LLVMBuilderRef %builder, %LLVMValueRef %agg, i32 %index, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildExtractValue(%LLVMBuilderRef %builder, %LLVMValueRef %agg, i32 %index, i8* %name)
    ret %LLVMValueRef %result
}

; New arithmetic/conversion wrappers for codegen migration
; llvm_build_urem: Build an unsigned remainder instruction
define %LLVMValueRef @llvm_build_urem(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildURem(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %result
}

; llvm_build_udiv: Build an unsigned division instruction
define %LLVMValueRef @llvm_build_udiv(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildUDiv(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %name)
    ret %LLVMValueRef %result
}

; llvm_build_ptrtoint: Build a pointer-to-integer conversion instruction
define %LLVMValueRef @llvm_build_ptrtoint(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %dest_type, i8* %name) {
entry:
    %result = call %LLVMValueRef @LLVMBuildPtrToInt(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %dest_type, i8* %name)
    ret %LLVMValueRef %result
}

; Global variable management
define %LLVMValueRef @llvm_add_global(%LLVMModuleRef %module, %LLVMTypeRef %type, i8* %name) {
entry:
    %global = call %LLVMValueRef @LLVMAddGlobal(%LLVMModuleRef %module, %LLVMTypeRef %type, i8* %name)
    ret %LLVMValueRef %global
}

define void @llvm_set_initializer(%LLVMValueRef %global, %LLVMValueRef %initializer) {
entry:
    call void @LLVMSetInitializer(%LLVMValueRef %global, %LLVMValueRef %initializer)
    ret void
}

define void @llvm_set_global_constant(%LLVMValueRef %global, i32 %is_constant) {
entry:
    call void @LLVMSetGlobalConstant(%LLVMValueRef %global, i32 %is_constant)
    ret void
}

define void @llvm_set_linkage(%LLVMValueRef %global, i32 %linkage) {
entry:
    call void @LLVMSetLinkage(%LLVMValueRef %global, i32 %linkage)
    ret void
}

; IR parsing
; llvm_parse_ir_in_context: Parse IR text into a module
; Creates a memory buffer from the IR text, then parses it
; Returns 0 on success, non-zero on error
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
    ; NOTE: Disposing the buffer immediately after parsing causes a segfault
    ; For now, we skip disposal to avoid crashes - this causes a small memory leak
    ; TODO: Investigate if buffer can be safely disposed after module is fully linked/used
    ; call void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef %buffer)
    ret i32 0
    
error_no_dispose:
    ; On error, don't dispose buffer - it may be corrupted
    ret i32 -1
    
success:
    ret i32 0
    
error:
    ret i32 -1
}

; Bitcode writing
define i32 @llvm_write_bitcode_to_file(%LLVMModuleRef %module, i8* %path) {
entry:
    %result = call i32 @LLVMWriteBitcodeToFile(%LLVMModuleRef %module, i8* %path)
    ret i32 %result
}

; Target triple and machine
define i8* @llvm_get_default_target_triple() {
entry:
    %triple = call i8* @LLVMGetDefaultTargetTriple()
    ret i8* %triple
}

define i32 @llvm_get_target_from_triple(i8* %triple, %LLVMTargetRef* %target, i8** %error_msg) {
entry:
    %result = call i32 @LLVMGetTargetFromTriple(i8* %triple, %LLVMTargetRef* %target, i8** %error_msg)
    ret i32 %result
}

define %LLVMTargetMachineRef @llvm_create_target_machine(%LLVMTargetRef %target, i8* %triple, i8* %cpu, i8* %features, i32 %level, i32 %reloc, i32 %code_model) {
entry:
    %tm = call %LLVMTargetMachineRef @LLVMCreateTargetMachine(%LLVMTargetRef %target, i8* %triple, i8* %cpu, i8* %features, i32 %level, i32 %reloc, i32 %code_model)
    ret %LLVMTargetMachineRef %tm
}

define i32 @llvm_target_machine_emit_to_file(%LLVMTargetMachineRef %tm, %LLVMModuleRef %module, i8* %filename, i32 %codegen, i8** %error_msg) {
entry:
    %result = call i32 @LLVMTargetMachineEmitToFile(%LLVMTargetMachineRef %tm, %LLVMModuleRef %module, i8* %filename, i32 %codegen, i8** %error_msg)
    ret i32 %result
}

define void @llvm_dispose_target_machine(%LLVMTargetMachineRef %tm) {
entry:
    call void @LLVMDisposeTargetMachine(%LLVMTargetMachineRef %tm)
    ret void
}

; Function and global lookup
define %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %name) {
entry:
    %func = call %LLVMValueRef @LLVMGetNamedFunction(%LLVMModuleRef %module, i8* %name)
    ret %LLVMValueRef %func
}

; Note: Function cloning APIs (LLVMCloneFunctionInto, LLVMValueIsAFunction) are not available
; in LLVM 21 C API. We use module linking instead, which automatically resolves symbols.

define %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef %module, i8* %name) {
entry:
    %global = call %LLVMValueRef @LLVMGetNamedGlobal(%LLVMModuleRef %module, i8* %name)
    ret %LLVMValueRef %global
}

; Module linking
define i32 @llvm_link_modules2(%LLVMModuleRef %dest, %LLVMModuleRef %src) {
entry:
    %result = call i32 @LLVMLinkModules2(%LLVMModuleRef %dest, %LLVMModuleRef %src)
    ret i32 %result
}

; Module verification
define i32 @llvm_verify_module(%LLVMModuleRef %module, i32 %action, i8** %error_msg) {
entry:
    %result = call i32 @LLVMVerifyModule(%LLVMModuleRef %module, i32 %action, i8** %error_msg)
    ret i32 %result
}

; Module printing
define i32 @llvm_print_module_to_file(%LLVMModuleRef %module, i8* %filename, i8** %error_msg) {
entry:
    %result = call i32 @LLVMPrintModuleToFile(%LLVMModuleRef %module, i8* %filename, i8** %error_msg)
    ret i32 %result
}
