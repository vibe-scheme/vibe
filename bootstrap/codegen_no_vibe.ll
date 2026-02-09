; Bootstrap Code Generator for Vibe
; Generates LLVM IR from AST nodes
; All functions use snake_case naming convention
;
; MIGRATION NOTE: This code generator currently uses text IR generation.
; Future work will integrate LLVM C API via FFI for direct bitcode generation.
; The migration strategy is:
; 1. Keep text IR generation working (current state) ✓
; 2. Add LLVM API calls alongside (parallel implementation) - TODO
; 3. Switch to LLVM API by default (new default) - TODO
; 4. Keep text IR as fallback (for debugging) - TODO

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }

; Forward declarations for LLVM types (from ffi.ll)
%LLVMContextRef = type i8*
%LLVMModuleRef = type i8*
%LLVMTypeRef = type i8*
%LLVMValueRef = type i8*
%LLVMBasicBlockRef = type i8*
%LLVMBuilderRef = type i8*
%LLVMTargetRef = type i8*
%LLVMTargetMachineRef = type i8*

; CodeGen structure - extended to include LLVM context/module handles and DSL evaluation
; Fields:
;   ir_buffer: Buffer for generated IR text (for backward compatibility during migration)
;   buffer_size: Current buffer size
;   buffer_pos: Current position in buffer
;   string_counter: Counter for unique string constant names
;   label_counter: Counter for unique label names
;   llvm_context: LLVM context handle
;   llvm_module: LLVM module handle
;   llvm_builder: LLVM builder handle (for generating instructions in main function)
;   current_function: LLVMValueRef for function currently being built (for DSL evaluation)
;   param_names: ASTNode* list of (name . param_value) pairs for parameter name mapping
;   local_values: ASTNode* list of (name . LLVMValueRef) pairs for local value binding
;   function_types: ASTNode* list of (name . LLVMTypeRef) pairs for function type mapping
;   constants: ASTNode* list of (name . LLVMValueRef) pairs for constant tracking
;   types: ASTNode* list of (name . LLVMTypeRef) pairs for type tracking
;   llvm_functions: ASTNode* list of (name . (func_value . func_type)) pairs for function tracking
%CodeGen = type { i8*, i64, i64, i32, i32, %LLVMContextRef, %LLVMModuleRef, %LLVMBuilderRef, %LLVMValueRef, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode* }

; Forward declarations for FFI types (from ffi.ll)
%LibraryHandle = type opaque
%FunctionPtr = type i8*

; Forward declarations for LLVM FFI functions (from ffi.ll)
declare i32 @llvm_ffi_init()
declare %LLVMContextRef @llvm_create_context()
declare void @llvm_dispose_context(%LLVMContextRef)
declare %LLVMModuleRef @llvm_create_module(%LLVMContextRef, i8*)
declare void @llvm_dispose_module(%LLVMModuleRef)
declare void @llvm_set_target(%LLVMModuleRef, i8*)
declare void @llvm_set_data_layout(%LLVMModuleRef, i8*)
declare %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef, i32)
declare %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef, i32)
declare %LLVMTypeRef @llvm_get_struct_type(%LLVMContextRef, %LLVMTypeRef*, i32, i32)
declare %LLVMTypeRef @llvm_create_named_struct_type(%LLVMContextRef, i8*)
declare void @llvm_set_struct_body(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)
declare %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)
declare %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef, i8*, i32, i32)
declare %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef, i64, i32)
declare %LLVMValueRef @llvm_create_constant_null(%LLVMTypeRef)
declare %LLVMValueRef @llvm_add_function(%LLVMModuleRef, i8*, %LLVMTypeRef)
declare i32 @llvm_count_params(%LLVMValueRef)
declare %LLVMValueRef @llvm_get_param(%LLVMValueRef, i32)
declare void @llvm_set_value_name(%LLVMValueRef, i8*)
declare %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef, i8*)
declare %LLVMBasicBlockRef @llvm_get_first_basic_block(%LLVMValueRef)
declare %LLVMBasicBlockRef @llvm_get_next_basic_block(%LLVMBasicBlockRef)
declare i8* @llvm_get_basic_block_name(%LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef)
declare %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef)
declare void @llvm_dispose_builder(%LLVMBuilderRef)
declare void @llvm_position_builder_at_end(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef)
declare %LLVMValueRef @llvm_build_ret_void(%LLVMBuilderRef)
declare %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef, %LLVMValueRef)
declare %LLVMValueRef @llvm_build_call(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @llvm_build_bitcast(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare void @llvm_build_store(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef)
declare %LLVMValueRef @llvm_build_load(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_icmp(%LLVMBuilderRef, i32, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_br(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_build_cond_br(%LLVMBuilderRef, %LLVMValueRef, %LLVMBasicBlockRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_build_zext(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_build_add(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_sub(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_mul(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_and(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_or(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_alloca(%LLVMBuilderRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_build_trunc(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_build_select(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_phi(%LLVMBuilderRef, %LLVMTypeRef, i8*)
declare void @llvm_add_incoming(%LLVMValueRef, %LLVMValueRef*, %LLVMBasicBlockRef*, i32)
declare %LLVMValueRef @llvm_get_undef(%LLVMTypeRef)
declare %LLVMValueRef @llvm_build_insert_value(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i32, i8*)
declare %LLVMValueRef @llvm_build_extract_value(%LLVMBuilderRef, %LLVMValueRef, i32, i8*)
declare %LLVMValueRef @llvm_build_urem(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_udiv(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_ptrtoint(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_add_global(%LLVMModuleRef, %LLVMTypeRef, i8*)
declare void @llvm_set_initializer(%LLVMValueRef, %LLVMValueRef)
declare void @llvm_set_global_constant(%LLVMValueRef, i32)
declare void @llvm_set_linkage(%LLVMValueRef, i32)
declare i32 @llvm_parse_ir_in_context(%LLVMContextRef, i8*, i64, %LLVMModuleRef*)
declare i32 @llvm_write_bitcode_to_file(%LLVMModuleRef, i8*)
declare i8* @llvm_get_default_target_triple()
declare i32 @llvm_get_target_from_triple(i8*, %LLVMTargetRef*, i8**)
declare %LLVMTargetMachineRef @llvm_create_target_machine(%LLVMTargetRef, i8*, i8*, i8*, i32, i32, i32)
declare i32 @llvm_target_machine_emit_to_file(%LLVMTargetMachineRef, %LLVMModuleRef, i8*, i32, i8**)
declare void @llvm_dispose_target_machine(%LLVMTargetMachineRef)
declare %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef, i8*)
declare %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef, i8*)
declare i32 @llvm_link_modules2(%LLVMModuleRef, %LLVMModuleRef)
declare i32 @llvm_verify_module(%LLVMModuleRef, i32, i8**)
declare i32 @llvm_print_module_to_file(%LLVMModuleRef, i8*, i8**)
declare %LLVMTypeRef @llvm_type_of(%LLVMValueRef)
declare %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef)
declare %LibraryHandle* @ffi_load_library(i8*)
declare %FunctionPtr @ffi_get_symbol(%LibraryHandle*, i8*)
declare i32 @open(i8*, i32, ...)
declare i64 @write(i32, i8*, i32)
declare i32 @close(i32)

; Initialize code generator
; codegen_init: Initialize code generator
; Returns: Pointer to CodeGen structure
define %CodeGen* @codegen_init(i8* %module_name) {
entry:
    ; Allocate CodeGen structure (now includes LLVM context/module/builder pointers + DSL fields + function types + tracking fields)
    %cg = call i8* @malloc(i64 112)  ; 8 + 8 + 8 + 4 + 4 + 8 + 8 + 8 + 8 + 8 + 8 + 8 + 8 + 8 + 8 = 112 bytes
    %cg_ptr = bitcast i8* %cg to %CodeGen*
    
    ; Initialize LLVM FFI
    %ffi_init_result = call i32 @llvm_ffi_init()
    
    ; Create LLVM context
    %llvm_context = call %LLVMContextRef @llvm_create_context()
    %context_null = icmp eq %LLVMContextRef %llvm_context, null
    br i1 %context_null, label %error, label %check_module_name

check_module_name:
    ; Check if module_name is null, use default if so
    %module_name_null = icmp eq i8* %module_name, null
    br i1 %module_name_null, label %use_default_name, label %use_provided_name

use_default_name:
    ; Use default module name "vibe"
    %default_name_array = bitcast [5 x i8]* @.str.module_name to i8*
    br label %create_module

use_provided_name:
    ; Use provided module name
    br label %create_module

create_module:
    ; Create LLVM module with appropriate name
    %module_name_to_use = phi i8* [ %default_name_array, %use_default_name ], [ %module_name, %use_provided_name ]
    %llvm_module = call %LLVMModuleRef @llvm_create_module(%LLVMContextRef %llvm_context, i8* %module_name_to_use)
    %module_null = icmp eq %LLVMModuleRef %llvm_module, null
    br i1 %module_null, label %dispose_context, label %set_target
    
set_target:
    ; Set target triple via LLVM API
    ; Use bitcast to convert the constant array pointer to i8*
    %target_triple_array = bitcast [18 x i8]* @.str.target_triple_value to i8*
    call void @llvm_set_target(%LLVMModuleRef %llvm_module, i8* %target_triple_array)
    
    ; Set data layout via LLVM API
    %data_layout_array = bitcast [38 x i8]* @.str.data_layout_value to i8*
    call void @llvm_set_data_layout(%LLVMModuleRef %llvm_module, i8* %data_layout_array)
    
    ; Allocate initial buffer (64KB) - for text IR generation (backward compatibility)
    %buffer_size = add i64 65536, 0
    %buffer = call i8* @malloc(i64 %buffer_size)
    
    %buffer_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 0
    store i8* %buffer, i8** %buffer_ptr
    
    %size_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 1
    store i64 %buffer_size, i64* %size_ptr
    
    %pos_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 2
    store i64 0, i64* %pos_ptr
    
    %str_counter_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 3
    store i32 0, i32* %str_counter_ptr
    
    %label_counter_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 4
    store i32 0, i32* %label_counter_ptr
    
    ; Store LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 5
    store %LLVMContextRef %llvm_context, %LLVMContextRef* %context_ptr
    
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 6
    store %LLVMModuleRef %llvm_module, %LLVMModuleRef* %module_ptr
    
    ; Initialize builder to null (will be created when needed)
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 7
    store %LLVMBuilderRef null, %LLVMBuilderRef* %builder_ptr
    
    ; Initialize DSL evaluation fields
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 8
    store %LLVMValueRef null, %LLVMValueRef* %current_function_ptr
    
    %param_names_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 9
    store %ASTNode* null, %ASTNode** %param_names_ptr
    
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_ptr
    
    %function_types_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 11
    store %ASTNode* null, %ASTNode** %function_types_ptr
    
    ; Initialize tracking fields
    %constants_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 12
    store %ASTNode* null, %ASTNode** %constants_ptr
    
    %types_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 13
    store %ASTNode* null, %ASTNode** %types_ptr
    
    %llvm_functions_ptr = getelementptr %CodeGen, %CodeGen* %cg_ptr, i32 0, i32 14
    store %ASTNode* null, %ASTNode** %llvm_functions_ptr
    
    ; Write target triple header (46 bytes without null terminator) - text IR approach (backward compatibility)
    call void @codegen_append(%CodeGen* %cg_ptr, i8* getelementptr inbounds ([38 x i8], [38 x i8]* @.str.target_triple, i32 0, i32 0), i64 37)
    
    ; Note: printf and other C library functions should now be declared via
    ; define-llvm-ffi-function in user code or runtime, not hardcoded here
    
    ret %CodeGen* %cg_ptr
    
dispose_context:
    call void @llvm_dispose_context(%LLVMContextRef %llvm_context)
    br label %error
    
error:
    call void @free(i8* %cg)
    ret %CodeGen* null
}

; Dispose code generator
; codegen_dispose: Dispose code generator and clean up LLVM resources
; Parameters:
;   cg: Pointer to CodeGen structure
define void @codegen_dispose(%CodeGen* %cg) {
entry:
    %cg_null = icmp eq %CodeGen* %cg, null
    br i1 %cg_null, label %done, label %dispose_resources
    
dispose_resources:
    ; Get LLVM context, module, and builder
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    ; Dispose builder first
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %dispose_module_check, label %dispose_builder
    
dispose_builder:
    call void @llvm_dispose_builder(%LLVMBuilderRef %builder)
    br label %dispose_module_check
    
dispose_module_check:
    ; Dispose module
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %dispose_context, label %dispose_module
    
dispose_module:
    call void @llvm_dispose_module(%LLVMModuleRef %module)
    br label %dispose_context
    
dispose_context:
    ; Dispose context
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %free_buffer, label %dispose_ctx
    
dispose_ctx:
    call void @llvm_dispose_context(%LLVMContextRef %context)
    br label %free_buffer
    
free_buffer:
    ; Free text buffer (backward compatibility)
    %buffer_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 0
    %buffer = load i8*, i8** %buffer_ptr
    %buffer_null = icmp eq i8* %buffer, null
    br i1 %buffer_null, label %free_cg, label %free_buf
    
free_buf:
    call void @free(i8* %buffer)
    br label %free_cg
    
free_cg:
    ; Free CodeGen structure
    %cg_bytes = bitcast %CodeGen* %cg to i8*
    call void @free(i8* %cg_bytes)
    br label %done
    
done:
    ret void
}

; Append string to IR buffer
; codegen_append: Append a string to the IR buffer
; Parameters:
;   cg: Pointer to CodeGen structure
;   str: String to append
;   len: Length of string
define void @codegen_append(%CodeGen* %cg, i8* %str, i64 %len) {
entry:
    %pos_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    
    %size_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 1
    %size = load i64, i64* %size_ptr
    
    ; Check if we need to grow buffer
    %new_pos = add i64 %pos, %len
    %needs_grow = icmp ugt i64 %new_pos, %size
    br i1 %needs_grow, label %grow, label %append

grow:
    ; Double the buffer size
    %new_size = mul i64 %size, 2
    %buffer_ptr_grow = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 0
    %old_buffer = load i8*, i8** %buffer_ptr_grow
    %new_buffer = call i8* @realloc(i8* %old_buffer, i64 %new_size)
    store i8* %new_buffer, i8** %buffer_ptr_grow
    store i64 %new_size, i64* %size_ptr
    br label %append

append:
    %buffer_ptr_append = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 0
    %buffer = load i8*, i8** %buffer_ptr_append
    %dest = getelementptr i8, i8* %buffer, i64 %pos
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest, i8* %str, i64 %len, i1 false)
    
    %new_pos_append = add i64 %pos, %len
    store i64 %new_pos_append, i64* %pos_ptr
    ret void
}

; Generate string constant
; codegen_string_literal: Generate a string constant in IR
; Parameters:
;   cg: Pointer to CodeGen structure
;   str: String value
;   len: String length
; Returns: Constant name (as string pointer)
; NOTE: This function generates the constant definition using both LLVM API and text IR.
; LLVM API is used to create the actual constant, text IR is kept for backward compatibility.
define i8* @codegen_string_literal(%CodeGen* %cg, i8* %str, i64 %len) {
entry:
    ; Get unique constant name
    %counter_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 3
    %counter = load i32, i32* %counter_ptr
    %new_counter = add i32 %counter, 1
    store i32 %new_counter, i32* %counter_ptr
    
    ; Generate constant name (simplified - in real implementation, format number)
    ; For now, use a simple naming scheme
    %name = call i8* @codegen_format_string_name(i32 %counter)
    
    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    ; Create string constant using LLVM API
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %can_use_llvm = or i1 %context_null, %module_null
    %can_use_llvm_not = xor i1 %can_use_llvm, -1
    br i1 %can_use_llvm_not, label %create_llvm_constant, label %text_only
    
create_llvm_constant:
    ; Get i8 type
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    
    ; Create array type [len+1 x i8] (including null terminator)
    %len_plus_one = add i64 %len, 1
    %len_plus_one_int = trunc i64 %len_plus_one to i32
    %array_type = call %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %i8_type, i32 %len_plus_one_int)
    
    ; Create string constant (with null terminator)
    %str_len_int = trunc i64 %len to i32
    %const_str = call %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef %context, i8* %str, i32 %str_len_int, i32 0)
    
    ; Add as global variable with the constant name
    %global = call %LLVMValueRef @llvm_add_global(%LLVMModuleRef %module, %LLVMTypeRef %array_type, i8* %name)
    
    ; Set initializer
    call void @llvm_set_initializer(%LLVMValueRef %global, %LLVMValueRef %const_str)
    
    ; Set as constant
    call void @llvm_set_global_constant(%LLVMValueRef %global, i32 1)
    
    ; Set linkage to private (equivalent to "private" in text IR)
    ; LLVMLinkage enum: LLVMPrivateLinkage = 0
    call void @llvm_set_linkage(%LLVMValueRef %global, i32 0)
    
    br label %text_only
    
text_only:
    ; Generate IR: @.str_N = private constant [L x i8] c"...\00"
    ; Keep text IR generation for backward compatibility
    call void @codegen_append_string_constant(%CodeGen* %cg, i8* %name, i8* %str, i64 %len)
    
    ret i8* %name
}

; Helper to format string constant name
; codegen_format_string_name: Format a string constant name
; Parameters:
;   num: Number for unique name
; Returns: Formatted name string (e.g., ".str.0")
define i8* @codegen_format_string_name(i32 %num) {
entry:
    ; Allocate buffer for name (e.g., ".str.0" = 6 bytes + null = 7)
    %buffer = call i8* @malloc(i64 16)
    
    ; Write ".str."
    %dot_str = getelementptr i8, i8* %buffer, i64 0
    store i8 46, i8* %dot_str  ; '.'
    %s = getelementptr i8, i8* %buffer, i64 1
    store i8 115, i8* %s  ; 's'
    %t = getelementptr i8, i8* %buffer, i64 2
    store i8 116, i8* %t  ; 't'
    %r = getelementptr i8, i8* %buffer, i64 3
    store i8 114, i8* %r  ; 'r'
    %dot2 = getelementptr i8, i8* %buffer, i64 4
    store i8 46, i8* %dot2  ; '.'
    
    ; Convert number to string (simplified - just use single digit for now)
    %num_mod = urem i32 %num, 10
    %num_char = add i32 %num_mod, 48  ; Convert to ASCII
    %num_trunc = trunc i32 %num_char to i8
    %num_ptr = getelementptr i8, i8* %buffer, i64 5
    store i8 %num_trunc, i8* %num_ptr
    
    ; Null terminate
    %null_ptr = getelementptr i8, i8* %buffer, i64 6
    store i8 0, i8* %null_ptr
    
    ret i8* %buffer
}

; Append string constant definition to IR
; codegen_append_string_constant: Append string constant definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Constant name
;   str: String value
;   len: String length
define void @codegen_append_string_constant(%CodeGen* %cg, i8* %name, i8* %str, i64 %len) {
entry:
    ; Generate: @.str_N = private constant [L x i8] c"...\00"
    ; Note: name is like ".str.0", we need "@.str.0" for the constant declaration
    ; Start with "@"
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    
    ; Append name (name is ".str.0", so this gives "@.str.0")
    %name_len = call i64 @strlen(i8* %name)
    call void @codegen_append(%CodeGen* %cg, i8* %name, i64 %name_len)
    
    ; Append " = private constant ["
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.constant_decl, i32 0, i32 0), i64 21)
    
    ; Append length as string (including null terminator)
    %len_plus_one = add i64 %len, 1
    %len_str = call i8* @codegen_format_number(i64 %len_plus_one)
    %len_str_len = call i64 @strlen(i8* %len_str)
    call void @codegen_append(%CodeGen* %cg, i8* %len_str, i64 %len_str_len)
    
    ; Append " x i8] c\""
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.x_i8_c_quote, i32 0, i32 0), i64 9)
    
    ; Append string with escaping
    call void @codegen_append_escaped_string(%CodeGen* %cg, i8* %str, i64 %len)
    
    ; Append null terminator "\00"
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.backslash_00, i32 0, i32 0), i64 3)
    
    ; Append "\"\0A"
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.quote_newline, i32 0, i32 0), i64 2)
    
    ret void
}

; Format number as string (simplified implementation)
; codegen_format_number: Convert number to string
; Parameters:
;   num: Number to convert
; Returns: String representation
define i8* @codegen_format_number(i64 %num) {
entry:
    %buffer = call i8* @malloc(i64 32)
    ; Simplified - just convert to single digit for now
    %num_mod = urem i64 %num, 10
    %num_char = add i64 %num_mod, 48
    %num_trunc = trunc i64 %num_char to i8
    store i8 %num_trunc, i8* %buffer
    %null_ptr = getelementptr i8, i8* %buffer, i64 1
    store i8 0, i8* %null_ptr
    ret i8* %buffer
}

; Append escaped string
; codegen_append_escaped_string: Append string with proper escaping for LLVM IR
; Parameters:
;   cg: Pointer to CodeGen structure
;   str: String value
;   len: String length
define void @codegen_append_escaped_string(%CodeGen* %cg, i8* %str, i64 %len) {
entry:
    %i = alloca i64
    store i64 0, i64* %i
    br label %loop

loop:
    %i_val = load i64, i64* %i
    %done = icmp uge i64 %i_val, %len
    br i1 %done, label %exit, label %process_char

process_char:
    %char_ptr = getelementptr i8, i8* %str, i64 %i_val
    %char = load i8, i8* %char_ptr
    %char_int = zext i8 %char to i32
    
    ; Check if null byte - escape as \00
    %is_null = icmp eq i32 %char_int, 0
    br i1 %is_null, label %escape_null, label %check_quote
    
escape_null:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.backslash_00, i32 0, i32 0), i64 3)
    br label %increment
    
check_quote:
    ; Check if quote - escape as \"
    %is_quote = icmp eq i32 %char_int, 34
    br i1 %is_quote, label %escape_quote, label %check_backslash
    
escape_quote:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.backslash_quote, i32 0, i32 0), i64 2)
    br label %increment
    
check_backslash:
    ; Check if backslash - escape as \\
    %is_backslash = icmp eq i32 %char_int, 92
    br i1 %is_backslash, label %escape_backslash, label %normal_char
    
escape_backslash:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.backslash_backslash, i32 0, i32 0), i64 2)
    br label %increment
    
normal_char:
    ; Write byte directly
    call void @codegen_append(%CodeGen* %cg, i8* %char_ptr, i64 1)
    br label %increment
    
increment:
    %i_val_inc = load i64, i64* %i
    %i_new = add i64 %i_val_inc, 1
    store i64 %i_new, i64* %i
    br label %loop

exit:
    ret void
}

; Handle define-bitcode-type AST node
; codegen_define_llvm_type: Generate LLVM type definition using direct LLVM API
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-llvm-type form
; Returns: 0 on success, -1 on error
; Syntax: (define-llvm-type TypeName (field1 type1) (field2 type2) ...)
define i32 @codegen_define_llvm_type(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; AST structure: LIST { ATOM: "define-llvm-type", ATOM: "TypeName", LIST: fields, ... }
    ; Get type name (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %type_name_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %type_name_node = load %ASTNode*, %ASTNode** %type_name_node_ptr
    %type_name_val_ptr = getelementptr %ASTNode, %ASTNode* %type_name_node, i32 0, i32 2
    %type_name = load i8*, i8** %type_name_val_ptr
    
    ; Get type name length
    %type_name_len_ptr = getelementptr %ASTNode, %ASTNode* %type_name_node, i32 0, i32 3
    %type_name_len = load i64, i64* %type_name_len_ptr
    
    ; Get fields list (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %fields_list = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    
    ; Get LLVM context
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %error, label %collect_fields
    
collect_fields:
    ; Allocate array for field types (max 64 fields)
    %types_array = alloca %LLVMTypeRef, i32 64
    %field_count = call i32 @codegen_collect_field_types(%CodeGen* %cg, %ASTNode* %fields_list, %LLVMTypeRef* %types_array, i32 64)
    %field_count_zero = icmp eq i32 %field_count, 0
    br i1 %field_count_zero, label %error, label %create_struct
    
create_struct:
    ; Create named struct type using LLVM API
    ; First, create null-terminated type name
    %name_buf_size = add i64 %type_name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %type_name, i64 %type_name_len, i1 false)
    %null_ptr = getelementptr i8, i8* %name_buf, i64 %type_name_len
    store i8 0, i8* %null_ptr
    
    ; Create named (opaque) struct type
    %named_struct_type = call %LLVMTypeRef @llvm_create_named_struct_type(%LLVMContextRef %context, i8* %name_buf)
    %named_struct_null = icmp eq %LLVMTypeRef %named_struct_type, null
    br i1 %named_struct_null, label %free_name_buf_error, label %set_struct_body
    
free_name_buf_error:
    call void @free(i8* %name_buf)
    br label %error
    
set_struct_body:
    ; Set the body of the struct type
    call void @llvm_set_struct_body(%LLVMTypeRef %named_struct_type, %LLVMTypeRef* %types_array, i32 %field_count, i32 0)
    
    ; Free name buffer
    call void @free(i8* %name_buf)
    
    ; Store type for later lookup
    call void @codegen_store_type(%CodeGen* %cg, i8* %type_name, i64 %type_name_len, %LLVMTypeRef %named_struct_type)
    
    ; Also generate text IR for backward compatibility
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.percent, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %type_name, i64 %type_name_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.type_equals, i32 0, i32 0), i64 7)
    call void @codegen_append_type_fields(%CodeGen* %cg, %ASTNode* %fields_list)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0), i64 1)
    
    ret i32 0
    
error:
    ret i32 -1
}

; Append type fields to IR
; codegen_append_type_fields: Generate field list for type definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   fields: AST node list of (field-name type) pairs
define void @codegen_append_type_fields(%CodeGen* %cg, %ASTNode* %fields) {
entry:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.lbrace, i32 0, i32 0), i64 2)
    
    %is_null = icmp eq %ASTNode* %fields, null
    br i1 %is_null, label %done, label %append_first
    
append_first:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %fields, i32 0, i32 4
    %field_pair = load %ASTNode*, %ASTNode** %car_ptr
    
    ; field_pair is a list: (field-name type)
    %field_car_ptr = getelementptr %ASTNode, %ASTNode* %field_pair, i32 0, i32 4
    %field_name_node = load %ASTNode*, %ASTNode** %field_car_ptr
    %field_name_val_ptr = getelementptr %ASTNode, %ASTNode* %field_name_node, i32 0, i32 2
    %field_name = load i8*, i8** %field_name_val_ptr
    
    %field_cdr_ptr = getelementptr %ASTNode, %ASTNode* %field_pair, i32 0, i32 5
    %field_cdr = load %ASTNode*, %ASTNode** %field_cdr_ptr
    %field_type_node_ptr = getelementptr %ASTNode, %ASTNode* %field_cdr, i32 0, i32 4
    %field_type_node = load %ASTNode*, %ASTNode** %field_type_node_ptr
    %field_type_val_ptr = getelementptr %ASTNode, %ASTNode* %field_type_node, i32 0, i32 2
    %field_type = load i8*, i8** %field_type_val_ptr
    %field_type_len_ptr = getelementptr %ASTNode, %ASTNode* %field_type_node, i32 0, i32 3
    %field_type_len = load i64, i64* %field_type_len_ptr
    
    ; Append field type
    call void @codegen_append(%CodeGen* %cg, i8* %field_type, i64 %field_type_len)
    
    ; Check for more fields
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %fields, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    %has_more = icmp ne %ASTNode* %next, null
    br i1 %has_more, label %append_more, label %done
    
append_more:
    ; Loop through remaining fields using phi node for proper iteration
    %current_field = phi %ASTNode* [ %next, %append_first ], [ %next_field, %append_more ]
    
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.comma_space, i32 0, i32 0), i64 2)
    %next_car_ptr = getelementptr %ASTNode, %ASTNode* %current_field, i32 0, i32 4
    %next_field_pair = load %ASTNode*, %ASTNode** %next_car_ptr
    
    ; next_field_pair is a list: (field-name type)
    %next_field_car_ptr = getelementptr %ASTNode, %ASTNode* %next_field_pair, i32 0, i32 4
    %next_field_name_node = load %ASTNode*, %ASTNode** %next_field_car_ptr
    %next_field_name_val_ptr = getelementptr %ASTNode, %ASTNode* %next_field_name_node, i32 0, i32 2
    %next_field_name = load i8*, i8** %next_field_name_val_ptr
    
    %next_field_cdr_ptr = getelementptr %ASTNode, %ASTNode* %next_field_pair, i32 0, i32 5
    %next_field_cdr = load %ASTNode*, %ASTNode** %next_field_cdr_ptr
    %next_field_type_node_ptr = getelementptr %ASTNode, %ASTNode* %next_field_cdr, i32 0, i32 4
    %next_field_type_node = load %ASTNode*, %ASTNode** %next_field_type_node_ptr
    %next_field_type_val_ptr = getelementptr %ASTNode, %ASTNode* %next_field_type_node, i32 0, i32 2
    %next_field_type = load i8*, i8** %next_field_type_val_ptr
    %next_field_type_len_ptr = getelementptr %ASTNode, %ASTNode* %next_field_type_node, i32 0, i32 3
    %next_field_type_len = load i64, i64* %next_field_type_len_ptr
    
    ; Append field type
    call void @codegen_append(%CodeGen* %cg, i8* %next_field_type, i64 %next_field_type_len)
    
    ; Move to next field
    %next_cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_field, i32 0, i32 5
    %next_field = load %ASTNode*, %ASTNode** %next_cdr_ptr
    %has_more_more = icmp ne %ASTNode* %next_field, null
    br i1 %has_more_more, label %append_more, label %done
    
done:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rbrace, i32 0, i32 0), i64 1)
    ret void
}

; Handle define-bitcode-constant AST node
; codegen_define_llvm_constant: Generate LLVM constant definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-llvm-constant form
; Returns: 0 on success, -1 on error
; Syntax: (define-llvm-constant name type value)
; TODO: Future version will use llvm_create_constant_string() via FFI instead of text IR
define i32 @codegen_define_llvm_constant(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; AST structure: LIST { ATOM: "define-llvm-constant", ATOM: "name", ATOM: "type", ATOM/STRING: value }
    ; Get constant name (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %name_len = load i64, i64* %name_len_ptr
    
    ; Get type (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Get value (fourth element)
    %cdr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 5
    %cdr_cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_cdr_ptr
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    %value_val_ptr = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 2
    %value = load i8*, i8** %value_val_ptr
    %value_len_ptr = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 3
    %value_len = load i64, i64* %value_len_ptr
    
    ; Check if value is a bytevector
    %value_node_type_ptr = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 0
    %value_node_type = load i32, i32* %value_node_type_ptr
    %is_atom = icmp eq i32 %value_node_type, 0  ; AST_ATOM
    br i1 %is_atom, label %check_bytevector, label %not_bytevector
    
check_bytevector:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    %is_bytevector = icmp eq i32 %atom_type, 13  ; TOKEN_BYTEVECTOR
    br i1 %is_bytevector, label %format_bytevector, label %not_bytevector
    
format_bytevector:
    ; Get LLVM context and module for direct API usage
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %either_null = or i1 %context_null, %module_null
    ; Use LLVM API if both context and module are non-null, otherwise fall back to text IR
    br i1 %either_null, label %text_only_constant, label %create_constant_direct
    
create_constant_direct:
    ; Debug: Creating constant
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_creating_constant, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %name)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create constant directly using LLVM API
    ; Resolve type string to LLVMTypeRef
    %constant_type_ref = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type, i64 %type_len)
    %constant_type_ref_null = icmp eq %LLVMTypeRef %constant_type_ref, null
    br i1 %constant_type_ref_null, label %text_only_constant, label %create_string_constant
    
create_string_constant:
    ; Create constant string from bytevector
    ; Get i8 type for array element
    %i8_type_const = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_type_const_null = icmp eq %LLVMTypeRef %i8_type_const, null
    br i1 %i8_type_const_null, label %text_only_constant, label %create_const_str
    
create_const_str:
    ; Create constant string value
    ; Note: If the bytevector already includes a null terminator, we should pass dont_null_terminate=1
    ; For now, we'll check if the last byte is null and adjust accordingly
    ; But for simplicity, assume bytevectors include null terminator and pass dont_null_terminate=1
    %value_len_int_const = trunc i64 %value_len to i32
    %const_str_value = call %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef %context, i8* %value, i32 %value_len_int_const, i32 1)
    %const_str_value_null = icmp eq %LLVMValueRef %const_str_value, null
    br i1 %const_str_value_null, label %text_only_constant, label %create_global
    
create_global:
    ; Create null-terminated name for global
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    
    ; Add global variable with the constant name
    %global_const = call %LLVMValueRef @llvm_add_global(%LLVMModuleRef %module, %LLVMTypeRef %constant_type_ref, i8* %name_buf)
    call void @free(i8* %name_buf)
    
    %global_const_null = icmp eq %LLVMValueRef %global_const, null
    br i1 %global_const_null, label %text_only_constant, label %set_initializer
    
set_initializer:
    ; Set initializer
    call void @llvm_set_initializer(%LLVMValueRef %global_const, %LLVMValueRef %const_str_value)
    
    ; Set as constant
    call void @llvm_set_global_constant(%LLVMValueRef %global_const, i32 1)
    
    ; Set linkage to private
    call void @llvm_set_linkage(%LLVMValueRef %global_const, i32 0)
    
    ; Debug: Constant created
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_constant_created, i32 0, i32 0))
    %global_const_ptr = bitcast %LLVMValueRef %global_const to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %global_const_ptr)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Store constant for later lookup
    call void @codegen_store_constant(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef %global_const)
    
    ; Also generate text IR for backward compatibility
    br label %text_only_constant
    
text_only_constant:
    ; Generate text IR for backward compatibility (or fallback if LLVM API unavailable)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %name, i64 %name_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.constant_equals, i32 0, i32 0), i64 11)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %type, i64 %type_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.c_quote_open, i32 0, i32 0), i64 2)
    call void @codegen_append_bytevector(%CodeGen* %cg, i8* %value, i64 %value_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.quote, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0), i64 1)
    ret i32 0
    
not_bytevector:
    ; Generate: @name = constant type value (for non-bytevector values)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %name, i64 %name_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.constant_equals, i32 0, i32 0), i64 11)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %type, i64 %type_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %value, i64 %value_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0), i64 1)
    
    ret i32 0
}

; OLD PARSING CODE REMOVED - Now using direct LLVM API
; The following code was removed as it's no longer needed:
; - parse_constant_old and all its IR building code
; - link_constant and module linking code  
; - All the old parsing/linking infrastructure
; We now create constants directly using:
; - codegen_resolve_type_string to get LLVMTypeRef
; - llvm_create_constant_string to create the constant value
; - llvm_add_global to create the global
; - llvm_set_initializer, llvm_set_global_constant, llvm_set_linkage to configure it
; - codegen_store_constant to store it for later lookup

; codegen_create_pointer_node: defined in codegen.vibe
declare %ASTNode* @codegen_create_pointer_node(i8*)

; Store constant in constants list
; codegen_store_constant: Store a constant name and LLVMValueRef pair
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Constant name
;   name_len: Name length
;   value: LLVMValueRef for the constant
define void @codegen_store_constant(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef %value) {
entry:
    ; Debug: Storing constant
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_storing_constant, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %name)
    %value_ptr_cast = bitcast %LLVMValueRef %value to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %value_ptr_cast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create name node
    %name_node = call %ASTNode* @codegen_create_string_node(i8* %name, i64 %name_len)
    
    ; Create value node (pointer node)
    %value_node = call %ASTNode* @codegen_create_pointer_node(i8* %value_ptr_cast)
    
    ; Create pair: (name . value)
    %pair = call %ASTNode* @codegen_create_cons(%ASTNode* %name_node, %ASTNode* %value_node)
    
    ; Get current constants list
    %constants_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 12
    %current_constants = load %ASTNode*, %ASTNode** %constants_ptr
    
    ; Prepend new pair to list
    %new_constants = call %ASTNode* @codegen_create_cons(%ASTNode* %pair, %ASTNode* %current_constants)
    
    ; Store updated list
    store %ASTNode* %new_constants, %ASTNode** %constants_ptr
    
    ; Debug: Constant stored successfully
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_constant_stored, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %value_ptr_cast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ret void
}

; Get constant by name
; codegen_get_constant: Look up a constant by name and return LLVMValueRef
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Constant name
;   name_len: Name length
; Returns: LLVMValueRef for the constant, or null if not found
define %LLVMValueRef @codegen_get_constant(%CodeGen* %cg, i8* %name, i64 %name_len) {
entry:
    ; Debug: Looking up constant
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_looking_up_constant, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %name)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get constants list
    %constants_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 12
    %constants = load %ASTNode*, %ASTNode** %constants_ptr
    
    %constants_null = icmp eq %ASTNode* %constants, null
    br i1 %constants_null, label %not_found, label %search_loop
    
search_loop:
    %current = alloca %ASTNode*
    store %ASTNode* %constants, %ASTNode** %current
    br label %iterate
    
iterate:
    %current_val = load %ASTNode*, %ASTNode** %current
    %current_null = icmp eq %ASTNode* %current_val, null
    br i1 %current_null, label %not_found, label %check_pair
    
check_pair:
    ; Get pair from car: (name . value)
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 4
    %pair = load %ASTNode*, %ASTNode** %car_ptr
    %pair_null = icmp eq %ASTNode* %pair, null
    br i1 %pair_null, label %next, label %compare_name
    
compare_name:
    ; Get name from pair.car
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %pair, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %name_node_null = icmp eq %ASTNode* %name_node, null
    br i1 %name_node_null, label %next, label %get_name
    
get_name:
    %stored_name_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %stored_name = load i8*, i8** %stored_name_ptr
    %stored_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %stored_len = load i64, i64* %stored_len_ptr
    
    ; Compare names
    %len_match = icmp eq i64 %stored_len, %name_len
    br i1 %len_match, label %compare_chars, label %next
    
compare_chars:
    %len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %stored_name, i8* %name, i32 %len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %found, label %next
    
found:
    ; Get value from pair.cdr
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %pair, i32 0, i32 5
    %value_node = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    %value_node_null = icmp eq %ASTNode* %value_node, null
    br i1 %value_node_null, label %not_found, label %extract_value
    
extract_value:
    ; Verify it's a pointer node (atom_type 999)
    %value_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 1
    %value_atom_type = load i32, i32* %value_atom_type_ptr
    %is_pointer = icmp eq i32 %value_atom_type, 999
    br i1 %is_pointer, label %cast_back, label %not_found
    
cast_back:
    ; Extract pointer from value field
    %value_ptr_field = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 2
    %value_ptr = load i8*, i8** %value_ptr_field
    %value_ref = bitcast i8* %value_ptr to %LLVMValueRef
    
    ; Debug: Constant found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([26 x i8], [26 x i8]* @.str.debug_constant_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %value_ptr)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ret %LLVMValueRef %value_ref
    
next:
    ; Move to next in list
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current
    br label %iterate
    
not_found:
    ; Debug: Constant not found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([26 x i8], [26 x i8]* @.str.debug_constant_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %name)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ret %LLVMValueRef null
}

; codegen_is_array_type: defined in codegen.vibe
declare i32 @codegen_is_array_type(%LLVMTypeRef)

; codegen_eval_dsl_expr: Evaluate DSL expressions (llvm-call, llvm-get-function, etc.)
; This function is defined later in the file (around line 4004)

; Helper function to collect field types for struct type creation
; codegen_collect_field_types: Collect field types from AST list into array
; Parameters:
;   cg: Pointer to CodeGen structure
;   fields: AST node list of (field-name type) pairs
;   types_array: Pre-allocated array to store LLVMTypeRef values
;   max_fields: Maximum number of fields (array size)
; Returns: i32 count of fields collected
define i32 @codegen_collect_field_types(%CodeGen* %cg, %ASTNode* %fields, %LLVMTypeRef* %types_array, i32 %max_fields) {
entry:
    %count = alloca i32
    store i32 0, i32* %count
    
    %fields_null = icmp eq %ASTNode* %fields, null
    br i1 %fields_null, label %done, label %collect_loop
    
collect_loop:
    %current_fields = phi %ASTNode* [ %fields, %entry ], [ %next_fields, %continue_collect ]
    %current_count = load i32, i32* %count
    %at_max = icmp uge i32 %current_count, %max_fields
    br i1 %at_max, label %done, label %get_field_pair
    
get_field_pair:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_fields, i32 0, i32 4
    %field_pair = load %ASTNode*, %ASTNode** %car_ptr
    %field_pair_null = icmp eq %ASTNode* %field_pair, null
    br i1 %field_pair_null, label %done, label %get_field_type
    
get_field_type:
    ; field_pair is (field-name type)
    ; Get type from cdr
    %field_cdr_ptr = getelementptr %ASTNode, %ASTNode* %field_pair, i32 0, i32 5
    %field_cdr = load %ASTNode*, %ASTNode** %field_cdr_ptr
    %field_cdr_null = icmp eq %ASTNode* %field_cdr, null
    br i1 %field_cdr_null, label %done, label %get_type_node
    
get_type_node:
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %field_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %done, label %resolve_type
    
resolve_type:
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type string to LLVMTypeRef
    %field_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %field_type_null = icmp eq %LLVMTypeRef %field_type, null
    br i1 %field_type_null, label %done, label %store_type
    
store_type:
    ; Store type in array
    %count_val = load i32, i32* %count
    %array_idx = getelementptr %LLVMTypeRef, %LLVMTypeRef* %types_array, i32 %count_val
    store %LLVMTypeRef %field_type, %LLVMTypeRef* %array_idx
    
    ; Increment count
    %new_count = add i32 %count_val, 1
    store i32 %new_count, i32* %count
    br label %continue_collect
    
continue_collect:
    ; Move to next field
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_fields, i32 0, i32 5
    %next_fields = load %ASTNode*, %ASTNode** %cdr_ptr
    %has_more = icmp ne %ASTNode* %next_fields, null
    br i1 %has_more, label %collect_loop, label %done
    
done:
    %final_count = load i32, i32* %count
    ret i32 %final_count
}

; DUPLICATE codegen_define_llvm_type REMOVED - the correct version is at line 568
; DUPLICATE codegen_append_type_fields REMOVED - the correct version is at line 629

; OLD PARSING CODE REMOVED - All the old IR building, parsing, and linking code has been deleted
; This code was replaced with direct LLVM API calls:
; - For constants: llvm_create_constant_string, llvm_add_global, llvm_set_initializer, etc.
; - For types: llvm_get_struct_type with field types collected via codegen_collect_field_types

; DUPLICATE codegen_create_pointer_node REMOVED - the correct version is at line 861
; DUPLICATE codegen_store_constant REMOVED - the correct version is at line 898
; DUPLICATE codegen_get_constant REMOVED - the correct version is at line 936
; DUPLICATE codegen_is_array_type REMOVED - the correct version is at line 1024
; All duplicate functions removed - continuing with rest of file...

; Store type in types list
; codegen_store_type: Store a type name and LLVMTypeRef pair
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Type name
;   name_len: Name length
;   type: LLVMTypeRef for the type
define void @codegen_store_type(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMTypeRef %type) {
entry:
    ; Create name node
    %name_node = call %ASTNode* @codegen_create_string_node(i8* %name, i64 %name_len)
    
    ; Create type node (pointer node)
    %type_ptr_cast = bitcast %LLVMTypeRef %type to i8*
    %type_node = call %ASTNode* @codegen_create_pointer_node(i8* %type_ptr_cast)
    
    ; Create pair: (name . type)
    %pair = call %ASTNode* @codegen_create_cons(%ASTNode* %name_node, %ASTNode* %type_node)
    
    ; Get current types list
    %types_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 13
    %current_types = load %ASTNode*, %ASTNode** %types_ptr
    
    ; Prepend new pair to list
    %new_types = call %ASTNode* @codegen_create_cons(%ASTNode* %pair, %ASTNode* %current_types)
    
    ; Store updated list
    store %ASTNode* %new_types, %ASTNode** %types_ptr
    
    ret void
}

; Get type by name
; codegen_get_type: Look up a type by name and return LLVMTypeRef
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Type name
;   name_len: Name length
; Returns: LLVMTypeRef for the type, or null if not found
define %LLVMTypeRef @codegen_get_type(%CodeGen* %cg, i8* %name, i64 %name_len) {
entry:
    ; Get types list
    %types_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 13
    %types = load %ASTNode*, %ASTNode** %types_ptr
    
    %types_null = icmp eq %ASTNode* %types, null
    br i1 %types_null, label %not_found_type, label %search_loop_type
    
search_loop_type:
    %current_type = alloca %ASTNode*
    store %ASTNode* %types, %ASTNode** %current_type
    br label %iterate_type
    
iterate_type:
    %current_val_type = load %ASTNode*, %ASTNode** %current_type
    %current_null_type = icmp eq %ASTNode* %current_val_type, null
    br i1 %current_null_type, label %not_found_type, label %check_pair_type
    
check_pair_type:
    ; Get pair from car: (name . type)
    %car_ptr_type = getelementptr %ASTNode, %ASTNode* %current_val_type, i32 0, i32 4
    %pair_type = load %ASTNode*, %ASTNode** %car_ptr_type
    %pair_null_type = icmp eq %ASTNode* %pair_type, null
    br i1 %pair_null_type, label %next_type, label %compare_name_type
    
compare_name_type:
    ; Get name from pair.car
    %pair_car_ptr_type = getelementptr %ASTNode, %ASTNode* %pair_type, i32 0, i32 4
    %name_node_type = load %ASTNode*, %ASTNode** %pair_car_ptr_type
    %name_node_null_type = icmp eq %ASTNode* %name_node_type, null
    br i1 %name_node_null_type, label %next_type, label %get_name_type
    
get_name_type:
    %stored_name_ptr_type = getelementptr %ASTNode, %ASTNode* %name_node_type, i32 0, i32 2
    %stored_name_type = load i8*, i8** %stored_name_ptr_type
    %stored_len_ptr_type = getelementptr %ASTNode, %ASTNode* %name_node_type, i32 0, i32 3
    %stored_len_type = load i64, i64* %stored_len_ptr_type
    
    ; Compare names
    %len_match_type = icmp eq i64 %stored_len_type, %name_len
    br i1 %len_match_type, label %compare_chars_type, label %next_type
    
compare_chars_type:
    %len_int_type = trunc i64 %name_len to i32
    %cmp_result_type = call i32 @strncmp(i8* %stored_name_type, i8* %name, i32 %len_int_type)
    %is_match_type = icmp eq i32 %cmp_result_type, 0
    br i1 %is_match_type, label %found_type, label %next_type
    
found_type:
    ; Get type from pair.cdr
    %pair_cdr_ptr_type = getelementptr %ASTNode, %ASTNode* %pair_type, i32 0, i32 5
    %type_node = load %ASTNode*, %ASTNode** %pair_cdr_ptr_type
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %not_found_type, label %extract_type
    
extract_type:
    ; Verify it's a pointer node (atom_type 999)
    %type_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 1
    %type_atom_type = load i32, i32* %type_atom_type_ptr
    %is_pointer_type = icmp eq i32 %type_atom_type, 999
    br i1 %is_pointer_type, label %cast_back_type, label %not_found_type
    
cast_back_type:
    ; Extract pointer from value field
    %type_ptr_field = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_ptr = load i8*, i8** %type_ptr_field
    %type_ref = bitcast i8* %type_ptr to %LLVMTypeRef
    ret %LLVMTypeRef %type_ref
    
next_type:
    ; Move to next in list
    %cdr_ptr_type = getelementptr %ASTNode, %ASTNode* %current_val_type, i32 0, i32 5
    %cdr_type = load %ASTNode*, %ASTNode** %cdr_ptr_type
    store %ASTNode* %cdr_type, %ASTNode** %current_type
    br label %iterate_type
    
not_found_type:
    ret %LLVMTypeRef null
}

; Store function in llvm_functions list
; codegen_store_llvm_function: Store a function name, LLVMValueRef, and LLVMTypeRef
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Function name
;   name_len: Name length
;   func_value: LLVMValueRef for the function
;   func_type: LLVMTypeRef for the function type
define void @codegen_store_llvm_function(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef %func_value, %LLVMTypeRef %func_type) {
entry:
    ; Create name node
    %name_node = call %ASTNode* @codegen_create_string_node(i8* %name, i64 %name_len)
    
    ; Create function value node (pointer node)
    %func_value_ptr = bitcast %LLVMValueRef %func_value to i8*
    %func_value_node = call %ASTNode* @codegen_create_pointer_node(i8* %func_value_ptr)
    
    ; Create function type node (pointer node)
    %func_type_ptr = bitcast %LLVMTypeRef %func_type to i8*
    %func_type_node = call %ASTNode* @codegen_create_pointer_node(i8* %func_type_ptr)
    
    ; Create pair: (func_value . func_type)
    %value_type_pair = call %ASTNode* @codegen_create_cons(%ASTNode* %func_value_node, %ASTNode* %func_type_node)
    
    ; Create pair: (name . (func_value . func_type))
    %name_func_pair = call %ASTNode* @codegen_create_cons(%ASTNode* %name_node, %ASTNode* %value_type_pair)
    
    ; Get current llvm_functions list
    %llvm_functions_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 14
    %current_functions = load %ASTNode*, %ASTNode** %llvm_functions_ptr
    
    ; Prepend new pair to list
    %new_functions = call %ASTNode* @codegen_create_cons(%ASTNode* %name_func_pair, %ASTNode* %current_functions)
    
    ; Store updated list
    store %ASTNode* %new_functions, %ASTNode** %llvm_functions_ptr
    
    ret void
}

; Get function by name
; codegen_get_llvm_function: Look up a function by name and return LLVMValueRef and LLVMTypeRef
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Function name
;   name_len: Name length
;   func_value_out: Pointer to store LLVMValueRef
;   func_type_out: Pointer to store LLVMTypeRef
; Returns: 1 if found, 0 if not found
define i32 @codegen_get_llvm_function(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef* %func_value_out, %LLVMTypeRef* %func_type_out) {
entry:
    ; Debug: Looking up function
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_looking_up_function, i32 0, i32 0))
    ; Print function name if valid
    %name_not_null = icmp ne i8* %name, null
    %name_len_valid = icmp ugt i64 %name_len, 0
    %can_print_name = and i1 %name_not_null, %name_len_valid
    br i1 %can_print_name, label %print_func_name, label %skip_print_func_name
    
print_func_name:
    %name_len_plus1_func = add i64 %name_len, 1
    %name_buf_func = call i8* @malloc(i64 %name_len_plus1_func)
    %name_buf_func_null = icmp eq i8* %name_buf_func, null
    br i1 %name_buf_func_null, label %skip_print_func_name, label %do_print_func_name
    
do_print_func_name:
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf_func, i8* %name, i64 %name_len, i1 false)
    %name_null_func = getelementptr i8, i8* %name_buf_func, i64 %name_len
    store i8 0, i8* %name_null_func
    call i32 (i8*, ...) @printf(i8* %name_buf_func)
    call void @free(i8* %name_buf_func)
    br label %skip_print_func_name
    
skip_print_func_name:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get llvm_functions list
    %llvm_functions_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 14
    %functions = load %ASTNode*, %ASTNode** %llvm_functions_ptr
    
    %functions_null = icmp eq %ASTNode* %functions, null
    br i1 %functions_null, label %not_found_func_debug, label %count_functions
    
not_found_func_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_function_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found_func
    
count_functions:
    ; Count functions in list for debug output
    %func_count = alloca i32
    store i32 0, i32* %func_count
    %current_func_count = alloca %ASTNode*
    store %ASTNode* %functions, %ASTNode** %current_func_count
    br label %count_loop
    
count_loop:
    %current_val_count = load %ASTNode*, %ASTNode** %current_func_count
    %current_null_count = icmp eq %ASTNode* %current_val_count, null
    br i1 %current_null_count, label %count_done, label %increment_count
    
increment_count:
    %count_val = load i32, i32* %func_count
    %count_inc = add i32 %count_val, 1
    store i32 %count_inc, i32* %func_count
    %cdr_ptr_count = getelementptr %ASTNode, %ASTNode* %current_val_count, i32 0, i32 5
    %cdr_count = load %ASTNode*, %ASTNode** %cdr_ptr_count
    store %ASTNode* %cdr_count, %ASTNode** %current_func_count
    br label %count_loop
    
count_done:
    %final_count = load i32, i32* %func_count
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_function_list_size, i32 0, i32 0), i32 %final_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %search_loop_func
    
search_loop_func:
    %current_func = alloca %ASTNode*
    store %ASTNode* %functions, %ASTNode** %current_func
    br label %iterate_func
    
iterate_func:
    %current_val_func = load %ASTNode*, %ASTNode** %current_func
    %current_null_func = icmp eq %ASTNode* %current_val_func, null
    br i1 %current_null_func, label %not_found_func, label %check_pair_func
    
check_pair_func:
    ; Get pair from car: (name . (func_value . func_type))
    %car_ptr_func = getelementptr %ASTNode, %ASTNode* %current_val_func, i32 0, i32 4
    %pair_func = load %ASTNode*, %ASTNode** %car_ptr_func
    %pair_null_func = icmp eq %ASTNode* %pair_func, null
    br i1 %pair_null_func, label %next_func, label %compare_name_func
    
compare_name_func:
    ; Get name from pair.car
    %pair_car_ptr_func = getelementptr %ASTNode, %ASTNode* %pair_func, i32 0, i32 4
    %name_node_func = load %ASTNode*, %ASTNode** %pair_car_ptr_func
    %name_node_null_func = icmp eq %ASTNode* %name_node_func, null
    br i1 %name_node_null_func, label %next_func, label %get_name_func
    
get_name_func:
    %stored_name_ptr_func = getelementptr %ASTNode, %ASTNode* %name_node_func, i32 0, i32 2
    %stored_name_func = load i8*, i8** %stored_name_ptr_func
    %stored_len_ptr_func = getelementptr %ASTNode, %ASTNode* %name_node_func, i32 0, i32 3
    %stored_len_func = load i64, i64* %stored_len_ptr_func
    
    ; Compare names
    %len_match_func = icmp eq i64 %stored_len_func, %name_len
    br i1 %len_match_func, label %compare_chars_func, label %next_func
    
compare_chars_func:
    %len_int_func = trunc i64 %name_len to i32
    %cmp_result_func = call i32 @strncmp(i8* %stored_name_func, i8* %name, i32 %len_int_func)
    %is_match_func = icmp eq i32 %cmp_result_func, 0
    br i1 %is_match_func, label %found_func, label %next_func
    
found_func:
    ; Debug: Function found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_function_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get (func_value . func_type) from pair.cdr
    %pair_cdr_ptr_func = getelementptr %ASTNode, %ASTNode* %pair_func, i32 0, i32 5
    %value_type_pair = load %ASTNode*, %ASTNode** %pair_cdr_ptr_func
    %value_type_pair_null = icmp eq %ASTNode* %value_type_pair, null
    br i1 %value_type_pair_null, label %not_found_func, label %extract_func_value
    
extract_func_value:
    ; Get func_value from value_type_pair.car
    %value_type_car_ptr = getelementptr %ASTNode, %ASTNode* %value_type_pair, i32 0, i32 4
    %func_value_node = load %ASTNode*, %ASTNode** %value_type_car_ptr
    %func_value_node_null = icmp eq %ASTNode* %func_value_node, null
    br i1 %func_value_node_null, label %not_found_func, label %extract_func_type
    
extract_func_type:
    ; Get func_type from value_type_pair.cdr
    %value_type_cdr_ptr = getelementptr %ASTNode, %ASTNode* %value_type_pair, i32 0, i32 5
    %func_type_node = load %ASTNode*, %ASTNode** %value_type_cdr_ptr
    %func_type_node_null = icmp eq %ASTNode* %func_type_node, null
    br i1 %func_type_node_null, label %not_found_func, label %verify_and_extract
    
verify_and_extract:
    ; Verify both are pointer nodes (atom_type 999)
    %func_value_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %func_value_node, i32 0, i32 1
    %func_value_atom_type = load i32, i32* %func_value_atom_type_ptr
    %func_type_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %func_type_node, i32 0, i32 1
    %func_type_atom_type = load i32, i32* %func_type_atom_type_ptr
    %both_are_pointers = and i1 true, true  ; Always true, but we'll check atom types
    %func_value_is_ptr = icmp eq i32 %func_value_atom_type, 999
    %func_type_is_ptr = icmp eq i32 %func_type_atom_type, 999
    %both_pointers = and i1 %func_value_is_ptr, %func_type_is_ptr
    br i1 %both_pointers, label %cast_back_func, label %not_found_func
    
cast_back_func:
    ; Extract func_value
    %func_value_ptr_field = getelementptr %ASTNode, %ASTNode* %func_value_node, i32 0, i32 2
    %func_value_ptr = load i8*, i8** %func_value_ptr_field
    %func_value_ref = bitcast i8* %func_value_ptr to %LLVMValueRef
    
    ; Extract func_type
    %func_type_ptr_field = getelementptr %ASTNode, %ASTNode* %func_type_node, i32 0, i32 2
    %func_type_ptr = load i8*, i8** %func_type_ptr_field
    %func_type_ref = bitcast i8* %func_type_ptr to %LLVMTypeRef
    
    ; Store in output parameters
    store %LLVMValueRef %func_value_ref, %LLVMValueRef* %func_value_out
    store %LLVMTypeRef %func_type_ref, %LLVMTypeRef* %func_type_out
    
    ret i32 1
    
next_func:
    ; Move to next in list
    %cdr_ptr_func = getelementptr %ASTNode, %ASTNode* %current_val_func, i32 0, i32 5
    %cdr_func = load %ASTNode*, %ASTNode** %cdr_ptr_func
    store %ASTNode* %cdr_func, %ASTNode** %current_func
    br label %iterate_func
    
not_found_func:
    ; Debug: Function not found after searching
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_function_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret i32 0
}

; Handle define-bitcode-function AST node (renamed from define-bitcode)
; codegen_define_bitcode_function: Generate LLVM function definition with types
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-bitcode-function form
; Returns: 0 on success, -1 on error
; Syntax: (define-bitcode-function (name (param1 type1) (param2 type2) ...) return-type "LLVM IR body")
; TODO: Future version will use llvm_create_function_type() and llvm_add_function() via FFI instead of text IR
define i32 @codegen_define_bitcode_function(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; AST structure: LIST { ATOM: "define-bitcode-function", LIST: signature, ATOM: return-type, STRING: body }
    ; Get signature list (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %sig_list_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %sig_list = load %ASTNode*, %ASTNode** %sig_list_node_ptr
    
    ; Extract function name (first element of signature list)
    %sig_car_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 4
    %func_name_node = load %ASTNode*, %ASTNode** %sig_car_ptr
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
    ; Get parameters with types (rest of signature list)
    %sig_cdr_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 5
    %params_list = load %ASTNode*, %ASTNode** %sig_cdr_ptr
    
    ; Get return type (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %return_type_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %return_type_node = load %ASTNode*, %ASTNode** %return_type_node_ptr
    %return_type_val_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 2
    %return_type = load i8*, i8** %return_type_val_ptr
    %return_type_len_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 3
    %return_type_len = load i64, i64* %return_type_len_ptr
    
    ; Get IR body (fourth element - string)
    %cdr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 5
    %cdr_cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_cdr_ptr
    %ir_body_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 4
    %ir_body_node = load %ASTNode*, %ASTNode** %ir_body_node_ptr
    %ir_body_val_ptr = getelementptr %ASTNode, %ASTNode* %ir_body_node, i32 0, i32 2
    %ir_body = load i8*, i8** %ir_body_val_ptr
    %ir_body_len_ptr = getelementptr %ASTNode, %ASTNode* %ir_body_node, i32 0, i32 3
    %ir_body_len = load i64, i64* %ir_body_len_ptr
    
    ; Build complete function definition as IR text for parsing
    ; We'll build it in a temporary buffer, parse it, then also generate text IR
    ; Estimate buffer size: signature (~100 bytes) + body + closing (~10 bytes)
    %estimated_sig_size = add i64 100, %func_name_len
    %estimated_sig_size2 = add i64 %estimated_sig_size, %return_type_len
    %func_def_size = add i64 %estimated_sig_size2, %ir_body_len
    %func_def_size2 = add i64 %func_def_size, 20  ; padding for signature parts
    %func_def_buf = call i8* @malloc(i64 %func_def_size2)
    
    ; Build function definition string
    ; Format: "define return-type @name(type1 %param1, ...) {\n[body]\n}\n"
    %pos = alloca i64
    store i64 0, i64* %pos
    
    ; Write "define "
    %pos_val1 = load i64, i64* %pos
    %dest1 = getelementptr i8, i8* %func_def_buf, i64 %pos_val1
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest1, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.define, i32 0, i32 0), i64 7, i1 false)
    %pos_val2 = add i64 %pos_val1, 7
    store i64 %pos_val2, i64* %pos
    
    ; Write return type
    %pos_val3 = load i64, i64* %pos
    %dest2 = getelementptr i8, i8* %func_def_buf, i64 %pos_val3
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest2, i8* %return_type, i64 %return_type_len, i1 false)
    %pos_val4 = add i64 %pos_val3, %return_type_len
    store i64 %pos_val4, i64* %pos
    
    ; Write " @"
    %pos_val5 = load i64, i64* %pos
    %dest3 = getelementptr i8, i8* %func_def_buf, i64 %pos_val5
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest3, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.space_at, i32 0, i32 0), i64 2, i1 false)
    %pos_val6 = add i64 %pos_val5, 2
    store i64 %pos_val6, i64* %pos
    
    ; Write function name
    %pos_val7 = load i64, i64* %pos
    %dest4 = getelementptr i8, i8* %func_def_buf, i64 %pos_val7
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest4, i8* %func_name, i64 %func_name_len, i1 false)
    %pos_val8 = add i64 %pos_val7, %func_name_len
    store i64 %pos_val8, i64* %pos
    
    ; Write "("
    %pos_val9 = load i64, i64* %pos
    %dest5 = getelementptr i8, i8* %func_def_buf, i64 %pos_val9
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest5, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i32 0, i32 0), i64 1, i1 false)
    %pos_val10 = add i64 %pos_val9, 1
    store i64 %pos_val10, i64* %pos
    
    ; Write parameters to buffer
    call void @codegen_write_typed_params_to_buffer(i8* %func_def_buf, i64* %pos, %ASTNode* %params_list)
    
    ; Write ") {\n"
    %pos_val11 = load i64, i64* %pos
    %dest6 = getelementptr i8, i8* %func_def_buf, i64 %pos_val11
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest6, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.rparen_brace, i32 0, i32 0), i64 3, i1 false)
    %pos_val12 = add i64 %pos_val11, 3
    store i64 %pos_val12, i64* %pos
    
    ; Write IR body
    %pos_val13 = load i64, i64* %pos
    %dest7 = getelementptr i8, i8* %func_def_buf, i64 %pos_val13
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest7, i8* %ir_body, i64 %ir_body_len, i1 false)
    %pos_val14 = add i64 %pos_val13, %ir_body_len
    store i64 %pos_val14, i64* %pos
    
    ; Write "\n}\n"
    %pos_val15 = load i64, i64* %pos
    %dest8 = getelementptr i8, i8* %func_def_buf, i64 %pos_val15
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest8, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.newline_close_brace, i32 0, i32 0), i64 3, i1 false)
    %pos_val16 = add i64 %pos_val15, 3
    store i64 %pos_val16, i64* %pos
    
    ; Null terminate
    %pos_val17 = load i64, i64* %pos
    %null_ptr = getelementptr i8, i8* %func_def_buf, i64 %pos_val17
    store i8 0, i8* %null_ptr
    br label %do_parse
    
do_parse:
    ; Parse function IR into module
    %parse_result = call i32 @codegen_parse_function_ir(%CodeGen* %cg, i8* %func_def_buf, i64 %pos_val17)
    
    ; Free buffer (always free, regardless of parse result)
    call void @free(i8* %func_def_buf)
    
    ; Check parse result and return
    %parse_failed = icmp ne i32 %parse_result, 0
    br i1 %parse_failed, label %error, label %success

success:
    ret i32 0

error:
    ret i32 -1
}

; Append typed parameter list
; codegen_append_typed_params: Append typed parameter list to function signature
; Parameters:
;   cg: Pointer to CodeGen structure
;   params: AST node list of (param-name type) pairs
define void @codegen_append_typed_params(%CodeGen* %cg, %ASTNode* %params) {
entry:
    %is_null = icmp eq %ASTNode* %params, null
    br i1 %is_null, label %done, label %append_first
    
append_first:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %params, i32 0, i32 4
    %param_pair = load %ASTNode*, %ASTNode** %car_ptr
    
    ; param_pair is a list: (param-name type)
    %param_car_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 4
    %param_name_node = load %ASTNode*, %ASTNode** %param_car_ptr
    %param_name_val_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 2
    %param_name = load i8*, i8** %param_name_val_ptr
    %param_name_len_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 3
    %param_name_len = load i64, i64* %param_name_len_ptr
    
    %param_cdr_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 5
    %param_cdr = load %ASTNode*, %ASTNode** %param_cdr_ptr
    %param_type_node_ptr = getelementptr %ASTNode, %ASTNode* %param_cdr, i32 0, i32 4
    %param_type_node = load %ASTNode*, %ASTNode** %param_type_node_ptr
    %param_type_val_ptr = getelementptr %ASTNode, %ASTNode* %param_type_node, i32 0, i32 2
    %param_type = load i8*, i8** %param_type_val_ptr
    %param_type_len_ptr = getelementptr %ASTNode, %ASTNode* %param_type_node, i32 0, i32 3
    %param_type_len = load i64, i64* %param_type_len_ptr
    
    ; Append: type %param_name
    call void @codegen_append(%CodeGen* %cg, i8* %param_type, i64 %param_type_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.percent, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %param_name, i64 %param_name_len)
    
    ; Check for more parameters
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %params, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    %has_more = icmp ne %ASTNode* %next, null
    br i1 %has_more, label %append_more, label %done
    
append_more:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.comma_space, i32 0, i32 0), i64 2)
    call void @codegen_append_typed_params(%CodeGen* %cg, %ASTNode* %next)
    br label %done
    
done:
    ret void
}

; Write typed parameter list to buffer
; codegen_write_typed_params_to_buffer: Write typed parameter list to buffer
; Parameters:
;   buf: Buffer pointer
;   pos: Pointer to current position in buffer (will be updated)
;   params: AST node list of (param-name type) pairs
define void @codegen_write_typed_params_to_buffer(i8* %buf, i64* %pos, %ASTNode* %params) {
entry:
    %is_null = icmp eq %ASTNode* %params, null
    br i1 %is_null, label %done, label %write_first
    
write_first:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %params, i32 0, i32 4
    %param_pair = load %ASTNode*, %ASTNode** %car_ptr
    
    ; param_pair is a list: (param-name type)
    %param_car_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 4
    %param_name_node = load %ASTNode*, %ASTNode** %param_car_ptr
    %param_name_val_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 2
    %param_name = load i8*, i8** %param_name_val_ptr
    %param_name_len_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 3
    %param_name_len = load i64, i64* %param_name_len_ptr
    
    %param_cdr_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 5
    %param_cdr = load %ASTNode*, %ASTNode** %param_cdr_ptr
    %param_type_node_ptr = getelementptr %ASTNode, %ASTNode* %param_cdr, i32 0, i32 4
    %param_type_node = load %ASTNode*, %ASTNode** %param_type_node_ptr
    %param_type_val_ptr = getelementptr %ASTNode, %ASTNode* %param_type_node, i32 0, i32 2
    %param_type = load i8*, i8** %param_type_val_ptr
    %param_type_len_ptr = getelementptr %ASTNode, %ASTNode* %param_type_node, i32 0, i32 3
    %param_type_len = load i64, i64* %param_type_len_ptr
    
    ; Write: type %param_name
    %pos_val1 = load i64, i64* %pos
    %dest1 = getelementptr i8, i8* %buf, i64 %pos_val1
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest1, i8* %param_type, i64 %param_type_len, i1 false)
    %pos_val2 = add i64 %pos_val1, %param_type_len
    store i64 %pos_val2, i64* %pos
    
    ; Write space
    %pos_val3 = load i64, i64* %pos
    %dest2 = getelementptr i8, i8* %buf, i64 %pos_val3
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest2, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1, i1 false)
    %pos_val4 = add i64 %pos_val3, 1
    store i64 %pos_val4, i64* %pos
    
    ; Write %
    %pos_val5 = load i64, i64* %pos
    %dest3 = getelementptr i8, i8* %buf, i64 %pos_val5
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest3, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.percent, i32 0, i32 0), i64 1, i1 false)
    %pos_val6 = add i64 %pos_val5, 1
    store i64 %pos_val6, i64* %pos
    
    ; Write param name
    %pos_val7 = load i64, i64* %pos
    %dest4 = getelementptr i8, i8* %buf, i64 %pos_val7
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest4, i8* %param_name, i64 %param_name_len, i1 false)
    %pos_val8 = add i64 %pos_val7, %param_name_len
    store i64 %pos_val8, i64* %pos
    
    ; Check for more parameters
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %params, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    %has_more = icmp ne %ASTNode* %next, null
    br i1 %has_more, label %write_more, label %done
    
write_more:
    ; Write ", "
    %pos_val9 = load i64, i64* %pos
    %dest5 = getelementptr i8, i8* %buf, i64 %pos_val9
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest5, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.comma_space, i32 0, i32 0), i64 2, i1 false)
    %pos_val10 = add i64 %pos_val9, 2
    store i64 %pos_val10, i64* %pos
    
    ; Recursively write remaining parameters
    call void @codegen_write_typed_params_to_buffer(i8* %buf, i64* %pos, %ASTNode* %next)
    br label %done
    
done:
    ret void
}

; Handle define-bitcode AST node (legacy - kept for backward compatibility)
; codegen_define_bitcode: Generate LLVM function definition from define-bitcode
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-bitcode form
; Returns: 0 on success, -1 on error
define i32 @codegen_define_bitcode(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; AST structure for define-bitcode:
    ; LIST {
    ;   ATOM: "define-bitcode"
    ;   LIST: { function_name, param1, param2, ... }
    ;   STRING: "LLVM IR body"
    ; }
    
    %car_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 4
    %car = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Verify first element is "define-bitcode"
    %car_type_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 0
    %car_type = load i32, i32* %car_type_ptr
    %is_atom = icmp eq i32 %car_type, 0  ; AST_ATOM
    br i1 %is_atom, label %check_name, label %error

check_name:
    ; Get function signature (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %cdr_car_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %sig_list = load %ASTNode*, %ASTNode** %cdr_car_ptr
    
    ; Extract function name (first element of signature list)
    %sig_car_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 4
    %func_name_node = load %ASTNode*, %ASTNode** %sig_car_ptr
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    
    ; Get IR body (third element - string)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %cdr_cdr_car_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %ir_body_node = load %ASTNode*, %ASTNode** %cdr_cdr_car_ptr
    %ir_body_val_ptr = getelementptr %ASTNode, %ASTNode* %ir_body_node, i32 0, i32 2
    %ir_body = load i8*, i8** %ir_body_val_ptr
    %ir_body_len_ptr = getelementptr %ASTNode, %ASTNode* %ir_body_node, i32 0, i32 3
    %ir_body_len = load i64, i64* %ir_body_len_ptr
    
    ; Extract parameters from signature list
    %sig_cdr_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 5
    %params_list = load %ASTNode*, %ASTNode** %sig_cdr_ptr
    
    ; Generate function signature: define void @name(i8* %param1, ...)
    ; For now, assume all parameters are i8* (strings)
    call void @codegen_append_function_def(%CodeGen* %cg, i8* %func_name, %ASTNode* %params_list, i8* %ir_body, i64 %ir_body_len)
    
    ret i32 0

error:
    ret i32 -1
}

; Append function definition to IR
; codegen_append_function_def: Append a function definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Function name
;   params: AST node list of parameters
;   body: IR body string
;   body_len: IR body length
define void @codegen_append_function_def(%CodeGen* %cg, i8* %name, %ASTNode* %params, i8* %body, i64 %body_len) {
entry:
    ; Generate: define void @name(i8* %param1, ...) {
    ;   [body]
    ; }
    
    ; Start function definition
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.define_void, i32 0, i32 0), i64 11)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    %name_len_call = call i64 @strlen(i8* %name)
    call void @codegen_append(%CodeGen* %cg, i8* %name, i64 %name_len_call)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i32 0, i32 0), i64 1)
    
    ; Generate parameters (simplified - assume all i8*)
    call void @codegen_append_params(%CodeGen* %cg, %ASTNode* %params)
    
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.rparen_brace, i32 0, i32 0), i64 3)
    
    ; Append IR body
    call void @codegen_append(%CodeGen* %cg, i8* %body, i64 %body_len)
    
    ; Close function
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.close_brace, i32 0, i32 0), i64 1)
    
    ret void
}

; Append parameter list
; codegen_append_params: Append parameter list to function signature
; Parameters:
;   cg: Pointer to CodeGen structure
;   params: AST node list of parameters
define void @codegen_append_params(%CodeGen* %cg, %ASTNode* %params) {
entry:
    %is_null = icmp eq %ASTNode* %params, null
    br i1 %is_null, label %done, label %append_first

append_first:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %params, i32 0, i32 4
    %param_node = load %ASTNode*, %ASTNode** %car_ptr
    %param_val_ptr = getelementptr %ASTNode, %ASTNode* %param_node, i32 0, i32 2
    %param_name = load i8*, i8** %param_val_ptr
    %param_name_len_ptr = getelementptr %ASTNode, %ASTNode* %param_node, i32 0, i32 3
    %param_name_len = load i64, i64* %param_name_len_ptr
    
    ; Append: i8* %param_name
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.i8_ptr, i32 0, i32 0), i64 3)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.percent, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %param_name, i64 %param_name_len)
    
    ; Check for more parameters
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %params, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    %has_more = icmp ne %ASTNode* %next, null
    br i1 %has_more, label %append_more, label %done

append_more:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.comma_space, i32 0, i32 0), i64 2)
    call void @codegen_append_params(%CodeGen* %cg, %ASTNode* %next)
    br label %done

done:
    ret void
}

; Generate function call
; codegen_call: Generate a function call
; Parameters:
;   cg: Pointer to CodeGen structure
;   func_name: Function name
;   args: AST node list of arguments
; Returns: 0 on success, -1 on error
define i32 @codegen_call(%CodeGen* %cg, i8* %func_name, %ASTNode* %args) {
entry:
    ; Get LLVM module and builder
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    ; Check if we can use LLVM API (both module and builder must be non-null)
    %module_null = icmp eq %LLVMModuleRef %module, null
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    %either_null = or i1 %module_null, %builder_null
    br i1 %either_null, label %text_only, label %use_llvm_api
    
use_llvm_api:
    br label %lookup_func
    
lookup_func:
    ; Get function name length
    %func_name_len = call i64 @strlen(i8* %func_name)
    
    ; First check if this is a define-llvm-function function
    %func_value_storage = alloca %LLVMValueRef
    %func_type_storage = alloca %LLVMTypeRef
    %found_tracked = call i32 @codegen_get_llvm_function(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMValueRef* %func_value_storage, %LLVMTypeRef* %func_type_storage)
    %is_tracked = icmp ne i32 %found_tracked, 0
    br i1 %is_tracked, label %use_tracked_func, label %lookup_in_module
    
use_tracked_func:
    ; Use tracked function value and type
    %tracked_func = load %LLVMValueRef, %LLVMValueRef* %func_value_storage
    %tracked_func_type = load %LLVMTypeRef, %LLVMTypeRef* %func_type_storage
    br label %build_call_with_type
    
lookup_in_module:
    ; Look up function in module (for legacy functions)
    ; Note: Function names in LLVM are stored without @ prefix
    %func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %func_name)
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error_not_found, label %get_func_type_legacy
    
get_func_type_legacy:
    ; For legacy functions, get the function type from the function value
    ; llvm_type_of returns the pointer type, so we need to get the element type
    %func_ptr_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    %func_type_legacy = call %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %func_ptr_type)
    br label %build_call_with_type
    
build_call_with_type:
    %func_phi = phi %LLVMValueRef [ %tracked_func, %use_tracked_func ], [ %func, %get_func_type_legacy ]
    %func_type_phi = phi %LLVMTypeRef [ %tracked_func_type, %use_tracked_func ], [ %func_type_legacy, %get_func_type_legacy ]
    br label %build_call

error_not_found:
    ; Function not found in module - return error
    br label %return_error
    
return_error:
    ; TODO: This should not happen if functions are properly linked
    ret i32 -1
    
build_call:
    ; Use func_phi and func_type_phi from build_call_with_type
    ; Get context for types
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    ; For printf and other functions, we now have the function type from func_type_phi
    ; Get i32 and i8* types for argument conversion
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type, i32 0)
    
    ; Count arguments and build argument array
    ; For now, assume printf with one string argument
    ; Allocate space for one argument
    %arg_array = alloca %LLVMValueRef, i32 1
    
    ; Build argument: getelementptr to string constant
    ; First, we need to get the string constant from args
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %call_with_no_args, label %get_first_arg
    
get_first_arg:
    %arg_car_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %arg_node = load %ASTNode*, %ASTNode** %arg_car_ptr
    
    ; Check if argument is a string literal
    %arg_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 0
    %arg_type = load i32, i32* %arg_type_ptr
    %is_atom = icmp eq i32 %arg_type, 0  ; AST_ATOM
    br i1 %is_atom, label %check_string_type, label %call_with_no_args
    
check_string_type:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    %is_string = icmp eq i32 %atom_type, 3  ; TOKEN_STRING
    br i1 %is_string, label %build_string_arg, label %call_with_no_args
    
build_string_arg:
    ; Get string value and length
    %str_val_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 2
    %str_val = load i8*, i8** %str_val_ptr
    %str_len_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 3
    %str_len = load i64, i64* %str_len_ptr
    
    ; Get the string constant name (should already be generated)
    %const_name = call i8* @codegen_get_string_constant_name(%CodeGen* %cg, i8* %str_val, i64 %str_len)
    
    ; Look up the global constant
    %global = call %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef %module, i8* %const_name)
    %global_null = icmp eq %LLVMValueRef %global, null
    br i1 %global_null, label %call_with_no_args, label %build_gep
    
build_gep:
    ; Build getelementptr: getelementptr ([len x i8], [len x i8]* @.str.N, i32 0, i32 0)
    %len_plus_one = add i64 %str_len, 1
    %len_plus_one_int = trunc i64 %len_plus_one to i32
    %array_type = call %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %i8_type, i32 %len_plus_one_int)
    
    ; Create indices: [0, 0]
    %indices = alloca %LLVMValueRef, i32 2
    %zero_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type, i64 0, i32 0)
    %zero_idx = getelementptr %LLVMValueRef, %LLVMValueRef* %indices, i32 0
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx
    %zero_idx2 = getelementptr %LLVMValueRef, %LLVMValueRef* %indices, i32 1
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx2
    
    ; Build GEP instruction
    ; Use empty string instead of null for name (LLVMBuildGEP2 may not handle null properly)
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %gep = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %array_type, %LLVMValueRef %global, %LLVMValueRef* %indices, i32 2, i8* %empty_str)
    
    ; Validate GEP result
    %gep_null = icmp eq %LLVMValueRef %gep, null
    br i1 %gep_null, label %call_with_no_args, label %store_gep
    
store_gep:
    ; Store in argument array
    store %LLVMValueRef %gep, %LLVMValueRef* %arg_array
    br label %call_func
    
call_with_no_args:
    ; No arguments - but still need a valid pointer (even if empty)
    ; Use the arg_array which is already allocated (it's safe to pass even with count 0)
    br label %call_func
    
call_func:
    ; PHI nodes must be first in the block
    %args_count = phi i32 [ 1, %store_gep ], [ 0, %call_with_no_args ]
    %args_ptr = phi %LLVMValueRef* [ %arg_array, %store_gep ], [ %arg_array, %call_with_no_args ]
    
    ; Use func_type_phi from build_call_with_type (already has the correct function type)
    %func_type_null_check = icmp eq %LLVMTypeRef %func_type_phi, null
    br i1 %func_type_null_check, label %text_only, label %build_call_inst
    
build_call_inst:
    ; Build call instruction using func_type_phi and func_phi
    ; Use empty string instead of null for name (LLVMBuildCall2 may not handle null properly)
    %empty_str_call = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %call_result = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type_phi, %LLVMValueRef %func_phi, %LLVMValueRef* %args_ptr, i32 %args_count, i8* %empty_str_call)
    br label %done
    
text_only:
    ; Generate: call void @func_name(args...)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.call_void, i32 0, i32 0), i64 9)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    %func_name_len_text = call i64 @strlen(i8* %func_name)
    call void @codegen_append(%CodeGen* %cg, i8* %func_name, i64 %func_name_len_text)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i32 0, i32 0), i64 1)
    
    ; Generate arguments
    call void @codegen_append_call_args(%CodeGen* %cg, %ASTNode* %args)
    
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rparen, i32 0, i32 0), i64 1)
    br label %done
    
done:
    ret i32 0
}


; Helper: Generate string constant definition only (without reference)
; codegen_define_string_constant_only: Generate string constant definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   str: String value
;   len: String length
; Returns: Constant name (as string pointer)
define i8* @codegen_define_string_constant_only(%CodeGen* %cg, i8* %str, i64 %len) {
entry:
    ; Get unique constant name
    %counter_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 3
    %counter = load i32, i32* %counter_ptr
    %new_counter = add i32 %counter, 1
    store i32 %new_counter, i32* %counter_ptr
    
    ; Generate constant name
    %name = call i8* @codegen_format_string_name(i32 %counter)
    
    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    ; Create string constant using LLVM API if available
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %can_use_llvm = or i1 %context_null, %module_null
    %can_use_llvm_not = xor i1 %can_use_llvm, -1
    br i1 %can_use_llvm_not, label %create_llvm_constant, label %text_only
    
create_llvm_constant:
    ; Get i8 type
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    
    ; Create array type [len+1 x i8] (including null terminator)
    %len_plus_one = add i64 %len, 1
    %len_plus_one_int = trunc i64 %len_plus_one to i32
    %array_type = call %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %i8_type, i32 %len_plus_one_int)
    
    ; Create string constant (with null terminator)
    %str_len_int = trunc i64 %len to i32
    %const_str = call %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef %context, i8* %str, i32 %str_len_int, i32 0)
    
    ; Add as global variable with the constant name
    %global = call %LLVMValueRef @llvm_add_global(%LLVMModuleRef %module, %LLVMTypeRef %array_type, i8* %name)
    
    ; Set initializer
    call void @llvm_set_initializer(%LLVMValueRef %global, %LLVMValueRef %const_str)
    
    ; Set as constant
    call void @llvm_set_global_constant(%LLVMValueRef %global, i32 1)
    
    ; Set linkage to private (equivalent to "private" in text IR)
    ; LLVMLinkage enum: LLVMPrivateLinkage = 0
    call void @llvm_set_linkage(%LLVMValueRef %global, i32 0)
    
    br label %text_only
    
text_only:
    ; Generate IR: @.str_N = private constant [L x i8] c"...\00"
    call void @codegen_append_string_constant(%CodeGen* %cg, i8* %name, i8* %str, i64 %len)
    
    ret i8* %name
}

; Helper: Get string constant name without generating definition
; codegen_get_string_constant_name: Get constant name for a string (assumes constant already exists)
; Parameters:
;   cg: Pointer to CodeGen structure
;   str: String value
;   len: String length
; Returns: Constant name (as string pointer)
; NOTE: This assumes the constant was already generated. Since constants are generated
; before function calls, and we're calling this during function call generation, the
; constant was generated with counter value (current_counter - 1). We use that to get the name.
; For bootstrap, this is sufficient. A more robust implementation would track
; string-to-constant-name mappings.
define i8* @codegen_get_string_constant_name(%CodeGen* %cg, i8* %str, i64 %len) {
entry:
    ; Get current counter
    %counter_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 3
    %counter = load i32, i32* %counter_ptr
    
    ; The constant was generated with counter value (counter - 1) since we're
    ; calling this after constants have been generated. Use that value.
    %prev_counter = sub i32 %counter, 1
    
    ; Generate name using the counter value that was used when the constant was generated
    %name = call i8* @codegen_format_string_name(i32 %prev_counter)
    
    ret i8* %name
}

; Append call arguments
; codegen_append_call_args: Append arguments to function call
; Parameters:
;   cg: Pointer to CodeGen structure
;   args: AST node list of arguments
define void @codegen_append_call_args(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %is_null = icmp eq %ASTNode* %args, null
    br i1 %is_null, label %done, label %append_first

append_first:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %arg_node = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Check if argument is a string literal
    %arg_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 0
    %arg_type = load i32, i32* %arg_type_ptr
    %is_atom = icmp eq i32 %arg_type, 0  ; AST_ATOM
    
    br i1 %is_atom, label %check_string, label %done

check_string:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    %is_string = icmp eq i32 %atom_type, 3  ; TOKEN_STRING
    
    br i1 %is_string, label %gen_string_arg, label %done

gen_string_arg:
    ; Extract string value
    %str_val_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 2
    %str_val = load i8*, i8** %str_val_ptr
    %str_len_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 3
    %str_len = load i64, i64* %str_len_ptr
    
    ; Get constant name (constants should already be defined by codegen_collect_string_constants)
    ; We need to find the constant name that was generated for this string.
    ; For bootstrap simplicity, we'll regenerate the name using the same algorithm.
    ; In a more sophisticated implementation, we'd track which constants map to which strings.
    ; For now, we'll use a helper that generates the name without creating the constant.
    %const_name = call i8* @codegen_get_string_constant_name(%CodeGen* %cg, i8* %str_val, i64 %str_len)
    
    ; Generate: i8* getelementptr ([L x i8], [L x i8]* @.str_N, i32 0, i32 0)
    ; First append the result type
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.i8_ptr, i32 0, i32 0), i64 3)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    
    ; Then append getelementptr instruction with opening parenthesis and bracket
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.getelementptr_open, i32 0, i32 0), i64 14)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lbracket, i32 0, i32 0), i64 1)
    
    ; Append length (including null terminator)
    %len_plus_one = add i64 %str_len, 1
    %len_str = call i8* @codegen_format_number(i64 %len_plus_one)
    %len_str_len = call i64 @strlen(i8* %len_str)
    call void @codegen_append(%CodeGen* %cg, i8* %len_str, i64 %len_str_len)
    
    ; Append " x i8], ["
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.x_i8_bracket_comma, i32 0, i32 0), i64 9)
    
    ; Append length again (including null terminator)
    call void @codegen_append(%CodeGen* %cg, i8* %len_str, i64 %len_str_len)
    
    ; Append " x i8]* @"
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.x_i8_ptr_at, i32 0, i32 0), i64 9)
    
    ; Append constant name (const_name is like ".str.0", we need "@.str.0" for the reference)
    %name_len = call i64 @strlen(i8* %const_name)
    call void @codegen_append(%CodeGen* %cg, i8* %const_name, i64 %name_len)
    
    ; Append ", i32 0, i32 0)"
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.getelementptr_indices, i32 0, i32 0), i64 14)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rparen, i32 0, i32 0), i64 1)
    
    ; Check for more arguments
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    %has_more = icmp ne %ASTNode* %next, null
    br i1 %has_more, label %append_more, label %done

append_more:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.comma_space, i32 0, i32 0), i64 2)
    call void @codegen_append_call_args(%CodeGen* %cg, %ASTNode* %next)
    br label %done

done:
    ret void
}

; Collect string constants from expressions
; codegen_collect_string_constants: Collect and generate string constants from expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   exprs: AST node list of expressions
define void @codegen_collect_string_constants(%CodeGen* %cg, %ASTNode* %exprs) {
entry:
    %is_null = icmp eq %ASTNode* %exprs, null
    br i1 %is_null, label %done, label %process_expr

process_expr:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %exprs, i32 0, i32 4
    %expr = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Check if this is a function call (list starting with identifier)
    %expr_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 0
    %expr_type = load i32, i32* %expr_type_ptr
    %is_list = icmp eq i32 %expr_type, 1  ; AST_LIST
    
    br i1 %is_list, label %check_call, label %next_expr

check_call:
    ; Extract arguments and collect string constants from them
    %expr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 5
    %args = load %ASTNode*, %ASTNode** %expr_cdr_ptr
    call void @codegen_collect_string_constants_from_args(%CodeGen* %cg, %ASTNode* %args)
    br label %next_expr

next_expr:
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %exprs, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    call void @codegen_collect_string_constants(%CodeGen* %cg, %ASTNode* %next)
    br label %done

done:
    ret void
}

; Collect string constants from function call arguments
; codegen_collect_string_constants_from_args: Collect string constants from arguments
; Parameters:
;   cg: Pointer to CodeGen structure
;   args: AST node list of arguments
define void @codegen_collect_string_constants_from_args(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %is_null = icmp eq %ASTNode* %args, null
    br i1 %is_null, label %done, label %check_arg

check_arg:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %arg_node = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Check if argument is a string literal
    %arg_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 0
    %arg_type = load i32, i32* %arg_type_ptr
    %is_atom = icmp eq i32 %arg_type, 0  ; AST_ATOM
    
    br i1 %is_atom, label %check_string, label %next_arg

check_string:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    %is_string = icmp eq i32 %atom_type, 3  ; TOKEN_STRING
    
    br i1 %is_string, label %gen_constant, label %next_arg

gen_constant:
    ; Generate string constant at module level
    %str_val_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 2
    %str_val = load i8*, i8** %str_val_ptr
    %str_len_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 3
    %str_len = load i64, i64* %str_len_ptr
    
    ; Generate constant definition (this will be at module level, before main)
    call i8* @codegen_define_string_constant_only(%CodeGen* %cg, i8* %str_val, i64 %str_len)
    br label %next_arg

next_arg:
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    call void @codegen_collect_string_constants_from_args(%CodeGen* %cg, %ASTNode* %next)
    br label %done

done:
    ret void
}

; Generate main function
; codegen_main: Generate main function with top-level expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   exprs: AST node list of top-level expressions
; Returns: 0 on success, -1 on error
; Note: If exprs is null/empty (only definitions, no executable expressions),
;       no main function is generated (library module).
define i32 @codegen_main(%CodeGen* %cg, %ASTNode* %exprs) {
entry:
    ; Check if there are any executable expressions
    ; If exprs is null, this is a library module (only definitions) - skip main
    %exprs_null = icmp eq %ASTNode* %exprs, null
    br i1 %exprs_null, label %done_no_main, label %check_empty
    
check_empty:
    ; Check if exprs is an empty list (list node with null car)
    %exprs_type_ptr = getelementptr %ASTNode, %ASTNode* %exprs, i32 0, i32 0
    %exprs_type = load i32, i32* %exprs_type_ptr
    %is_list = icmp eq i32 %exprs_type, 1  ; AST_LIST
    br i1 %is_list, label %check_car, label %has_exprs
    
check_car:
    ; Check if car is null (empty list)
    %exprs_car_ptr = getelementptr %ASTNode, %ASTNode* %exprs, i32 0, i32 4
    %exprs_car = load %ASTNode*, %ASTNode** %exprs_car_ptr
    %car_null = icmp eq %ASTNode* %exprs_car, null
    br i1 %car_null, label %done_no_main, label %has_exprs
    
has_exprs:
    ; First, collect and generate all string constants at module level
    ; This ensures constants are defined before functions
    call void @codegen_collect_string_constants(%CodeGen* %cg, %ASTNode* %exprs)
    
    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %either_null = or i1 %context_null, %module_null
    br i1 %either_null, label %text_only, label %create_main_llvm
    
create_main_llvm:
    ; Get i32 type for return type
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    %i32_type_null = icmp eq %LLVMTypeRef %i32_type, null
    br i1 %i32_type_null, label %text_only, label %create_func_type
    
create_func_type:
    ; Create function type: i32 () - no parameters
    ; Pass null for param_types when there are no parameters
    %main_func_type = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %i32_type, %LLVMTypeRef* null, i32 0, i32 0)
    %func_type_null = icmp eq %LLVMTypeRef %main_func_type, null
    br i1 %func_type_null, label %text_only, label %check_func_type_valid
    
check_func_type_valid:
    ; Double-check function type is valid (not just non-null)
    ; For now, assume if it's non-null it's valid and proceed
    br label %add_function
    
add_function:
    ; Add main function to module
    ; Check if function already exists first (LLVMAddFunction will return existing if name matches)
    %main_name_array = bitcast [5 x i8]* @.str.main_name to i8*
    %main_func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %main_name_array, %LLVMTypeRef %main_func_type)
    %main_func_null = icmp eq %LLVMValueRef %main_func, null
    br i1 %main_func_null, label %text_only, label %verify_func
    
verify_func:
    ; Verify function is actually a function (not just a non-null pointer)
    ; LLVM doesn't provide a direct way to check this, so we'll just proceed
    ; but add extra caution
    br label %create_block
    
create_block:
    ; Create entry basic block
    ; Double-check function is still valid before appending block
    %main_func_check = icmp eq %LLVMValueRef %main_func, null
    br i1 %main_func_check, label %text_only, label %append_block
    
append_block:
    ; Try appending basic block with a name instead of null
    ; Some LLVM versions might require a non-null name
    %entry_block_name = bitcast [6 x i8]* @.str.entry_block_name to i8*
    %entry_block = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %main_func, i8* %entry_block_name)
    %block_null = icmp eq %LLVMBasicBlockRef %entry_block, null
    br i1 %block_null, label %text_only, label %create_builder
    
create_builder:
    ; Create builder
    %builder = call %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef %context)
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %text_only, label %position_builder
    
position_builder:
    ; Position builder at end of entry block
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %entry_block)
    
    ; Store builder in CodeGen structure
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    store %LLVMBuilderRef %builder, %LLVMBuilderRef* %builder_ptr
    
    ; Generate return i32 0
    %zero_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type, i64 0, i32 0)
    %zero_const_null = icmp eq %LLVMValueRef %zero_const, null
    br i1 %zero_const_null, label %text_only, label %build_ret
    
build_ret:
    ; Generate code for each top-level expression (will use builder)
    call void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %exprs)
    
    ; Generate return i32 0 (if not already generated by expressions)
    %ret_inst = call %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef %builder, %LLVMValueRef %zero_const)
    br label %done
    
text_only:
    ; Fallback to text IR generation if LLVM API unavailable
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_main, i32 0, i32 0), i64 20)
    call void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %exprs)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.ret_zero, i32 0, i32 0), i64 11)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.close_brace, i32 0, i32 0), i64 1)
    br label %done
    
done_no_main:
    ; No executable expressions - this is a library module
    ; Just collect string constants (if any) but don't generate main
    call void @codegen_collect_string_constants(%CodeGen* %cg, %ASTNode* null)
    br label %done
    
done:
    ret i32 0
}

; Append top-level expressions
; codegen_append_top_level_exprs: Generate code for top-level expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   exprs: AST node list of expressions
define void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %exprs) {
entry:
    %is_null = icmp eq %ASTNode* %exprs, null
    br i1 %is_null, label %done, label %process_expr

process_expr:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %exprs, i32 0, i32 4
    %expr = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Check if this is a function call (list starting with identifier)
    %expr_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 0
    %expr_type = load i32, i32* %expr_type_ptr
    %is_list = icmp eq i32 %expr_type, 1  ; AST_LIST
    
    br i1 %is_list, label %check_call, label %next_expr

check_call:
    %expr_car_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 4
    %first = load %ASTNode*, %ASTNode** %expr_car_ptr
    %first_type_ptr = getelementptr %ASTNode, %ASTNode* %first, i32 0, i32 0
    %first_type = load i32, i32* %first_type_ptr
    %first_is_atom = icmp eq i32 %first_type, 0  ; AST_ATOM
    
    br i1 %first_is_atom, label %gen_call, label %next_expr

gen_call:
    ; Extract function name
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %first, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    
    ; Extract arguments
    %expr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 5
    %args = load %ASTNode*, %ASTNode** %expr_cdr_ptr
    br label %do_call
    
do_call:
    ; Generate function call using LLVM API
    ; Note: We no longer generate text IR - all calls go through LLVM API
    %call_result = call i32 @codegen_call(%CodeGen* %cg, i8* %func_name, %ASTNode* %args)
    %call_failed = icmp ne i32 %call_result, 0
    br i1 %call_failed, label %call_error, label %next_expr

call_error:
    ; Function call failed - this should not happen if functions are properly defined
    ; For now, just skip this expression (in future, we should propagate the error)
    br label %next_expr
    
    br label %next_expr

next_expr:
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %exprs, i32 0, i32 5
    %next = load %ASTNode*, %ASTNode** %cdr_ptr
    call void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %next)
    br label %done

done:
    ret void
}

; Get generated IR
; codegen_get_ir: Get the generated IR string
; Parameters:
;   cg: Pointer to CodeGen structure
; Returns: IR string (null-terminated)
; NOTE: This function returns text IR. Future version will write bitcode directly.
define i8* @codegen_get_ir(%CodeGen* %cg) {
entry:
    %buffer_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 0
    %buffer = load i8*, i8** %buffer_ptr
    %pos_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    
    ; Null-terminate
    %null_ptr = getelementptr i8, i8* %buffer, i64 %pos
    store i8 0, i8* %null_ptr
    
    ret i8* %buffer
}

; Extract function name from IR text
; codegen_extract_function_name: Extract function name from function IR text
; Parameters:
;   func_ir: Function IR text (format: "define return-type @name(")
;   func_ir_len: Length of IR text
; Returns: Pointer to function name string (allocated with malloc), or null on error
; NOTE: The returned string must be freed by caller
define i8* @codegen_extract_function_name(i8* %func_ir, i64 %func_ir_len) {
entry:
    %ir_null = icmp eq i8* %func_ir, null
    %ir_len_zero = icmp eq i64 %func_ir_len, 0
    %ir_invalid = or i1 %ir_null, %ir_len_zero
    br i1 %ir_invalid, label %error, label %find_at_sign
    
find_at_sign:
    ; Find "@" symbol after "define " and return type
    ; Search for "@" starting from position 0
    %pos = alloca i64
    store i64 0, i64* %pos
    br label %search_loop
    
search_loop:
    %pos_val = load i64, i64* %pos
    %done = icmp uge i64 %pos_val, %func_ir_len
    br i1 %done, label %error, label %check_char
    
check_char:
    %char_ptr = getelementptr i8, i8* %func_ir, i64 %pos_val
    %char = load i8, i8* %char_ptr
    %char_int = zext i8 %char to i32
    %is_at = icmp eq i32 %char_int, 64  ; '@' = 64
    br i1 %is_at, label %found_at, label %increment
    
increment:
    %pos_next = add i64 %pos_val, 1
    store i64 %pos_next, i64* %pos
    br label %search_loop
    
found_at:
    ; Found "@" - now extract name until "("
    %name_start_pos = add i64 %pos_val, 1  ; Skip "@"
    %name_end_pos = alloca i64
    store i64 %name_start_pos, i64* %name_end_pos
    br label %find_paren
    
find_paren:
    %end_pos_val = load i64, i64* %name_end_pos
    %end_done = icmp uge i64 %end_pos_val, %func_ir_len
    br i1 %end_done, label %error, label %check_paren
    
check_paren:
    %paren_ptr = getelementptr i8, i8* %func_ir, i64 %end_pos_val
    %paren_char = load i8, i8* %paren_ptr
    %paren_int = zext i8 %paren_char to i32
    %is_paren = icmp eq i32 %paren_int, 40  ; '(' = 40
    br i1 %is_paren, label %extract_name, label %increment_end
    
increment_end:
    %end_pos_next = add i64 %end_pos_val, 1
    store i64 %end_pos_next, i64* %name_end_pos
    br label %find_paren
    
extract_name:
    ; Extract name from name_start_pos to name_end_pos
    %name_len = sub i64 %end_pos_val, %name_start_pos
    %name_len_zero = icmp eq i64 %name_len, 0
    br i1 %name_len_zero, label %error, label %alloc_name
    
alloc_name:
    %name_buf_size = add i64 %name_len, 1  ; +1 for null terminator
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    %name_buf_null = icmp eq i8* %name_buf, null
    br i1 %name_buf_null, label %error, label %copy_name
    
copy_name:
    %name_src = getelementptr i8, i8* %func_ir, i64 %name_start_pos
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name_src, i64 %name_len, i1 false)
    %null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %null_ptr
    ret i8* %name_buf
    
error:
    ret i8* null
}

; Note: Function cloning APIs are not available in LLVM 21 C API.
; We use module linking instead, which automatically resolves symbols between modules.

; Parse complete function definition from IR text
; codegen_parse_function_ir: Parse a complete function definition from IR text and add to module
; Parameters:
;   cg: Pointer to CodeGen structure
;   func_ir: Complete function definition as IR text (including signature and body)
;   func_ir_len: Length of IR text
; Returns: 0 on success, -1 on error
; NOTE: This wraps the function in a minimal module, parses it into a temporary module,
; extracts the function, clones it to the main module, and disposes the temp module.
; The function can reference undeclared symbols - LLVMParseIRInContext handles
; undeclared symbols gracefully, and they will be resolved when the module is linked
; to the main module where those symbols are already defined.
define i32 @codegen_parse_function_ir(%CodeGen* %cg, i8* %func_ir, i64 %func_ir_len) {
entry:
    ; Allocate temp module pointer (must be in entry block to dominate all uses)
    %temp_module_ptr = alloca %LLVMModuleRef
    ; Initialize to null
    store %LLVMModuleRef null, %LLVMModuleRef* %temp_module_ptr
    
    ; Get LLVM context
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %error, label %wrap_module
    
wrap_module:
    ; Check if IR text is valid
    %ir_text_null = icmp eq i8* %func_ir, null
    %ir_len_zero = icmp eq i64 %func_ir_len, 0
    %ir_invalid = or i1 %ir_text_null, %ir_len_zero
    br i1 %ir_invalid, label %error, label %wrap_module_valid
    
wrap_module_valid:
    ; Wrap function in minimal module IR
    ; Format: "target datalayout = \"...\"\ntarget triple = \"...\"\n\n[func_ir]\n"
    %data_layout_array = bitcast [35 x i8]* @.str.data_layout_value to i8*
    %data_layout_len = add i64 34, 0  ; length without null (e-m:o-i64:64-i128:128-n32:64-S128 = 34 chars)
    %data_layout_prefix_len = add i64 21, 0  ; "target datalayout = \"" (21 chars)
    %data_layout_suffix_len = add i64 2, 0   ; "\"\n" (2 chars)
    %data_layout_total = add i64 %data_layout_prefix_len, %data_layout_len
    %data_layout_with_suffix = add i64 %data_layout_total, %data_layout_suffix_len
    
    %target_triple_array = bitcast [18 x i8]* @.str.target_triple_value to i8*
    %target_triple_len = add i64 17, 0  ; length without null (arm64-apple-darwin = 17 chars)
    %target_triple_prefix_len = add i64 17, 0  ; "target triple = \"" (17 chars)
    %target_triple_suffix_len = add i64 3, 0   ; "\"\n\n" (3 chars)
    %target_triple_total = add i64 %target_triple_prefix_len, %target_triple_len
    %target_triple_with_suffix = add i64 %target_triple_total, %target_triple_suffix_len
    
    %total_prefix = add i64 %data_layout_with_suffix, %target_triple_with_suffix
    ; No external declarations needed - LLVMParseAssemblyInContext handles undeclared symbols
    ; Symbols will be resolved when the module is linked to the main module
    %module_ir_size = add i64 %total_prefix, %func_ir_len
    %module_ir_size2 = add i64 %module_ir_size, 1  ; null terminator
    %module_ir_buf = call i8* @malloc(i64 %module_ir_size2)
    %buf_null = icmp eq i8* %module_ir_buf, null
    br i1 %buf_null, label %error, label %build_module_ir
    
build_module_ir:
    ; Build: "target datalayout = \"...\"\ntarget triple = \"...\"\n\n[func_ir]\n"
    %pos = alloca i64
    store i64 0, i64* %pos
    
    ; Write "target datalayout = \""
    %pos_val1 = load i64, i64* %pos
    %dest1 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val1
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest1, i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.data_layout_prefix, i32 0, i32 0), i64 21, i1 false)
    %pos_val2 = add i64 %pos_val1, 21
    store i64 %pos_val2, i64* %pos
    
    ; Write data layout value
    %pos_val3 = load i64, i64* %pos
    %dest2 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val3
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest2, i8* %data_layout_array, i64 %data_layout_len, i1 false)
    %pos_val4 = add i64 %pos_val3, %data_layout_len
    store i64 %pos_val4, i64* %pos
    
    ; Write "\"\n"
    %pos_val5 = load i64, i64* %pos
    %dest3 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val5
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest3, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.data_layout_suffix, i32 0, i32 0), i64 2, i1 false)
    %pos_val6 = add i64 %pos_val5, 2
    store i64 %pos_val6, i64* %pos
    
    ; Write "target triple = \""
    %pos_val7 = load i64, i64* %pos
    %dest4 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val7
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest4, i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.target_triple_prefix, i32 0, i32 0), i64 17, i1 false)
    %pos_val8 = add i64 %pos_val7, 17
    store i64 %pos_val8, i64* %pos
    
    ; Write target triple value
    %pos_val9 = load i64, i64* %pos
    %dest5 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val9
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest5, i8* %target_triple_array, i64 %target_triple_len, i1 false)
    %pos_val10 = add i64 %pos_val9, %target_triple_len
    store i64 %pos_val10, i64* %pos
    
    ; Write "\"\n\n"
    %pos_val11 = load i64, i64* %pos
    %dest6 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val11
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest6, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.target_triple_suffix, i32 0, i32 0), i64 3, i1 false)
    %pos_val12 = add i64 %pos_val11, 3
    store i64 %pos_val12, i64* %pos
    
    ; Copy function IR (no external declarations needed - LLVMParseAssemblyInContext handles undeclared symbols)
    %pos_val13 = load i64, i64* %pos
    %func_dest = getelementptr i8, i8* %module_ir_buf, i64 %pos_val13
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_dest, i8* %func_ir, i64 %func_ir_len, i1 false)
    %pos_val14 = add i64 %pos_val13, %func_ir_len
    store i64 %pos_val14, i64* %pos
    
    ; Add final newline and null terminate
    %pos_val15 = load i64, i64* %pos
    %newline_ptr = getelementptr i8, i8* %module_ir_buf, i64 %pos_val15
    store i8 10, i8* %newline_ptr  ; '\n'
    %pos_val16 = add i64 %pos_val15, 1
    %null_ptr = getelementptr i8, i8* %module_ir_buf, i64 %pos_val16
    store i8 0, i8* %null_ptr
    
    ; Use pos_val16 as total length (includes null terminator, but we pass length without it)
    %total_len = sub i64 %pos_val16, 1
    br label %parse_module
    
parse_module:
    ; Parse into temporary module (temp_module_ptr already allocated in entry block)
    ; Note: LLVMParseIRInContext creates the module itself (it's an output parameter)
    %parse_result = call i32 @llvm_parse_ir_in_context(%LLVMContextRef %context, i8* %module_ir_buf, i64 %total_len, %LLVMModuleRef* %temp_module_ptr)
    
    ; Free buffer
    call void @free(i8* %module_ir_buf)
    br label %check_parse_result
    
check_parse_result:
    ; Check parse result
    %parse_failed = icmp ne i32 %parse_result, 0
    br i1 %parse_failed, label %parse_error_cleanup, label %check_temp_module
    
parse_error_cleanup:
    ; Parse failed - return error without trying to dispose temp module
    ; (temp module may be null or invalid if parse failed)
    ret i32 -1
    
check_temp_module:
    ; Verify temp module was created successfully
    %temp_module_check = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_check_null = icmp eq %LLVMModuleRef %temp_module_check, null
    br i1 %temp_module_check_null, label %error, label %success
    
success:
    ; Get main module from CodeGen structure
    %main_module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %main_module = load %LLVMModuleRef, %LLVMModuleRef* %main_module_ptr
    %main_module_null = icmp eq %LLVMModuleRef %main_module, null
    br i1 %main_module_null, label %dispose_temp_and_error, label %link_modules
    
link_modules:
    ; Link temp module into main module
    ; Note: LLVMLinkModules2 automatically resolves symbols - if a symbol is referenced
    ; in the temp module but defined in the main module, it will be linked correctly.
    ; This allows functions to reference constants defined earlier without external declarations.
    %temp_module = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_null = icmp eq %LLVMModuleRef %temp_module, null
    br i1 %temp_module_null, label %error, label %do_link
    
do_link:
    ; Link src (temp) into dest (main)
    ; LLVMLinkModules2 automatically moves contents from src to dest
    ; and resolves symbol references to definitions in the destination module
    %link_result = call i32 @llvm_link_modules2(%LLVMModuleRef %main_module, %LLVMModuleRef %temp_module)
    %link_failed = icmp ne i32 %link_result, 0
    br i1 %link_failed, label %dispose_and_error, label %success_after_link
    
success_after_link:
    ; Linking succeeded - function is now in main module
    ; Dispose temp module after linking (it's now empty but still needs to be freed)
    ; According to LLVM docs, LLVMLinkModules2 moves content from src to dest,
    ; leaving src empty. The empty module should still be disposed to free memory.
    %temp_module_success = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_success_null = icmp eq %LLVMModuleRef %temp_module_success, null
    br i1 %temp_module_success_null, label %return_success, label %dispose_temp_success
    
dispose_temp_success:
    call void @llvm_dispose_module(%LLVMModuleRef %temp_module_success)
    br label %return_success
    
return_success:
    ret i32 0
    
dispose_temp_and_error:
    ; Dispose temp module before error return
    %temp_module_for_error = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_for_error_null = icmp eq %LLVMModuleRef %temp_module_for_error, null
    br i1 %temp_module_for_error_null, label %error, label %dispose_temp_error
    
dispose_temp_error:
    call void @llvm_dispose_module(%LLVMModuleRef %temp_module_for_error)
    br label %error
    
dispose_and_error:
    ; Dispose temp module if it exists
    %temp_module_for_dispose = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_for_dispose_null = icmp eq %LLVMModuleRef %temp_module_for_dispose, null
    br i1 %temp_module_for_dispose_null, label %error, label %dispose_temp_module_error
    
dispose_temp_module_error:
    call void @llvm_dispose_module(%LLVMModuleRef %temp_module_for_dispose)
    br label %error
    
error:
    ret i32 -1
}

; Write bitcode to file

; codegen_write_ir_text: Write module IR text to file using LLVM API
; Parameters:
;   cg: Pointer to CodeGen structure
;   filename: Output file path (null-terminated string)
; Returns: 0 on success, -1 on error
define i32 @codegen_write_ir_text(%CodeGen* %cg, i8* %filename) {
entry:
    %cg_null = icmp eq %CodeGen* %cg, null
    br i1 %cg_null, label %error, label %get_module
    
get_module:
    ; Get LLVM module from CodeGen structure
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %error, label %write
    
write:
    ; Write IR text to file
    %error_msg = alloca i8*
    store i8* null, i8** %error_msg
    %result = call i32 @llvm_print_module_to_file(%LLVMModuleRef %module, i8* %filename, i8** %error_msg)
    %write_failed = icmp ne i32 %result, 0
    br i1 %write_failed, label %error, label %success
    
success:
    ret i32 0
    
error:
    ret i32 -1
}

; codegen_write_bitcode: Write module bitcode to file using LLVM API
; Parameters:
;   cg: Pointer to CodeGen structure
;   filename: Output file path (null-terminated string)
; Returns: 0 on success, -1 on error
define i32 @codegen_write_bitcode(%CodeGen* %cg, i8* %filename) {
entry:
    %cg_null = icmp eq %CodeGen* %cg, null
    br i1 %cg_null, label %error, label %get_module
    
get_module:
    ; Get LLVM module from CodeGen structure
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %error, label %write
    
write:
    ; Verify module before writing (helps ensure module is in valid state)
    ; Note: We ignore verification errors as they may be false positives
    ; (e.g., vararg functions, global initializers), but verification itself
    ; may help finalize module state for proper bitcode writing
    %verify_error_msg = alloca i8*
    store i8* null, i8** %verify_error_msg
    %verify_result = call i32 @llvm_verify_module(%LLVMModuleRef %module, i32 1, i8** %verify_error_msg)
    ; Continue regardless of verification result
    
    ; Write bitcode to file
    %result = call i32 @llvm_write_bitcode_to_file(%LLVMModuleRef %module, i8* %filename)
    %write_failed = icmp ne i32 %result, 0
    br i1 %write_failed, label %error, label %success
    
success:
    ret i32 0
    
error:
    ret i32 -1
}

; Write object file
; codegen_write_object_file: Write module directly to object file using TargetMachine API
; Parameters:
;   cg: Pointer to CodeGen structure
;   filename: Output file path (null-terminated string)
; Returns: 0 on success, -1 on error
define i32 @codegen_write_object_file(%CodeGen* %cg, i8* %filename) {
entry:
    %cg_null = icmp eq %CodeGen* %cg, null
    br i1 %cg_null, label %error, label %get_module
    
get_module:
    ; Get LLVM module from CodeGen structure
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %error, label %get_triple
    
get_triple:
    ; Get default target triple from LLVM (this should match the system)
    %default_triple = call i8* @llvm_get_default_target_triple()
    %triple_null = icmp eq i8* %default_triple, null
    br i1 %triple_null, label %use_hardcoded_triple, label %get_target
    
use_hardcoded_triple:
    ; Fallback to hardcoded triple if default fails
    %triple_array = bitcast [18 x i8]* @.str.target_triple_value to i8*
    br label %get_target_with_triple
    
get_target:
    ; Use default triple
    br label %get_target_with_triple
    
get_target_with_triple:
    ; Get the triple to use (either default or hardcoded)
    %triple_to_use = phi i8* [ %default_triple, %get_target ], [ %triple_array, %use_hardcoded_triple ]
    br label %get_target_impl
    
get_target_impl:
    ; Get target from triple
    %target_ptr = alloca %LLVMTargetRef
    %error_msg_ptr = alloca i8*
    store i8* null, i8** %error_msg_ptr
    %target_result = call i32 @llvm_get_target_from_triple(i8* %triple_to_use, %LLVMTargetRef* %target_ptr, i8** %error_msg_ptr)
    %target_failed = icmp ne i32 %target_result, 0
    br i1 %target_failed, label %error, label %create_target_machine
    
create_target_machine:
    %target = load %LLVMTargetRef, %LLVMTargetRef* %target_ptr
    
    ; Create target machine with default options
    ; CPU: empty string (use default)
    ; Features: empty string (use default)
    ; Level: 2 (CodeGenLevelDefault)
    ; Reloc: 0 (RelocDefault)
    ; CodeModel: 0 (CodeModelDefault)
    %cpu_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %features_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %tm = call %LLVMTargetMachineRef @llvm_create_target_machine(%LLVMTargetRef %target, i8* %triple_to_use, i8* %cpu_str, i8* %features_str, i32 2, i32 0, i32 0)
    %tm_null = icmp eq %LLVMTargetMachineRef %tm, null
    br i1 %tm_null, label %error, label %emit_file
    
emit_file:
    ; Emit module to object file
    ; CodeGen type: 1 = ObjectFile
    %error_msg_emit = alloca i8*
    store i8* null, i8** %error_msg_emit
    %emit_result = call i32 @llvm_target_machine_emit_to_file(%LLVMTargetMachineRef %tm, %LLVMModuleRef %module, i8* %filename, i32 1, i8** %error_msg_emit)
    
    ; Dispose target machine
    call void @llvm_dispose_target_machine(%LLVMTargetMachineRef %tm)
    
    %emit_failed = icmp ne i32 %emit_result, 0
    br i1 %emit_failed, label %error, label %success
    
success:
    ret i32 0
    
error:
    ret i32 -1
}

; Forward declaration for printf (from ffi.ll)
declare i32 @printf(i8*, ...)

; String literals
@.str.target_triple = private unnamed_addr constant [39 x i8] c"target triple = \22arm64-apple-darwin\22\0A\0A\00"
@.str.printf_decl = private unnamed_addr constant [42 x i8] c"declare i32 @printf(i8* nocapture, ...)\0A\0A\00"
@.str.debug_prefix_lexer = private unnamed_addr constant [9 x i8] c"[LEXER] \00"
@.str.debug_prefix_parser = private unnamed_addr constant [10 x i8] c"[PARSER] \00"
@.str.debug_prefix_codegen = private unnamed_addr constant [11 x i8] c"[CODEGEN] \00"
@.str.debug_prefix_dsl_body = private unnamed_addr constant [12 x i8] c"[DSL-BODY] \00"
@.str.debug_prefix_dsl_expr = private unnamed_addr constant [12 x i8] c"[DSL-EXPR] \00"
@.str.debug_newline = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str.debug_define_llvm_function_start = private unnamed_addr constant [39 x i8] c"codegen_define_llvm_function: starting\00"
@.str.debug_define_llvm_ffi_function_start = private unnamed_addr constant [43 x i8] c"codegen_define_llvm_ffi_function: starting\00"
@.str.debug_declare_llvm_function_start = private unnamed_addr constant [40 x i8] c"codegen_declare_llvm_function: starting\00"
@.str.debug_extracting_dsl_body = private unnamed_addr constant [29 x i8] c"Extracting DSL body from AST\00"
@.str.debug_dsl_body_extracted = private unnamed_addr constant [32 x i8] c"DSL body extracted successfully\00"
@.str.debug_evaluating_dsl_body = private unnamed_addr constant [20 x i8] c"Evaluating DSL body\00"
@.str.debug_dsl_body_expr = private unnamed_addr constant [30 x i8] c"Evaluating expression in body\00"
@.str.debug_dsl_expr_atom = private unnamed_addr constant [15 x i8] c"DSL expr: atom\00"
@.str.debug_dsl_expr_list = private unnamed_addr constant [15 x i8] c"DSL expr: list\00"
@.str.debug_dsl_primitive = private unnamed_addr constant [16 x i8] c"DSL primitive: \00"
@.str.debug_dsl_body_start = private unnamed_addr constant [29 x i8] c"codegen_eval_dsl_body: start\00"
@.str.debug_body_type_check = private unnamed_addr constant [25 x i8] c"Body type check: type=%d\00"
@.str.debug_dsl_body_done = private unnamed_addr constant [28 x i8] c"codegen_eval_dsl_body: done\00"
@.str.debug_expr_null = private unnamed_addr constant [15 x i8] c"DSL expr: null\00"
@.str.debug_expr_type = private unnamed_addr constant [18 x i8] c"DSL expr type: %d\00"
@.str.debug_unknown_primitive = private unnamed_addr constant [25 x i8] c"ERROR: Unknown primitive\00"
@.str.debug_func_eval_result = private unnamed_addr constant [32 x i8] c"Function eval result (checking)\00"
@.str.debug_get_function_result = private unnamed_addr constant [27 x i8] c"llvm-get-function result: \00"
@.str.debug_looking_up_func = private unnamed_addr constant [22 x i8] c"Looking up function: \00"
@.str.debug_null = private unnamed_addr constant [5 x i8] c"NULL\00"
@.str.debug_not_null = private unnamed_addr constant [3 x i8] c"OK\00"
@.str.debug_func_not_found_error = private unnamed_addr constant [27 x i8] c"ERROR: Function not found!\00"
@.str.debug_getting_func_type = private unnamed_addr constant [25 x i8] c"Getting function type...\00"
@.str.debug_func_type_result = private unnamed_addr constant [21 x i8] c"Function type result\00"
@.str.debug_func_type_null_error = private unnamed_addr constant [30 x i8] c"ERROR: Function type is null!\00"
@.str.debug_null_arg_error = private unnamed_addr constant [28 x i8] c"ERROR: Argument %d is null!\00"
@.str.debug_building_call = private unnamed_addr constant [27 x i8] c"Building call with %d args\00"
@.str.debug_resolving_param = private unnamed_addr constant [22 x i8] c"Resolving parameter: \00"
@.str.debug_param_names_null = private unnamed_addr constant [33 x i8] c"ERROR: param_names list is null!\00"
@.str.debug_current_func_null = private unnamed_addr constant [33 x i8] c"ERROR: current_function is null!\00"
@.str.debug_param_found = private unnamed_addr constant [24 x i8] c"Parameter found in list\00"
@.str.debug_param_value_null = private unnamed_addr constant [40 x i8] c"ERROR: Parameter value null at index %d\00"
@.str.debug_param_value_ok = private unnamed_addr constant [31 x i8] c"Parameter value OK at index %d\00"
@.str.debug_getting_param_by_index = private unnamed_addr constant [30 x i8] c"Getting parameter at index %d\00"
@.str.debug_param_count = private unnamed_addr constant [29 x i8] c"Function has %d parameter(s)\00"
@.str.debug_collected_param_count = private unnamed_addr constant [31 x i8] c"Collected %d parameter type(s)\00"
@.str.debug_collect_params_start = private unnamed_addr constant [35 x i8] c"codegen_collect_param_types: start\00"
@.str.debug_params_null = private unnamed_addr constant [28 x i8] c"ERROR: params list is null!\00"
@.str.debug_processing_param = private unnamed_addr constant [27 x i8] c"Processing parameter %d...\00"
@.str.debug_param_pair_null = private unnamed_addr constant [27 x i8] c"ERROR: param_pair is null!\00"
@.str.debug_pair_cdr_null_collect = private unnamed_addr constant [25 x i8] c"ERROR: pair_cdr is null!\00"
@.str.debug_type_node_null = private unnamed_addr constant [26 x i8] c"ERROR: type_node is null!\00"
@.str.debug_resolving_type = private unnamed_addr constant [17 x i8] c"Resolving type: \00"
@.str.debug_type_resolve_failed = private unnamed_addr constant [28 x i8] c"ERROR: Type resolve failed!\00"
@.str.debug_param_lookup_still_null = private unnamed_addr constant [46 x i8] c"ERROR: param_lookup still null before return!\00"
@.str.debug_returning_param_value = private unnamed_addr constant [37 x i8] c"Returning parameter value (non-null)\00"
@.str.debug_returning_from_eval = private unnamed_addr constant [39 x i8] c"codegen_eval_dsl_expr returning param:\00"
@.str.debug_storing_arg = private unnamed_addr constant [30 x i8] c"Storing argument %d in array:\00"
@.str.debug_stored_value_null = private unnamed_addr constant [35 x i8] c"ERROR: Stored value is null at %d!\00"
@.str.debug_value_stored_ok = private unnamed_addr constant [32 x i8] c"Value stored successfully at %d\00"
@.str.debug_extracting_args_list = private unnamed_addr constant [24 x i8] c"Extracting args list...\00"
@.str.debug_checking_i8_ptr = private unnamed_addr constant [26 x i8] c"Checking for i8* match...\00"
@.str.debug_i8_ptr_cmp_result = private unnamed_addr constant [26 x i8] c"i8* comparison result: %d\00"
@.str.debug_i8_ptr_bar_cmp_result = private unnamed_addr constant [28 x i8] c"|i8*| comparison result: %d\00"
@.str.debug_looking_up_global = private unnamed_addr constant [20 x i8] c"Looking up global: \00"
@.str.debug_local = private unnamed_addr constant [8 x i8] c"local: \00"
@.str.debug_global_not_found = private unnamed_addr constant [25 x i8] c"ERROR: Global not found!\00"
@.str.debug_name_colon_space = private unnamed_addr constant [8 x i8] c" name: \00"
@.str.debug_local_not_found = private unnamed_addr constant [18 x i8] c"Local not found: \00"
@.str.debug_global_found = private unnamed_addr constant [17 x i8] c"Global found: OK\00"
@.str.debug_creating_constant = private unnamed_addr constant [25 x i8] c"Creating constant: name=\00"
@.str.debug_constant_created = private unnamed_addr constant [28 x i8] c"Constant created, pointer: \00"
@.str.debug_storing_constant = private unnamed_addr constant [24 x i8] c"Storing constant: name=\00"
@.str.debug_constant_stored = private unnamed_addr constant [27 x i8] c"Constant stored, pointer: \00"
@.str.debug_looking_up_constant = private unnamed_addr constant [27 x i8] c"Looking up constant: name=\00"
@.str.debug_evaluating_value = private unnamed_addr constant [14 x i8] c" - evaluating\00"
@.str.debug_value_eval_failed = private unnamed_addr constant [21 x i8] c" - value eval FAILED\00"
@.str.debug_let_star_recognized = private unnamed_addr constant [8 x i8] c"let* OK\00"
@.str.debug_processing_binding = private unnamed_addr constant [19 x i8] c"Processing binding\00"
@.str.debug_extracted_name = private unnamed_addr constant [17 x i8] c"Extracted name: \00"
@.str.debug_binding_local_value = private unnamed_addr constant [22 x i8] c"Binding local value: \00"
@.str.debug_no_more_bindings = private unnamed_addr constant [34 x i8] c"No more bindings, evaluating body\00"
@.str.debug_processing_bindings_list = private unnamed_addr constant [28 x i8] c"Processing bindings list...\00"
@.str.debug_binding_pair_null = private unnamed_addr constant [22 x i8] c"Binding pair is null!\00"
@.str.debug_binding_type_check = private unnamed_addr constant [28 x i8] c"Binding type check: type=%d\00"
@.str.debug_binding_not_list = private unnamed_addr constant [32 x i8] c"Binding is not a list, skipping\00"
@.str.debug_binding_name_null = private unnamed_addr constant [22 x i8] c"Binding name is null!\00"
@.str.debug_name_type_check = private unnamed_addr constant [25 x i8] c"Name type check: type=%d\00"
@.str.debug_name_not_atom = private unnamed_addr constant [26 x i8] c"Binding name is not atom!\00"
@.str.debug_binding_val_type = private unnamed_addr constant [27 x i8] c"binding_val type check: %d\00"
@.str.debug_bindings_list_type = private unnamed_addr constant [34 x i8] c"bindings_list type check: type=%d\00"
@.str.debug_value_expr_type = private unnamed_addr constant [31 x i8] c"value_expr type check: type=%d\00"
@.str.debug_binding_val_car_type = private unnamed_addr constant [36 x i8] c"binding_val.car type check: type=%d\00"
@.str.debug_value_wrapper_type = private unnamed_addr constant [34 x i8] c"value_wrapper type check: type=%d\00"
@.str.debug_constant_found = private unnamed_addr constant [26 x i8] c"Constant found, pointer: \00"
@.str.debug_constant_not_found = private unnamed_addr constant [26 x i8] c"Constant not found: name=\00"
@.str.debug_pointer_value = private unnamed_addr constant [13 x i8] c", pointer=%p\00"
@.str.debug_type_fmt = private unnamed_addr constant [3 x i8] c"%s\00"
@.str.debug_type_len = private unnamed_addr constant [17 x i8] c"Type length: %ld\00"
@.str.debug_name_len_bounds_check = private unnamed_addr constant [46 x i8] c"ERROR: name_len out of bounds: %ld (max 1000)\00"
@.str.debug_name_null_check = private unnamed_addr constant [29 x i8] c"ERROR: name pointer is null!\00"
@.str.debug_atom_val_ptr = private unnamed_addr constant [31 x i8] c"Atom val pointer: %p, len: %ld\00"
@.str.debug_atom_first_bytes = private unnamed_addr constant [27 x i8] c"Atom first bytes: %c%c%c%c\00"
@.str.debug_looking_up_function = private unnamed_addr constant [27 x i8] c"Looking up function: name=\00"
@.str.debug_function_list_size = private unnamed_addr constant [29 x i8] c"Function list has %d entries\00"
@.str.debug_function_found = private unnamed_addr constant [19 x i8] c"Function found: OK\00"
@.str.debug_function_not_found = private unnamed_addr constant [21 x i8] c"Function not found: \00"
@.str.debug_checking_array = private unnamed_addr constant [22 x i8] c"Checking for array...\00"
@.str.debug_reached_array_check = private unnamed_addr constant [26 x i8] c"Reached check_array block\00"
@.str.debug_first_char = private unnamed_addr constant [21 x i8] c"First char: %d (dec)\00"
@.str.debug_checking_builder = private unnamed_addr constant [19 x i8] c"Checking builder: \00"
@.str.debug_checking_func_type = private unnamed_addr constant [21 x i8] c"Checking func_type: \00"
@.str.debug_checking_func = private unnamed_addr constant [16 x i8] c"Checking func: \00"
@.str.debug_checking_args_array = private unnamed_addr constant [22 x i8] c"Checking args_array: \00"
@.str.debug_first_arg_value = private unnamed_addr constant [18 x i8] c"First arg value: \00"
@.str.debug_arg_value_at = private unnamed_addr constant [18 x i8] c"Arg value at %d: \00"
@.str.debug_index_out_of_range = private unnamed_addr constant [54 x i8] c"ERROR: Index %d out of range (function has %d params)\00"
@.str.debug_getting_index_node = private unnamed_addr constant [22 x i8] c"Getting index node...\00"
@.str.debug_checking_pair_cdr = private unnamed_addr constant [21 x i8] c"Checking pair cdr...\00"
@.str.debug_param_atom_type = private unnamed_addr constant [26 x i8] c"Param value atom_type: %d\00"
@.str.debug_param_not_number_type = private unnamed_addr constant [39 x i8] c"ERROR: Param value not number type: %d\00"
@.str.debug_creating_pair = private unnamed_addr constant [28 x i8] c"Creating pair with index %d\00"
@.str.debug_pair_cdr_null = private unnamed_addr constant [25 x i8] c"ERROR: Pair cdr is null!\00"
@.str.debug_pair_cdr_lost = private unnamed_addr constant [37 x i8] c"ERROR: Pair cdr lost after creation!\00"
@.str.debug_checking_pair = private unnamed_addr constant [20 x i8] c"Checking pair cdr: \00"
@.str.debug_pair_cdr_null_before_store = private unnamed_addr constant [37 x i8] c"ERROR: Pair cdr null before storing!\00"
@.str.debug_comparing_names = private unnamed_addr constant [24 x i8] c"Comparing with stored: \00"
@.str.debug_empty_str = private unnamed_addr constant [8 x i8] c"<empty>\00"
@.str.debug_building_param_name = private unnamed_addr constant [27 x i8] c"Building param name node: \00"
@.str.debug_retrieving_name_node = private unnamed_addr constant [31 x i8] c"Retrieving name node from pair\00"
@.str.debug_name_node_type = private unnamed_addr constant [31 x i8] c"Name node type=%d atom_type=%d\00"
@.str.module_name = private unnamed_addr constant [5 x i8] c"vibe\00"
@.str.target_triple_value = private unnamed_addr constant [19 x i8] c"arm64-apple-darwin\00"
@.str.data_layout_value = private unnamed_addr constant [34 x i8] c"e-m:o-i64:64-i128:128-n32:64-S128\00"
@.str.space_at = private unnamed_addr constant [3 x i8] c" @\00"
@.str.newline_close_brace = private unnamed_addr constant [4 x i8] c"\0A}\0A\00"
@.str.main_name = private unnamed_addr constant [5 x i8] c"main\00"
@.str.data_layout_prefix = private unnamed_addr constant [22 x i8] c"target datalayout = \22\00"
@.str.data_layout_suffix = private unnamed_addr constant [3 x i8] c"\22\0A\00"
@.str.target_triple_prefix = private unnamed_addr constant [18 x i8] c"target triple = \22\00"
@.str.target_triple_suffix = private unnamed_addr constant [4 x i8] c"\22\0A\0A\00"
@.str.entry_block_name = private unnamed_addr constant [6 x i8] c"entry\00"
@.str.define_void = private unnamed_addr constant [12 x i8] c"define void\00"
@.str.lparen = private unnamed_addr constant [2 x i8] c"(\00"
@.str.rparen = private unnamed_addr constant [2 x i8] c")\00"
@.str.rparen_brace = private unnamed_addr constant [4 x i8] c") {\00"
@.str.close_brace = private unnamed_addr constant [2 x i8] c"}\00"
@.str.i8_ptr = private unnamed_addr constant [4 x i8] c"i8*\00"
@.str.percent = private unnamed_addr constant [2 x i8] c"%\00"
@.str.comma_space = private unnamed_addr constant [3 x i8] c", \00"
@.str.call_void = private unnamed_addr constant [10 x i8] c"call void\00"
@.str.define_main = private unnamed_addr constant [21 x i8] c"define i32 @main() {\00"
@.str.ret_zero = private unnamed_addr constant [12 x i8] c"  ret i32 0\00"
@.str.type_equals = private unnamed_addr constant [8 x i8] c" = type\00"
@.str.lbrace = private unnamed_addr constant [3 x i8] c" {\00"
@.str.rbrace = private unnamed_addr constant [2 x i8] c"}\00"
@.str.newline = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str.at_sign = private unnamed_addr constant [2 x i8] c"@\00"
@.str.constant_equals = private unnamed_addr constant [12 x i8] c" = constant\00"
@.str.space = private unnamed_addr constant [2 x i8] c" \00"
@.str.define = private unnamed_addr constant [8 x i8] c"define \00"
@.str.c_quote_open = private unnamed_addr constant [3 x i8] c"c\22\00"
@.str.quote = private unnamed_addr constant [2 x i8] c"\22\00"
@.str.backslash_00 = private unnamed_addr constant [4 x i8] c"\\00\00"
@.str.backslash_quote = private unnamed_addr constant [3 x i8] c"\\\22\00"
@.str.backslash_backslash = private unnamed_addr constant [3 x i8] c"\\\\\00"
@.str.func_not_found_after_link = private unnamed_addr constant [42 x i8] c"ERROR: Function not found after linking: \00"
@.str.func_not_found_in_call = private unnamed_addr constant [36 x i8] c"ERROR: Function not found in call: \00"
@.str.processing_call = private unnamed_addr constant [27 x i8] c"Processing function call: \00"
@.str.func_name_extraction_failed = private unnamed_addr constant [47 x i8] c"ERROR: Failed to extract function name from IR\00"
@.str.extracting_from_ir = private unnamed_addr constant [32 x i8] c"Extracting function name from: \00"
@.str.extracted_name = private unnamed_addr constant [26 x i8] c"Extracted function name: \00"
@.str.reached_verify_after_link = private unnamed_addr constant [33 x i8] c"DEBUG: Reached verify_after_link\00"
@.str.about_to_link = private unnamed_addr constant [22 x i8] c"About to link modules\00"
@.str.link_succeeded = private unnamed_addr constant [33 x i8] c"DEBUG: Link succeeded (result=0)\00"
@.str.link_failed = private unnamed_addr constant [31 x i8] c"DEBUG: Link failed (result!=0)\00"
@.str.external_hello_string = private unnamed_addr constant [45 x i8] c"@hello_string = external constant [14 x i8]\0A\00"
@.str.func_found_after_link = private unnamed_addr constant [36 x i8] c"DEBUG: Function found after linking\00"
@.str.printf_decl_module = private unnamed_addr constant [42 x i8] c"declare i32 @printf(i8* nocapture, ...)\0A\0A\00"
@.str.constant_decl = private unnamed_addr constant [22 x i8] c" = private constant [\00"
@.str.x_i8_c_quote = private unnamed_addr constant [10 x i8] c" x i8] c\22\00"
@.str.quote_newline = private unnamed_addr constant [3 x i8] c"\22\0A\00"
@.str.getelementptr_start = private unnamed_addr constant [16 x i8] c"getelementptr [\00"
@.str.getelementptr_open = private unnamed_addr constant [15 x i8] c"getelementptr(\00"
@.str.lbracket = private unnamed_addr constant [2 x i8] c"[\00"
@.str.x_i8_bracket_comma = private unnamed_addr constant [10 x i8] c" x i8], [\00"
@.str.x_i8_ptr_at = private unnamed_addr constant [10 x i8] c" x i8]* @\00"
@.str.getelementptr_indices = private unnamed_addr constant [15 x i8] c", i32 0, i32 0\00"
@.str.printf_name = private unnamed_addr constant [7 x i8] c"printf\00"
@.str.empty = private unnamed_addr constant [1 x i8] c"\00"
@.str.type_void = private unnamed_addr constant [5 x i8] c"void\00"
@.str.type_i8 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.type_i8_ptr = private unnamed_addr constant [4 x i8] c"i8*\00"
@.str.type_i32 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.type_i64 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.dsl_gep = private unnamed_addr constant [9 x i8] c"llvm:gep\00"
@.str.dsl_call = private unnamed_addr constant [10 x i8] c"llvm:call\00"
@.str.dsl_ret_void = private unnamed_addr constant [14 x i8] c"llvm:ret-void\00"
@.str.dsl_ret = private unnamed_addr constant [9 x i8] c"llvm:ret\00"
@.str.dsl_get_global = private unnamed_addr constant [16 x i8] c"llvm:get-global\00"
@.str.dsl_get_function = private unnamed_addr constant [18 x i8] c"llvm:get-function\00"
@.str.dsl_get_param = private unnamed_addr constant [15 x i8] c"llvm:get-param\00"
@.str.dsl_const_int = private unnamed_addr constant [15 x i8] c"llvm:const-int\00"
@.str.dsl_const_null = private unnamed_addr constant [16 x i8] c"llvm:const-null\00"
@.str.dsl_list = private unnamed_addr constant [5 x i8] c"list\00"
@.str.dsl_array = private unnamed_addr constant [11 x i8] c"llvm:array\00"
@.str.let_star = private unnamed_addr constant [5 x i8] c"let*\00"
@.str.dsl_bitcast = private unnamed_addr constant [13 x i8] c"llvm:bitcast\00"
@.str.dsl_store = private unnamed_addr constant [11 x i8] c"llvm:store\00"
@.str.dsl_load = private unnamed_addr constant [10 x i8] c"llvm:load\00"
@.str.dsl_icmp = private unnamed_addr constant [10 x i8] c"llvm:icmp\00"
@.str.dsl_br = private unnamed_addr constant [8 x i8] c"llvm:br\00"
@.str.dsl_zext = private unnamed_addr constant [10 x i8] c"llvm:zext\00"
@.str.dsl_add = private unnamed_addr constant [9 x i8] c"llvm:add\00"
@.str.dsl_or = private unnamed_addr constant [8 x i8] c"llvm:or\00"
@.str.dsl_label = private unnamed_addr constant [11 x i8] c"llvm:label\00"
@.str.dsl_alloca = private unnamed_addr constant [12 x i8] c"llvm:alloca\00"
@.str.dsl_sub = private unnamed_addr constant [9 x i8] c"llvm:sub\00"
@.str.dsl_and = private unnamed_addr constant [9 x i8] c"llvm:and\00"
@.str.dsl_mul = private unnamed_addr constant [9 x i8] c"llvm:mul\00"
@.str.dsl_trunc = private unnamed_addr constant [11 x i8] c"llvm:trunc\00"
@.str.dsl_select = private unnamed_addr constant [12 x i8] c"llvm:select\00"
@.str.dsl_phi = private unnamed_addr constant [9 x i8] c"llvm:phi\00"
@.str.dsl_undef = private unnamed_addr constant [11 x i8] c"llvm:undef\00"
@.str.dsl_insertvalue = private unnamed_addr constant [17 x i8] c"llvm:insertvalue\00"
@.str.dsl_extractvalue = private unnamed_addr constant [18 x i8] c"llvm:extractvalue\00"
@.str.dsl_urem = private unnamed_addr constant [10 x i8] c"llvm:urem\00"
@.str.dsl_udiv = private unnamed_addr constant [10 x i8] c"llvm:udiv\00"
@.str.dsl_ptrtoint = private unnamed_addr constant [14 x i8] c"llvm:ptrtoint\00"
@.str.err_label_no_terminator = private unnamed_addr constant [37 x i8] c"error: label '%s' has no terminator\0A\00"
@.str.err_entry_no_terminator = private unnamed_addr constant [55 x i8] c"error: entry block of function '%s' has no terminator\0A\00"
@.str.pred_eq = private unnamed_addr constant [3 x i8] c"eq\00"
@.str.pred_ne = private unnamed_addr constant [3 x i8] c"ne\00"
@.str.pred_uge = private unnamed_addr constant [4 x i8] c"uge\00"
@.str.pred_ult = private unnamed_addr constant [4 x i8] c"ult\00"
@.str.pred_ugt = private unnamed_addr constant [4 x i8] c"ugt\00"
@.str.pred_ule = private unnamed_addr constant [4 x i8] c"ule\00"
@.str.pred_sge = private unnamed_addr constant [4 x i8] c"sge\00"
@.str.pred_slt = private unnamed_addr constant [4 x i8] c"slt\00"
@.str.pred_sgt = private unnamed_addr constant [4 x i8] c"sgt\00"
@.str.pred_sle = private unnamed_addr constant [4 x i8] c"sle\00"

; ============================================================================
; Debug Logging Helpers
; ============================================================================

; debug_log_string: Print debug message with prefix
; Parameters:
;   prefix: Prefix string (e.g., "[LEXER] ")
;   message: Message string
;   message_len: Message length
define void @debug_log_string(i8* %prefix, i8* %message, i64 %message_len) {
entry:
    ; Print prefix
    call i32 (i8*, ...) @printf(i8* %prefix)
    
    ; Create null-terminated message
    %buf_size = add i64 %message_len, 1
    %buf = call i8* @malloc(i64 %buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %buf, i8* %message, i64 %message_len, i1 false)
    %null_ptr = getelementptr i8, i8* %buf, i64 %message_len
    store i8 0, i8* %null_ptr
    
    ; Print message
    call i32 (i8*, ...) @printf(i8* %buf)
    
    ; Print newline
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Free buffer
    call void @free(i8* %buf)
    ret void
}

; Append bytevector with proper escaping for LLVM IR
; codegen_append_bytevector: Append bytevector data with escaping
; Parameters:
;   cg: Pointer to CodeGen structure
;   data: Bytevector data
;   len: Length of bytevector
define void @codegen_append_bytevector(%CodeGen* %cg, i8* %data, i64 %len) {
entry:
    %i = alloca i64
    store i64 0, i64* %i
    br label %loop

loop:
    %i_val = load i64, i64* %i
    %done = icmp uge i64 %i_val, %len
    br i1 %done, label %exit, label %process_byte

process_byte:
    %byte_ptr = getelementptr i8, i8* %data, i64 %i_val
    %byte = load i8, i8* %byte_ptr
    %byte_int = zext i8 %byte to i32
    
    ; Check if null byte - escape as \00
    %is_null = icmp eq i32 %byte_int, 0
    br i1 %is_null, label %escape_null, label %check_quote
    
escape_null:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.backslash_00, i32 0, i32 0), i64 3)
    br label %increment
    
check_quote:
    ; Check if quote - escape as \"
    %is_quote = icmp eq i32 %byte_int, 34
    br i1 %is_quote, label %escape_quote, label %check_backslash
    
escape_quote:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.backslash_quote, i32 0, i32 0), i64 2)
    br label %increment
    
check_backslash:
    ; Check if backslash - escape as \\
    %is_backslash = icmp eq i32 %byte_int, 92
    br i1 %is_backslash, label %escape_backslash, label %normal_byte
    
escape_backslash:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.backslash_backslash, i32 0, i32 0), i64 2)
    br label %increment
    
normal_byte:
    ; Write byte directly
    %byte_ptr_copy = getelementptr i8, i8* %data, i64 %i_val
    call void @codegen_append(%CodeGen* %cg, i8* %byte_ptr_copy, i64 1)
    br label %increment
    
increment:
    %i_val_inc = load i64, i64* %i
    %i_new = add i64 %i_val_inc, 1
    store i64 %i_new, i64* %i
    br label %loop

exit:
    ret void
}

; Write bytevector data with escaping to a buffer
; codegen_write_bytevector_to_buffer: Write bytevector data with escaping to buffer
; Parameters:
;   buf: Buffer pointer
;   pos: Pointer to current position in buffer (will be updated)
;   data: Bytevector data
;   len: Length of bytevector
define void @codegen_write_bytevector_to_buffer(i8* %buf, i64* %pos, i8* %data, i64 %len) {
entry:
    %i = alloca i64
    store i64 0, i64* %i
    br label %loop

loop:
    %i_val = load i64, i64* %i
    %done = icmp uge i64 %i_val, %len
    br i1 %done, label %exit, label %process_byte

process_byte:
    %byte_ptr = getelementptr i8, i8* %data, i64 %i_val
    %byte = load i8, i8* %byte_ptr
    %byte_int = zext i8 %byte to i32
    
    ; Check if null byte - escape as \00
    %is_null = icmp eq i32 %byte_int, 0
    br i1 %is_null, label %escape_null, label %check_quote
    
escape_null:
    %pos_val_n = load i64, i64* %pos
    %dest_n = getelementptr i8, i8* %buf, i64 %pos_val_n
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_n, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.backslash_00, i32 0, i32 0), i64 3, i1 false)
    %pos_val_n2 = add i64 %pos_val_n, 3
    store i64 %pos_val_n2, i64* %pos
    br label %increment
    
check_quote:
    ; Check if quote - escape as \"
    %is_quote = icmp eq i32 %byte_int, 34
    br i1 %is_quote, label %escape_quote, label %check_backslash
    
escape_quote:
    %pos_val_q = load i64, i64* %pos
    %dest_q = getelementptr i8, i8* %buf, i64 %pos_val_q
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_q, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.backslash_quote, i32 0, i32 0), i64 2, i1 false)
    %pos_val_q2 = add i64 %pos_val_q, 2
    store i64 %pos_val_q2, i64* %pos
    br label %increment
    
check_backslash:
    ; Check if backslash - escape as \\
    %is_backslash = icmp eq i32 %byte_int, 92
    br i1 %is_backslash, label %escape_backslash, label %normal_byte
    
escape_backslash:
    %pos_val_b = load i64, i64* %pos
    %dest_b = getelementptr i8, i8* %buf, i64 %pos_val_b
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_b, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.backslash_backslash, i32 0, i32 0), i64 2, i1 false)
    %pos_val_b2 = add i64 %pos_val_b, 2
    store i64 %pos_val_b2, i64* %pos
    br label %increment
    
normal_byte:
    ; Write byte directly
    %pos_val = load i64, i64* %pos
    %dest = getelementptr i8, i8* %buf, i64 %pos_val
    %byte_ptr_copy = getelementptr i8, i8* %data, i64 %i_val
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest, i8* %byte_ptr_copy, i64 1, i1 false)
    %pos_val2 = add i64 %pos_val, 1
    store i64 %pos_val2, i64* %pos
    br label %increment
    
increment:
    %i_val_inc = load i64, i64* %i
    %i_new = add i64 %i_val_inc, 1
    store i64 %i_new, i64* %i
    br label %loop

exit:
    ret void
}

; ============================================================================
; DSL Evaluation Infrastructure
; ============================================================================

; Resolve type string to LLVMTypeRef
; codegen_resolve_type_string: Parse type string and return LLVMTypeRef
; Parameters:
;   cg: Pointer to CodeGen structure
;   type_str: Type string (e.g., "|i8*|", "|void|", "|[14 x i8]|")
;   type_len: Length of type string
; Returns: LLVMTypeRef, or null on error
; Handles: i8, i32, i64, void, i8*, [N x i8], [N x i8]*
define %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len) {
entry:
    ; Debug: Print type string being resolved
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_resolving_type, i32 0, i32 0))
    
    ; Debug: Print length first
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_type_len, i32 0, i32 0), i64 %type_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %type_str_null_check = icmp eq i8* %type_str, null
    %type_len_zero_check = icmp eq i64 %type_len, 0
    %type_invalid_check = or i1 %type_str_null_check, %type_len_zero_check
    br i1 %type_invalid_check, label %print_type_null, label %print_type_valid
    
print_type_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %check_context
    
print_type_valid:
    ; Print type string for debugging
    ; Debug: Print length first (already printed in entry, but keep for consistency)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_type_len, i32 0, i32 0), i64 %type_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %type_len_plus1_debug = add i64 %type_len, 1
    %type_buf_debug = call i8* @malloc(i64 %type_len_plus1_debug)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %type_buf_debug, i8* %type_str, i64 %type_len, i1 false)
    %type_null_ptr_debug = getelementptr i8, i8* %type_buf_debug, i64 %type_len
    store i8 0, i8* %type_null_ptr_debug
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_type_fmt, i32 0, i32 0), i8* %type_buf_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call void @free(i8* %type_buf_debug)
    br label %check_context
    
check_context:
    ; Get LLVM context from CodeGen
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    ; Check for null context
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %error, label %check_void
    
check_named_type:
    ; Check if type is a named type (fallback after all built-in types checked)
    ; Note: Parser already stripped % prefix, lexer already stripped bars
    ; So we receive "TypeName" or "TypeName*" format
    
    ; Debug: Print first char
    %first_char_named = load i8, i8* %type_str
    %first_char_int = zext i8 %first_char_named to i32
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_first_char, i32 0, i32 0), i32 %first_char_int)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if type ends with '*' (pointer to named type)
    %last_char_idx = sub i64 %type_len, 1
    %last_char_ptr = getelementptr i8, i8* %type_str, i64 %last_char_idx
    %last_char = load i8, i8* %last_char_ptr
    %is_pointer = icmp eq i8 %last_char, 42  ; '*' = 42
    br i1 %is_pointer, label %lookup_named_type_ptr, label %lookup_named_type_direct
    
lookup_named_type_ptr:
    ; Type is "TypeName*" - extract "TypeName" (skip last '*')
    %name_len_ptr_val = sub i64 %type_len, 1
    br label %lookup_named_type_common
    
lookup_named_type_direct:
    ; Type is "TypeName" - use full length
    %name_len_direct_val = add i64 %type_len, 0
    br label %lookup_named_type_common
    
lookup_named_type_common:
    ; Merge name length from both paths
    %name_len = phi i64 [ %name_len_ptr_val, %lookup_named_type_ptr ], [ %name_len_direct_val, %lookup_named_type_direct ]
    %is_pointer_flag = phi i1 [ %is_pointer, %lookup_named_type_ptr ], [ %is_pointer, %lookup_named_type_direct ]
    
    ; Create null-terminated name for lookup
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %type_str, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    
    ; Look up type by name
    %resolved_type = call %LLVMTypeRef @codegen_get_type(%CodeGen* %cg, i8* %name_buf, i64 %name_len)
    call void @free(i8* %name_buf)
    
    %resolved_null = icmp eq %LLVMTypeRef %resolved_type, null
    br i1 %resolved_null, label %error, label %check_if_pointer
    
check_if_pointer:
    ; If original type ended with '*', create pointer type
    br i1 %is_pointer_flag, label %create_pointer_type, label %return_named_type
    
create_pointer_type:
    %pointer_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %resolved_type, i32 0)
    %pointer_null = icmp eq %LLVMTypeRef %pointer_type, null
    br i1 %pointer_null, label %error, label %return_pointer_type
    
return_pointer_type:
    ret %LLVMTypeRef %pointer_type
    
return_named_type:
    ret %LLVMTypeRef %resolved_type
    
check_void:
    ; Check for "void" (already normalized by lexer - bars stripped)
    %is_void_len = icmp eq i64 %type_len, 4
    br i1 %is_void_len, label %check_void_str, label %check_i8
    
check_void_str:
    ; Compare with "void" (4 chars)
    %void_str = getelementptr [5 x i8], [5 x i8]* @.str.type_void, i32 0, i32 0
    %void_cmp = call i32 @strncmp(i8* %type_str, i8* %void_str, i32 4)
    %is_void = icmp eq i32 %void_cmp, 0
    br i1 %is_void, label %return_void, label %check_i8
    
return_void:
    %void_type = call %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %void_type
    
check_i8:
    ; Check for "i8" (already normalized by lexer - bars stripped)
    %is_i8_len = icmp eq i64 %type_len, 2
    br i1 %is_i8_len, label %check_i8_str, label %check_i8_ptr
    
check_i8_str:
    %i8_str = getelementptr [3 x i8], [3 x i8]* @.str.type_i8, i32 0, i32 0
    %i8_cmp = call i32 @strncmp(i8* %type_str, i8* %i8_str, i32 2)
    %is_i8 = icmp eq i32 %i8_cmp, 0
    br i1 %is_i8, label %return_i8, label %check_i8_ptr
    
check_i8_ptr:
    ; Check for "i8*" (already normalized by lexer - bars stripped)
    %is_i8_ptr_len = icmp eq i64 %type_len, 3
    br i1 %is_i8_ptr_len, label %check_i8_ptr_str, label %check_i32
    
check_i8_ptr_str:
    %i8_ptr_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i8_ptr, i32 0, i32 0
    %i8_ptr_cmp = call i32 @strncmp(i8* %type_str, i8* %i8_ptr_str, i32 3)
    %is_i8_ptr = icmp eq i32 %i8_ptr_cmp, 0
    br i1 %is_i8_ptr, label %return_i8_ptr, label %check_i32
    
return_i8:
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i8_type
    
return_i8_ptr:
    %i8_type_base = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type_base, i32 0)
    ret %LLVMTypeRef %i8_ptr_type
    
check_i32:
    ; Check for "i32" (already normalized by lexer - bars stripped)
    %is_i32_len = icmp eq i64 %type_len, 3
    br i1 %is_i32_len, label %check_i32_str, label %check_i64
    
check_i32_str:
    %i32_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i32, i32 0, i32 0
    %i32_cmp = call i32 @strncmp(i8* %type_str, i8* %i32_str, i32 3)
    %is_i32 = icmp eq i32 %i32_cmp, 0
    br i1 %is_i32, label %return_i32, label %check_i64
    
return_i32:
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i32_type
    
check_i64:
    ; Check for "i64" (already normalized by lexer - bars stripped)
    %is_i64_len = icmp eq i64 %type_len, 3
    br i1 %is_i64_len, label %check_i64_str, label %check_array
    
check_i64_str:
    %i64_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i64, i32 0, i32 0
    %i64_cmp = call i32 @strncmp(i8* %type_str, i8* %i64_str, i32 3)
    %is_i64 = icmp eq i32 %i64_cmp, 0
    br i1 %is_i64, label %return_i64, label %check_array
    
return_i64:
    %i64_type = call %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i64_type
    
check_array:
    ; Check for array types like "[14 x i8]" (already normalized by lexer - bars stripped)
    ; Look for opening bracket '['
    %first_char = load i8, i8* %type_str
    %is_bracket = icmp eq i8 %first_char, 91  ; '[' = 91
    
    ; Debug: Print that we're checking for array
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_checking_array, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    br i1 %is_bracket, label %parse_array, label %check_named_type
    
parse_array:
    ; Parse array: "[N x i8]" format where N is a number
    ; We need to extract the number N and create an array type [N x i8]
    
    ; Find the opening bracket position (already at start of array string)
    ; Skip '[' to get to the number
    %array_start_plus1 = getelementptr i8, i8* %type_str, i64 1
    %array_len_minus1 = sub i64 %type_len, 1  ; Subtract '[' from length
    
    ; Parse the number N
    ; We'll scan for digits until we find " x "
    %num_start = alloca i8*
    store i8* %array_start_plus1, i8** %num_start
    %num_end = alloca i8*
    store i8* %array_start_plus1, i8** %num_end
    %num_value = alloca i32
    store i32 0, i32* %num_value
    %found_x = alloca i32
    store i32 0, i32* %found_x
    
    ; Simple digit parsing: look for " x " pattern
    ; For bootstrap simplicity, we'll search for " x " and parse digits before it
    br label %find_x_pattern
    
find_x_pattern:
    ; Look for " x " pattern in the string
    ; We'll use a simple approach: check if current position + 1 is ' ' and position + 2 is 'x' and position + 3 is ' '
    %current_pos_val = load i8*, i8** %num_end
    
    ; Check bounds first
    %current_offset = ptrtoint i8* %current_pos_val to i64
    %start_offset = ptrtoint i8* %array_start_plus1 to i64
    %offset = sub i64 %current_offset, %start_offset
    %max_offset = sub i64 %array_len_minus1, 3  ; Need at least 3 more chars for " x "
    %within_bounds = icmp ult i64 %offset, %max_offset
    br i1 %within_bounds, label %check_pattern, label %parse_digits
    
check_pattern:
    ; Check if current position is a digit, and if so, check if next 3 chars are " x "
    %current_char = load i8, i8* %current_pos_val
    %current_char_int = zext i8 %current_char to i32
    %is_digit_check = icmp uge i32 %current_char_int, 48  ; '0'
    %is_digit_max_check = icmp ule i32 %current_char_int, 57  ; '9'
    %is_valid_digit_check = and i1 %is_digit_check, %is_digit_max_check
    
    ; If it's a digit, check if the next 3 chars are " x "
    br i1 %is_valid_digit_check, label %check_x_pattern, label %increment_pos
    
check_x_pattern:
    %pos_plus1 = getelementptr i8, i8* %current_pos_val, i64 1
    %pos_plus2 = getelementptr i8, i8* %current_pos_val, i64 2
    %pos_plus3 = getelementptr i8, i8* %current_pos_val, i64 3
    
    %char1 = load i8, i8* %pos_plus1
    %char2 = load i8, i8* %pos_plus2
    %char3 = load i8, i8* %pos_plus3
    
    %is_space1 = icmp eq i8 %char1, 32  ; ' '
    %is_x = icmp eq i8 %char2, 120  ; 'x'
    %is_space2 = icmp eq i8 %char3, 32  ; ' '
    %both_spaces = and i1 %is_space1, %is_space2
    %found_pattern = and i1 %both_spaces, %is_x
    
    br i1 %found_pattern, label %mark_found_x, label %increment_pos
    
mark_found_x:
    ; When we find " x ", current_pos_val points to the char before the first space
    ; This is the last digit, so num_end should point to current_pos_val + 1 (the space)
    %num_end_pos = getelementptr i8, i8* %current_pos_val, i64 1
    store i8* %num_end_pos, i8** %num_end
    store i32 1, i32* %found_x
    br label %parse_digits
    
increment_pos:
    ; Move to next position
    %next_pos = getelementptr i8, i8* %current_pos_val, i64 1
    store i8* %next_pos, i8** %num_end
    br label %find_x_pattern
    
parse_digits:
    ; Parse digits from num_start to num_end
    %num_start_val = load i8*, i8** %num_start
    %num_end_val = load i8*, i8** %num_end
    %num_len_ptr = alloca i64
    %num_start_int = ptrtoint i8* %num_start_val to i64
    %num_end_int = ptrtoint i8* %num_end_val to i64
    %num_len_calc = sub i64 %num_end_int, %num_start_int
    store i64 %num_len_calc, i64* %num_len_ptr
    
    ; Simple digit parsing: convert ASCII digits to integer
    %num_len_val = load i64, i64* %num_len_ptr
    %num_len_zero = icmp eq i64 %num_len_val, 0
    br i1 %num_len_zero, label %error, label %convert_digits
    
convert_digits:
    ; Convert string of digits to integer
    ; For simplicity, handle up to 3 digits (0-999)
    %num_result = alloca i32
    store i32 0, i32* %num_result
    %digit_pos = alloca i8*
    store i8* %num_start_val, i8** %digit_pos
    %digit_count = alloca i32
    store i32 0, i32* %digit_count
    br label %digit_loop
    
digit_loop:
    %digit_pos_val = load i8*, i8** %digit_pos
    %digit_pos_end = load i8*, i8** %num_end
    %digit_pos_int = ptrtoint i8* %digit_pos_val to i64
    %digit_end_int = ptrtoint i8* %digit_pos_end to i64
    %digit_done = icmp uge i64 %digit_pos_int, %digit_end_int
    br i1 %digit_done, label %check_element_type, label %read_digit
    
read_digit:
    %digit_char = load i8, i8* %digit_pos_val
    %digit_int = zext i8 %digit_char to i32
    %is_digit = icmp uge i32 %digit_int, 48  ; '0'
    %is_digit_max = icmp ule i32 %digit_int, 57  ; '9'
    %is_valid_digit = and i1 %is_digit, %is_digit_max
    br i1 %is_valid_digit, label %accumulate_digit, label %check_element_type
    
accumulate_digit:
    %num_result_val = load i32, i32* %num_result
    %digit_value = sub i32 %digit_int, 48  ; Convert ASCII to value
    %num_result_times10 = mul i32 %num_result_val, 10
    %num_result_new = add i32 %num_result_times10, %digit_value
    store i32 %num_result_new, i32* %num_result
    
    %digit_pos_next = getelementptr i8, i8* %digit_pos_val, i64 1
    store i8* %digit_pos_next, i8** %digit_pos
    br label %digit_loop
    
check_element_type:
    ; Verify that after " x " we have "i8]"
    ; num_end points to the space before "x": ' '(+0) 'x'(+1) ' '(+2) 'i'(+3) '8'(+4) ']'(+5)
    %num_end_val_check = load i8*, i8** %num_end
    %check_pos = getelementptr i8, i8* %num_end_val_check, i64 3  ; Skip " x " to reach 'i'
    %check_char_i = load i8, i8* %check_pos
    %check_pos_plus1 = getelementptr i8, i8* %check_pos, i64 1
    %check_char_8 = load i8, i8* %check_pos_plus1
    %check_pos_plus2 = getelementptr i8, i8* %check_pos, i64 2
    %check_char_bracket = load i8, i8* %check_pos_plus2
    
    %is_i_check = icmp eq i8 %check_char_i, 105  ; 'i'
    %is_8_check = icmp eq i8 %check_char_8, 56  ; '8'
    %is_bracket_check = icmp eq i8 %check_char_bracket, 93  ; ']'
    %is_i8_check = and i1 %is_i_check, %is_8_check
    %is_i8_bracket = and i1 %is_i8_check, %is_bracket_check
    
    br i1 %is_i8_bracket, label %create_array_type, label %error
    
create_array_type:
    ; Create array type [N x i8]
    %num_result_final = load i32, i32* %num_result
    %i8_type_arr = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %array_type = call %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %i8_type_arr, i32 %num_result_final)
    ret %LLVMTypeRef %array_type
    
error:
    ret %LLVMTypeRef null
}

; Evaluate DSL expression and return LLVMValueRef
; codegen_eval_dsl_expr: Recursively evaluate DSL AST expression
; Parameters:
;   cg: Pointer to CodeGen structure
;   expr: AST node for DSL expression
; Returns: LLVMValueRef for expressions that produce values, null for statements
; Expression types:
;   - Atom (symbol): Look up as DSL primitive or parameter name
;   - Atom (string): String literal (for function names, etc.)
;   - Atom (number): Integer literal (not yet supported - would need to parse)
;   - List: Function call - first element is function name, rest are args
define %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %expr) {
entry:
    %expr_null = icmp eq %ASTNode* %expr, null
    br i1 %expr_null, label %return_null, label %check_type
    
return_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_expr_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
check_type:
    %expr_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 0
    %expr_type = load i32, i32* %expr_type_ptr
    
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_expr_type, i32 0, i32 0), i32 %expr_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if quote (type 2), atom (type 0), or list (type 1)
    %is_quote = icmp eq i32 %expr_type, 2  ; AST_QUOTE
    br i1 %is_quote, label %handle_quote, label %check_atom
    
check_atom:
    %is_atom = icmp eq i32 %expr_type, 0  ; AST_ATOM
    br i1 %is_atom, label %handle_atom, label %handle_list
    
handle_quote:
    ; Extract quoted expression from car field
    %quote_car_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 4
    %quoted_expr = load %ASTNode*, %ASTNode** %quote_car_ptr
    %quoted_expr_null = icmp eq %ASTNode* %quoted_expr, null
    br i1 %quoted_expr_null, label %return_null, label %check_quoted_atom
    
check_quoted_atom:
    ; Check if quoted expression is an atom (type 0)
    %quoted_type_ptr = getelementptr %ASTNode, %ASTNode* %quoted_expr, i32 0, i32 0
    %quoted_type = load i32, i32* %quoted_type_ptr
    %quoted_is_atom = icmp eq i32 %quoted_type, 0  ; AST_ATOM
    br i1 %quoted_is_atom, label %extract_atom_name, label %return_null
    
extract_atom_name:
    ; Extract atom name and return as special marker
    ; For now, we'll use a helper function to extract the atom name
    ; This will be used by llvm:icmp, llvm:br, llvm:label to get quoted identifiers
    ; We need to return the atom name somehow - but LLVMValueRef can't hold strings directly
    ; Instead, we'll store it in a special way that handlers can extract
    ; For now, return null and let handlers call codegen_extract_quoted_atom directly
    ; This is a limitation - we need a way to pass quoted atom names through the evaluation
    ; The handlers will check if their argument is AST_QUOTE and extract it themselves
    ret %LLVMValueRef null
    
handle_atom:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_dsl_expr_atom, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get atom value and length
    %atom_val_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 2
    %atom_val = load i8*, i8** %atom_val_ptr
    %atom_len_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 3
    %atom_len = load i64, i64* %atom_len_ptr
    
    ; Debug: Print atom value pointer and length to verify they're not corrupted
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_atom_val_ptr, i32 0, i32 0), i8* %atom_val, i64 %atom_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Print first few bytes of atom_val to verify it's not corrupted
    %atom_val_not_null = icmp ne i8* %atom_val, null
    %atom_len_gt_zero = icmp ugt i64 %atom_len, 0
    %can_print_bytes = and i1 %atom_val_not_null, %atom_len_gt_zero
    br i1 %can_print_bytes, label %print_first_bytes, label %skip_print_bytes
    
print_first_bytes:
    ; Print first 4 bytes (or fewer if atom_len < 4)
    %atom_len_ge_4 = icmp uge i64 %atom_len, 4
    br i1 %atom_len_ge_4, label %print_4_bytes, label %print_less_than_4
    
print_4_bytes:
    %byte0_ptr = getelementptr i8, i8* %atom_val, i64 0
    %byte0 = load i8, i8* %byte0_ptr
    %byte1_ptr = getelementptr i8, i8* %atom_val, i64 1
    %byte1 = load i8, i8* %byte1_ptr
    %byte2_ptr = getelementptr i8, i8* %atom_val, i64 2
    %byte2 = load i8, i8* %byte2_ptr
    %byte3_ptr = getelementptr i8, i8* %atom_val, i64 3
    %byte3 = load i8, i8* %byte3_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_atom_first_bytes, i32 0, i32 0), i8 %byte0, i8 %byte1, i8 %byte2, i8 %byte3)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %skip_print_bytes
    
print_less_than_4:
    ; For shorter atoms, just print what we have
    br label %skip_print_bytes
    
skip_print_bytes:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    
    ; Check atom type: TOKEN_IDENTIFIER (symbol), TOKEN_STRING, TOKEN_NUMBER
    ; Handle TOKEN_NUMBER (type 2) by converting to constant integer
    %is_number = icmp eq i32 %atom_type, 2  ; TOKEN_NUMBER
    br i1 %is_number, label %handle_number, label %try_resolve_symbol
    
handle_number:
    ; Parse integer from AST node
    %int_value = call i32 @codegen_parse_int_from_ast(%ASTNode* %expr)
    
    ; Get context to create i32 type
    %context_for_int_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context_for_int = load %LLVMContextRef, %LLVMContextRef* %context_for_int_ptr
    %context_for_int_null = icmp eq %LLVMContextRef %context_for_int, null
    br i1 %context_for_int_null, label %return_null, label %get_i32_type
    
get_i32_type:
    ; Get i32 type for the constant
    %i32_type_for_const = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context_for_int)
    %i32_type_for_const_null = icmp eq %LLVMTypeRef %i32_type_for_const, null
    br i1 %i32_type_for_const_null, label %return_null, label %create_int_const
    
create_int_const:
    ; Create constant integer (value is already i32, extend to i64 for API)
    %int_value_64 = zext i32 %int_value to i64
    %int_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type_for_const, i64 %int_value_64, i32 0)
    ret %LLVMValueRef %int_const
    
try_resolve_symbol:
    ; Resolution order: Check functions before parameters to avoid crashes
    ; 1. Local values (let* bindings) - most local scope
    ; 2. Functions - module-level functions (check before parameters to find function names)
    ; 3. Parameters - function parameters
    ; 4. Constants - module-level constants
    
    ; Try to resolve as local value name first (let* bindings shadow parameters)
    %local_value_first = call %LLVMValueRef @codegen_dsl_resolve_local(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %local_not_null_first = icmp ne %LLVMValueRef %local_value_first, null
    br i1 %local_not_null_first, label %return_local_first, label %try_function_first
    
return_local_first:
    ret %LLVMValueRef %local_value_first
    
try_function_first:
    ; Try to resolve as function name (before checking parameters)
    ; This prevents crashes when a function name is mistaken for a parameter
    ; Allocate space for function value and type output
    %func_value_out_first = alloca %LLVMValueRef
    %func_type_out_first = alloca %LLVMTypeRef
    %func_found_first = call i32 @codegen_get_llvm_function(%CodeGen* %cg, i8* %atom_val, i64 %atom_len, %LLVMValueRef* %func_value_out_first, %LLVMTypeRef* %func_type_out_first)
    %func_found_bool_first = icmp ne i32 %func_found_first, 0
    br i1 %func_found_bool_first, label %return_function_first, label %try_param
    
return_function_first:
    ; Get function value from output parameter
    %func_value_first = load %LLVMValueRef, %LLVMValueRef* %func_value_out_first
    ret %LLVMValueRef %func_value_first
    
try_param:
    ; Try to resolve as parameter name (after checking locals and functions)
    %param_value = call %LLVMValueRef @codegen_dsl_resolve_param(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %param_not_null = icmp ne %LLVMValueRef %param_value, null
    br i1 %param_not_null, label %return_param, label %try_constant
    
return_param:
    ; Debug: Returning parameter value from codegen_eval_dsl_expr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([35 x i8], [35 x i8]* @.str.debug_returning_from_eval, i32 0, i32 0))
    %param_value_check = icmp eq %LLVMValueRef %param_value, null
    br i1 %param_value_check, label %param_value_null_in_eval, label %return_param_ok
    
param_value_null_in_eval:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
return_param_ok:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef %param_value
    
try_constant:
    ; Try to resolve as constant name (after checking locals)
    ; Debug: Looking up constant
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_looking_up_constant, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %atom_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %constant_value = call %LLVMValueRef @codegen_get_constant(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %constant_not_null = icmp ne %LLVMValueRef %constant_value, null
    br i1 %constant_not_null, label %return_constant, label %constant_not_found
    
constant_not_found:
    ; Debug: Constant not found (locals, functions, and parameters were already checked)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_global_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.debug_name_colon_space, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %atom_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; All resolution attempts failed, return null
    br label %return_null_atom
    
return_constant:
    ; Check if constant is an array type and convert to pointer if needed
    ; Get the type of the constant (globals are pointers)
    %constant_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %constant_value)
    %constant_type_null = icmp eq %LLVMTypeRef %constant_type, null
    br i1 %constant_type_null, label %return_constant_as_is, label %check_if_array
    
check_if_array:
    ; Check if the constant type is an array
    %is_array = call i32 @codegen_is_array_type(%LLVMTypeRef %constant_type)
    %is_array_bool = icmp eq i32 %is_array, 1
    br i1 %is_array_bool, label %create_gep, label %return_constant_as_is
    
create_gep:
    ; Get builder from CodeGen structure
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %return_constant_as_is, label %get_context_for_gep
    
get_context_for_gep:
    ; Get context to create constant integers
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %return_constant_as_is, label %create_indices
    
create_indices:
    ; Get i32 type for indices
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    %i32_type_null = icmp eq %LLVMTypeRef %i32_type, null
    br i1 %i32_type_null, label %return_constant_as_is, label %create_zero_const
    
create_zero_const:
    ; Create constant zero for indices [0, 0]
    %zero_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type, i64 0, i32 0)
    %zero_const_null = icmp eq %LLVMValueRef %zero_const, null
    br i1 %zero_const_null, label %return_constant_as_is, label %allocate_indices_array
    
allocate_indices_array:
    ; Allocate array for two indices [0, 0]
    %indices_array = call i8* @malloc(i64 16)  ; 2 * 8 bytes for LLVMValueRef
    %indices_ptr = bitcast i8* %indices_array to %LLVMValueRef*
    
    ; Store first zero index
    %zero_idx0 = getelementptr %LLVMValueRef, %LLVMValueRef* %indices_ptr, i32 0
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx0
    
    ; Store second zero index
    %zero_idx1 = getelementptr %LLVMValueRef, %LLVMValueRef* %indices_ptr, i32 1
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx1
    
    ; Get the element type of the pointer (the array type)
    %array_element_type = call %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %constant_type)
    %array_element_type_null = icmp eq %LLVMTypeRef %array_element_type, null
    br i1 %array_element_type_null, label %free_indices_and_return, label %build_gep
    
build_gep:
    ; Build GEP instruction: getelementptr array_element_type, constant_type* %constant_value, [0, 0]
    ; Use empty string for name
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %constant_gep_result = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %array_element_type, %LLVMValueRef %constant_value, %LLVMValueRef* %indices_ptr, i32 2, i8* %empty_str)
    
    ; Free indices array
    call void @free(i8* %indices_array)
    
    ; Check if GEP succeeded
    %constant_gep_null = icmp eq %LLVMValueRef %constant_gep_result, null
    br i1 %constant_gep_null, label %return_constant_as_is, label %return_gep
    
free_indices_and_return:
    ; Free indices array if we couldn't get element type
    call void @free(i8* %indices_array)
    br label %return_constant_as_is
    
return_gep:
    ; Return the GEP result (pointer to first element of array)
    ret %LLVMValueRef %constant_gep_result
    
return_constant_as_is:
    ; Return constant value as-is (not an array or GEP failed)
    ret %LLVMValueRef %constant_value
    
return_null_atom:
    ret %LLVMValueRef null
    
handle_list:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_dsl_expr_list, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if this is a let* special form
    %list_car_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 4
    %list_car = load %ASTNode*, %ASTNode** %list_car_ptr
    
    %list_car_null = icmp eq %ASTNode* %list_car, null
    br i1 %list_car_null, label %return_null, label %check_let_star
    
check_let_star:
    ; Check if first element is "let*"
    %car_type_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 0
    %car_type = load i32, i32* %car_type_ptr
    %car_is_atom = icmp eq i32 %car_type, 0  ; AST_ATOM
    br i1 %car_is_atom, label %check_let_star_name, label %handle_function_call
    
check_let_star_name:
    %car_val_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 2
    %car_val = load i8*, i8** %car_val_ptr
    %car_len_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 3
    %car_len = load i64, i64* %car_len_ptr
    
    ; Check if it's "let*" (4 characters)
    %is_let_star = call i32 @codegen_dsl_check_primitive(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.let_star, i32 0, i32 0), i64 4)
    %is_let_star_bool = icmp ne i32 %is_let_star, 0
    br i1 %is_let_star_bool, label %handle_let_star, label %handle_function_call
    
handle_let_star:
    ; Debug: let* form recognized
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_let_star_recognized, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    %let_star_result = call %LLVMValueRef @codegen_eval_let_star(%CodeGen* %cg, %ASTNode* %expr)
    ret %LLVMValueRef %let_star_result
    
handle_function_call:
    ; List is a function call: (primitive-name arg1 arg2 ...)
    ; Get function name (first element)
    %func_name_node_null = icmp eq %ASTNode* %list_car, null
    br i1 %func_name_node_null, label %return_null, label %get_func_name
    
get_func_name:
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
    ; Debug logging - print primitive name
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_dsl_primitive, i32 0, i32 0))
    ; Print primitive name (create null-terminated string)
    %prim_buf_size = add i64 %func_name_len, 1
    %prim_buf = call i8* @malloc(i64 %prim_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %prim_buf, i8* %func_name, i64 %func_name_len, i1 false)
    %prim_null_ptr = getelementptr i8, i8* %prim_buf, i64 %func_name_len
    store i8 0, i8* %prim_null_ptr
    call i32 (i8*, ...) @printf(i8* %prim_buf)
    call void @free(i8* %prim_buf)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get arguments (rest of list)
    %list_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 5
    %args_list = load %ASTNode*, %ASTNode** %list_cdr_ptr
    
    ; Dispatch to appropriate primitive handler
    ; Check for each primitive by name
    %is_gep = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_gep, i32 0, i32 0), i64 8)
    %is_gep_bool = icmp ne i32 %is_gep, 0
    br i1 %is_gep_bool, label %call_gep, label %check_call
    
call_gep:
    %gep_result = call %LLVMValueRef @codegen_dsl_gep(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %gep_result
    
check_call:
    %is_call = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_call, i32 0, i32 0), i64 9)
    %is_call_bool = icmp ne i32 %is_call, 0
    br i1 %is_call_bool, label %call_call, label %check_ret_void
    
call_call:
    %call_result = call %LLVMValueRef @codegen_dsl_call(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %call_result
    
check_ret_void:
    %is_ret_void = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.dsl_ret_void, i32 0, i32 0), i64 13)
    %is_ret_void_bool = icmp ne i32 %is_ret_void, 0
    br i1 %is_ret_void_bool, label %call_ret_void, label %check_ret
    
call_ret_void:
    %ret_void_result = call %LLVMValueRef @codegen_dsl_ret_void(%CodeGen* %cg)
    ret %LLVMValueRef %ret_void_result
    
check_ret:
    %is_ret = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_ret, i32 0, i32 0), i64 8)
    %is_ret_bool = icmp ne i32 %is_ret, 0
    br i1 %is_ret_bool, label %call_ret, label %check_get_global
    
call_ret:
    %ret_result = call %LLVMValueRef @codegen_dsl_ret(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %ret_result
    
check_get_global:
    %is_get_global = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([16 x i8], [16 x i8]* @.str.dsl_get_global, i32 0, i32 0), i64 15)
    %is_get_global_bool = icmp ne i32 %is_get_global, 0
    br i1 %is_get_global_bool, label %call_get_global, label %check_get_function
    
call_get_global:
    %get_global_result = call %LLVMValueRef @codegen_dsl_get_global(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_global_result
    
check_get_function:
    %is_get_function = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.dsl_get_function, i32 0, i32 0), i64 17)
    %is_get_function_bool = icmp ne i32 %is_get_function, 0
    br i1 %is_get_function_bool, label %call_get_function, label %check_get_param
    
call_get_function:
    %get_function_result = call %LLVMValueRef @codegen_dsl_get_function(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_function_result
    
check_get_param:
    %is_get_param = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.dsl_get_param, i32 0, i32 0), i64 14)
    %is_get_param_bool = icmp ne i32 %is_get_param, 0
    br i1 %is_get_param_bool, label %call_get_param, label %check_const_int
    
call_get_param:
    %get_param_result = call %LLVMValueRef @codegen_dsl_get_param(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_param_result
    
check_const_int:
    %is_const_int = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.dsl_const_int, i32 0, i32 0), i64 14)
    %is_const_int_bool = icmp ne i32 %is_const_int, 0
    br i1 %is_const_int_bool, label %call_const_int, label %check_const_null
    
call_const_int:
    %const_int_result = call %LLVMValueRef @codegen_dsl_const_int(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %const_int_result
    
check_const_null:
    %is_const_null = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([16 x i8], [16 x i8]* @.str.dsl_const_null, i32 0, i32 0), i64 15)
    %is_const_null_bool = icmp ne i32 %is_const_null, 0
    br i1 %is_const_null_bool, label %call_const_null, label %check_list
    
call_const_null:
    %const_null_result = call %LLVMValueRef @codegen_dsl_const_null(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %const_null_result
    
check_list:
    ; Check for "list" form - evaluates arguments and returns them as a list structure
    ; For now, "list" is handled by evaluating arguments directly
    ; The list structure in AST is already correct for passing to functions
    ; So we just evaluate the list normally (which will fail for unknown primitives)
    ; Actually, "list" should be handled specially - it creates a list of evaluated values
    %is_list = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.dsl_list, i32 0, i32 0), i64 4)
    %is_list_bool = icmp ne i32 %is_list, 0
    br i1 %is_list_bool, label %handle_list_form, label %check_array
    
handle_list_form:
    ; For "list" form, we just return the args_list as-is
    ; The caller will evaluate each element when needed
    ; Actually, we can't return an AST node as LLVMValueRef
    ; So "list" needs special handling in the caller
    ; For now, return null and handle it in the caller
    ret %LLVMValueRef null
    
check_array:
    ; Check for "llvm:array" form - evaluates arguments and returns them as an array
    ; Similar to "list" but semantically correct for LLVM argument arrays
    %is_llvm_array = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_array, i32 0, i32 0), i64 10)
    %is_llvm_array_bool = icmp ne i32 %is_llvm_array, 0
    br i1 %is_llvm_array_bool, label %handle_array_form, label %check_bitcast
    
check_bitcast:
    ; Check for "llvm:bitcast" form
    %is_bitcast = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.dsl_bitcast, i32 0, i32 0), i64 12)
    %is_bitcast_bool = icmp ne i32 %is_bitcast, 0
    br i1 %is_bitcast_bool, label %call_bitcast, label %check_store
    
call_bitcast:
    %bitcast_result = call %LLVMValueRef @codegen_dsl_bitcast(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %bitcast_result
    
check_store:
    ; Check for "llvm:store" form
    %is_store = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_store, i32 0, i32 0), i64 10)
    %is_store_bool = icmp ne i32 %is_store, 0
    br i1 %is_store_bool, label %call_store, label %check_load
    
call_store:
    %store_result = call %LLVMValueRef @codegen_dsl_store(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %store_result
    
check_load:
    ; Check for "llvm:load" form
    %is_load = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_load, i32 0, i32 0), i64 9)
    %is_load_bool = icmp ne i32 %is_load, 0
    br i1 %is_load_bool, label %call_load, label %check_icmp
    
call_load:
    %load_result = call %LLVMValueRef @codegen_dsl_load(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %load_result
    
check_icmp:
    ; Check for "llvm:icmp" form
    %is_icmp = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_icmp, i32 0, i32 0), i64 9)
    %is_icmp_bool = icmp ne i32 %is_icmp, 0
    br i1 %is_icmp_bool, label %call_icmp, label %check_br
    
call_icmp:
    %icmp_result = call %LLVMValueRef @codegen_dsl_icmp(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %icmp_result
    
check_br:
    ; Check for "llvm:br" form
    %is_br = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.dsl_br, i32 0, i32 0), i64 7)
    %is_br_bool = icmp ne i32 %is_br, 0
    br i1 %is_br_bool, label %call_br, label %check_zext
    
call_br:
    %br_result = call %LLVMValueRef @codegen_dsl_br(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %br_result
    
check_zext:
    ; Check for "llvm:zext" form
    %is_zext = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_zext, i32 0, i32 0), i64 9)
    %is_zext_bool = icmp ne i32 %is_zext, 0
    br i1 %is_zext_bool, label %call_zext, label %check_add
    
call_zext:
    %zext_result = call %LLVMValueRef @codegen_dsl_zext(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %zext_result
    
check_add:
    ; Check for "llvm:add" form
    %is_add = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_add, i32 0, i32 0), i64 8)
    %is_add_bool = icmp ne i32 %is_add, 0
    br i1 %is_add_bool, label %call_add, label %check_or
    
call_add:
    %add_result = call %LLVMValueRef @codegen_dsl_add(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %add_result
    
check_or:
    ; Check for "llvm:or" form
    %is_or = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.dsl_or, i32 0, i32 0), i64 7)
    %is_or_bool = icmp ne i32 %is_or, 0
    br i1 %is_or_bool, label %call_or, label %check_label
    
call_or:
    %or_result = call %LLVMValueRef @codegen_dsl_or(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %or_result
    
check_label:
    ; Check for "llvm:label" form
    %is_label = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_label, i32 0, i32 0), i64 10)
    %is_label_bool = icmp ne i32 %is_label, 0
    br i1 %is_label_bool, label %call_label, label %check_alloca
    
call_label:
    %label_result = call %LLVMValueRef @codegen_dsl_label(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %label_result
    
check_alloca:
    %is_alloca = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.dsl_alloca, i32 0, i32 0), i64 11)
    %is_alloca_bool = icmp ne i32 %is_alloca, 0
    br i1 %is_alloca_bool, label %call_alloca, label %check_sub

call_alloca:
    %alloca_result = call %LLVMValueRef @codegen_dsl_alloca(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %alloca_result

check_sub:
    %is_sub = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_sub, i32 0, i32 0), i64 8)
    %is_sub_bool = icmp ne i32 %is_sub, 0
    br i1 %is_sub_bool, label %call_sub, label %check_and

call_sub:
    %sub_result = call %LLVMValueRef @codegen_dsl_sub(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %sub_result

check_and:
    %is_and = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_and, i32 0, i32 0), i64 8)
    %is_and_bool = icmp ne i32 %is_and, 0
    br i1 %is_and_bool, label %call_and, label %check_mul

call_and:
    %and_result = call %LLVMValueRef @codegen_dsl_and(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %and_result

check_mul:
    %is_mul = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_mul, i32 0, i32 0), i64 8)
    %is_mul_bool = icmp ne i32 %is_mul, 0
    br i1 %is_mul_bool, label %call_mul, label %check_trunc

call_mul:
    %mul_result = call %LLVMValueRef @codegen_dsl_mul(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %mul_result

check_trunc:
    %is_trunc = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_trunc, i32 0, i32 0), i64 10)
    %is_trunc_bool = icmp ne i32 %is_trunc, 0
    br i1 %is_trunc_bool, label %call_trunc, label %check_select

call_trunc:
    %trunc_result = call %LLVMValueRef @codegen_dsl_trunc(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %trunc_result

check_select:
    %is_select = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.dsl_select, i32 0, i32 0), i64 11)
    %is_select_bool = icmp ne i32 %is_select, 0
    br i1 %is_select_bool, label %call_select, label %check_phi

call_select:
    %select_result = call %LLVMValueRef @codegen_dsl_select(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %select_result

check_phi:
    %is_phi = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_phi, i32 0, i32 0), i64 8)
    %is_phi_bool = icmp ne i32 %is_phi, 0
    br i1 %is_phi_bool, label %call_phi, label %check_undef

call_phi:
    %phi_result = call %LLVMValueRef @codegen_dsl_phi(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %phi_result

check_undef:
    %is_undef = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_undef, i32 0, i32 0), i64 10)
    %is_undef_bool = icmp ne i32 %is_undef, 0
    br i1 %is_undef_bool, label %call_undef, label %check_insertvalue

call_undef:
    %undef_result = call %LLVMValueRef @codegen_dsl_undef(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %undef_result

check_insertvalue:
    %is_insertvalue = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.dsl_insertvalue, i32 0, i32 0), i64 16)
    %is_insertvalue_bool = icmp ne i32 %is_insertvalue, 0
    br i1 %is_insertvalue_bool, label %call_insertvalue, label %check_extractvalue

call_insertvalue:
    %insertvalue_result = call %LLVMValueRef @codegen_dsl_insertvalue(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %insertvalue_result

check_extractvalue:
    %is_extractvalue = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.dsl_extractvalue, i32 0, i32 0), i64 17)
    %is_extractvalue_bool = icmp ne i32 %is_extractvalue, 0
    br i1 %is_extractvalue_bool, label %call_extractvalue, label %check_urem

call_extractvalue:
    %extractvalue_result = call %LLVMValueRef @codegen_dsl_extractvalue(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %extractvalue_result

check_urem:
    ; Check for "llvm:urem" form
    %is_urem = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_urem, i32 0, i32 0), i64 9)
    %is_urem_bool = icmp ne i32 %is_urem, 0
    br i1 %is_urem_bool, label %call_urem, label %check_udiv

call_urem:
    %urem_result = call %LLVMValueRef @codegen_dsl_urem(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %urem_result

check_udiv:
    ; Check for "llvm:udiv" form
    %is_udiv = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_udiv, i32 0, i32 0), i64 9)
    %is_udiv_bool = icmp ne i32 %is_udiv, 0
    br i1 %is_udiv_bool, label %call_udiv, label %check_ptrtoint

call_udiv:
    %udiv_result = call %LLVMValueRef @codegen_dsl_udiv(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %udiv_result

check_ptrtoint:
    ; Check for "llvm:ptrtoint" form
    %is_ptrtoint = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.dsl_ptrtoint, i32 0, i32 0), i64 13)
    %is_ptrtoint_bool = icmp ne i32 %is_ptrtoint, 0
    br i1 %is_ptrtoint_bool, label %call_ptrtoint, label %unknown_primitive

call_ptrtoint:
    %ptrtoint_result = call %LLVMValueRef @codegen_dsl_ptrtoint(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %ptrtoint_result

handle_array_form:
    ; For "llvm-array" form, we return null and let the caller handle it
    ; The caller (codegen_dsl_call) will evaluate each element when needed
    ret %LLVMValueRef null
    
unknown_primitive:
    ; Unknown primitive - return null (error case)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_unknown_primitive, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
}

; codegen_dsl_check_primitive: defined in codegen.vibe
declare i32 @codegen_dsl_check_primitive(i8*, i64, i8*, i64)

; Resolve parameter name to LLVMValueRef
; codegen_dsl_resolve_param: Look up parameter by name
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Parameter name
;   name_len: Name length
; Returns: LLVMValueRef for parameter, or null if not found
define %LLVMValueRef @codegen_dsl_resolve_param(%CodeGen* %cg, i8* %name, i64 %name_len) {
entry:
    ; Safety checks: validate input parameters before proceeding
    ; Check if name pointer is null
    %name_is_null = icmp eq i8* %name, null
    br i1 %name_is_null, label %return_null_safety, label %check_name_len
    
return_null_safety:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_name_null_check, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
check_name_len:
    ; Check if name_len is within reasonable bounds (max 1000 characters)
    %name_len_too_large = icmp ugt i64 %name_len, 1000
    br i1 %name_len_too_large, label %return_null_bounds, label %debug_and_proceed
    
return_null_bounds:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([45 x i8], [45 x i8]* @.str.debug_name_len_bounds_check, i32 0, i32 0), i64 %name_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
debug_and_proceed:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_resolving_param, i32 0, i32 0))
    ; Debug: Print name pointer and length before malloc
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_atom_val_ptr, i32 0, i32 0), i8* %name, i64 %name_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; Print name (check malloc result)
    %name_len_plus1_debug = add i64 %name_len, 1
    %name_buf_debug = call i8* @malloc(i64 %name_len_plus1_debug)
    %name_buf_debug_null = icmp eq i8* %name_buf_debug, null
    br i1 %name_buf_debug_null, label %skip_name_print, label %copy_name
    
copy_name:
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf_debug, i8* %name, i64 %name_len, i1 false)
    %name_null_debug = getelementptr i8, i8* %name_buf_debug, i64 %name_len
    store i8 0, i8* %name_null_debug
    call i32 (i8*, ...) @printf(i8* %name_buf_debug)
    call void @free(i8* %name_buf_debug)
    br label %skip_name_print
    
skip_name_print:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get param_names list from CodeGen
    %param_names_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 9
    %param_names = load %ASTNode*, %ASTNode** %param_names_ptr
    
    %param_names_null = icmp eq %ASTNode* %param_names, null
    br i1 %param_names_null, label %not_found_debug, label %search_params
    
not_found_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_param_names_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found
    
search_params:
    ; param_names is a list of (name index) pairs
    ; For now, we'll use a simple linear search
    ; TODO: Optimize with hash table if needed
    
    ; Get current function
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %current_function = load %LLVMValueRef, %LLVMValueRef* %current_function_ptr
    
    %func_null = icmp eq %LLVMValueRef %current_function, null
    br i1 %func_null, label %not_found_func_debug, label %iterate_params
    
not_found_func_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([33 x i8], [33 x i8]* @.str.debug_current_func_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found
    
iterate_params:
    ; Iterate through param_names list to find matching name
    %current_pair = alloca %ASTNode*
    store %ASTNode* %param_names, %ASTNode** %current_pair
    %index = alloca i32
    store i32 0, i32* %index
    br label %search_loop
    
search_loop:
    %pair_val = load %ASTNode*, %ASTNode** %current_pair
    %pair_null = icmp eq %ASTNode* %pair_val, null
    br i1 %pair_null, label %not_found, label %check_pair
    
check_pair:
    ; param_names is a list created with codegen_create_cons, so each element is:
    ; ((name . (index . nil)) . rest)
    ; We need to get the car to get the actual (name . (index . nil)) pair
    %actual_pair_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 4
    %actual_pair = load %ASTNode*, %ASTNode** %actual_pair_ptr
    %actual_pair_null = icmp eq %ASTNode* %actual_pair, null
    br i1 %actual_pair_null, label %next_pair, label %continue_check_pair
    
continue_check_pair:
    ; Debug: Check pair structure
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_checking_pair, i32 0, i32 0))
    %pair_cdr_debug_ptr = getelementptr %ASTNode, %ASTNode* %actual_pair, i32 0, i32 5
    %pair_cdr_debug = load %ASTNode*, %ASTNode** %pair_cdr_debug_ptr
    %pair_cdr_debug_null = icmp eq %ASTNode* %pair_cdr_debug, null
    br i1 %pair_cdr_debug_null, label %pair_cdr_debug_null_msg, label %pair_cdr_debug_ok
    
pair_cdr_debug_null_msg:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %continue_check_pair_after_debug
    
pair_cdr_debug_ok:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %continue_check_pair_after_debug
    
continue_check_pair_after_debug:
    ; actual_pair is (name . (index . nil))
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %actual_pair, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %name_node_null_check = icmp eq %ASTNode* %name_node, null
    br i1 %name_node_null_check, label %next_pair, label %debug_name_node
    
debug_name_node:
    ; Debug: Print name node info when retrieving
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([31 x i8], [31 x i8]* @.str.debug_retrieving_name_node, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if name node is a list - if so, extract the atom from it
    %name_node_type_check_retrieve = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 0
    %name_node_type_retrieve = load i32, i32* %name_node_type_check_retrieve
    %is_list_retrieve = icmp eq i32 %name_node_type_retrieve, 1  ; AST_LIST
    br i1 %is_list_retrieve, label %extract_atom_from_list, label %get_stored_name
    
extract_atom_from_list:
    ; Extract atom from list (car of the list)
    %list_car_retrieve_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 4
    %list_car_retrieve = load %ASTNode*, %ASTNode** %list_car_retrieve_ptr
    %list_car_retrieve_null = icmp eq %ASTNode* %list_car_retrieve, null
    br i1 %list_car_retrieve_null, label %next_pair, label %check_car_is_atom
    
check_car_is_atom:
    ; Check if car is an atom
    %list_car_type_retrieve_ptr = getelementptr %ASTNode, %ASTNode* %list_car_retrieve, i32 0, i32 0
    %list_car_type_retrieve = load i32, i32* %list_car_type_retrieve_ptr
    %list_car_is_atom_retrieve = icmp eq i32 %list_car_type_retrieve, 0  ; AST_ATOM
    br i1 %list_car_is_atom_retrieve, label %use_extracted_atom, label %next_pair
    
use_extracted_atom:
    ; Use the extracted atom as the name node
    br label %get_stored_name_common
    
get_stored_name:
    br label %get_stored_name_common
    
get_stored_name_common:
    %name_node_final = phi %ASTNode* [ %name_node, %get_stored_name ], [ %list_car_retrieve, %use_extracted_atom ]
    
    ; Debug: Check name node structure
    %name_node_type_ptr = getelementptr %ASTNode, %ASTNode* %name_node_final, i32 0, i32 0
    %name_node_type = load i32, i32* %name_node_type_ptr
    %name_node_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %name_node_final, i32 0, i32 1
    %name_node_atom_type = load i32, i32* %name_node_atom_type_ptr
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([31 x i8], [31 x i8]* @.str.debug_name_node_type, i32 0, i32 0), i32 %name_node_type, i32 %name_node_atom_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node_final, i32 0, i32 2
    %stored_name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node_final, i32 0, i32 3
    %stored_name_len = load i64, i64* %name_len_ptr
    
    ; Debug logging - compare names (check if stored_name is null first)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_comparing_names, i32 0, i32 0))
    %stored_name_is_null = icmp eq i8* %stored_name, null
    %stored_len_is_zero = icmp eq i64 %stored_name_len, 0
    %cannot_print_stored = or i1 %stored_name_is_null, %stored_len_is_zero
    br i1 %cannot_print_stored, label %print_stored_null_or_empty, label %print_stored_value
    
print_stored_null_or_empty:
    %is_null_msg = select i1 %stored_name_is_null, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0), i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str.debug_empty_str, i32 0, i32 0)
    call i32 (i8*, ...) @printf(i8* %is_null_msg)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %compare_done
    
print_stored_value:
    ; Print stored name if it exists
    %stored_name_len_plus1 = add i64 %stored_name_len, 1
    %stored_name_buf = call i8* @malloc(i64 %stored_name_len_plus1)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %stored_name_buf, i8* %stored_name, i64 %stored_name_len, i1 false)
    %stored_name_null_ptr = getelementptr i8, i8* %stored_name_buf, i64 %stored_name_len
    store i8 0, i8* %stored_name_null_ptr
    call i32 (i8*, ...) @printf(i8* %stored_name_buf)
    call void @free(i8* %stored_name_buf)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %compare_done
    
compare_done:
    ; Compare names (only if stored_name is valid - not null and len > 0)
    ; We already checked stored_name_is_null and stored_len_is_zero above
    ; If either is true, we can't compare, so go to next_pair
    br i1 %cannot_print_stored, label %next_pair, label %do_compare
    
do_compare:
    %len_match = icmp eq i64 %name_len, %stored_name_len
    br i1 %len_match, label %compare_names, label %next_pair
    
compare_names:
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %name, i8* %stored_name, i32 %name_len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %found, label %next_pair
    
found:
    ; Debug logging - parameter found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.debug_param_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get param_value from pair
    ; actual_pair structure: (name . (index . nil)) where index is stored in a list node
    ; So we need to get cdr (which is a list), then get car of that list to get the index node
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %actual_pair, i32 0, i32 5
    %pair_cdr_list = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    %pair_cdr_list_null = icmp eq %ASTNode* %pair_cdr_list, null
    br i1 %pair_cdr_list_null, label %param_value_node_is_null, label %get_index_from_list
    
get_index_from_list:
    ; Get the actual index node from the list (car of the cdr list)
    %index_list_car_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr_list, i32 0, i32 4
    %param_value_node = load %ASTNode*, %ASTNode** %index_list_car_ptr
    
    ; Debug logging - check if param_value_node is null
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.debug_checking_pair_cdr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    %param_value_node_null = icmp eq %ASTNode* %param_value_node, null
    br i1 %param_value_node_null, label %param_value_node_is_null, label %extract_param_value
    
param_value_node_is_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found
    
extract_param_value:
    ; Check if it's a pointer node (atom_type 999) or an integer node (stored index)
    %param_value_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %param_value_node, i32 0, i32 1
    %param_value_atom_type = load i32, i32* %param_value_atom_type_ptr
    
    ; Debug: Print atom type
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([26 x i8], [26 x i8]* @.str.debug_param_atom_type, i32 0, i32 0), i32 %param_value_atom_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %is_pointer = icmp eq i32 %param_value_atom_type, 999
    br i1 %is_pointer, label %cast_back_param, label %check_if_index
    
check_if_index:
    ; If it's not a pointer, it might be an integer (index) that we stored
    ; Check if it's a number atom (TOKEN_NUMBER = 2)
    %is_number = icmp eq i32 %param_value_atom_type, 2  ; TOKEN_NUMBER
    br i1 %is_number, label %lookup_by_index, label %not_found_index_type
    
not_found_index_type:
    ; Debug: Not a number type, can't resolve
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([39 x i8], [39 x i8]* @.str.debug_param_not_number_type, i32 0, i32 0), i32 %param_value_atom_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found
    
lookup_by_index:
    ; Extract index from the node
    %index_str_ptr = getelementptr %ASTNode, %ASTNode* %param_value_node, i32 0, i32 2
    %index_str = load i8*, i8** %index_str_ptr
    %index_from_ast = call i32 @codegen_parse_int_from_ast(%ASTNode* %param_value_node)
    
    ; Get current function and look up parameter by index
    %current_function_ptr_lookup = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %current_function_lookup = load %LLVMValueRef, %LLVMValueRef* %current_function_ptr_lookup
    %func_null_lookup = icmp eq %LLVMValueRef %current_function_lookup, null
    br i1 %func_null_lookup, label %not_found, label %get_param_by_index
    
get_param_by_index:
    ; Debug: Count parameters first to verify function is constructed correctly
    %param_count = call i32 @llvm_count_params(%LLVMValueRef %current_function_lookup)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([29 x i8], [29 x i8]* @.str.debug_param_count, i32 0, i32 0), i32 %param_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Print index being looked up
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_getting_param_by_index, i32 0, i32 0), i32 %index_from_ast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if index is valid
    %index_valid = icmp ult i32 %index_from_ast, %param_count
    br i1 %index_valid, label %lookup_param, label %index_out_of_range
    
index_out_of_range:
    ; Debug: Index out of range
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([45 x i8], [45 x i8]* @.str.debug_index_out_of_range, i32 0, i32 0), i32 %index_from_ast, i32 %param_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found
    
lookup_param:
    ; Look up parameter by index (should work now that function is being evaluated)
    %param_lookup = call %LLVMValueRef @llvm_get_param(%LLVMValueRef %current_function_lookup, i32 %index_from_ast)
    %param_lookup_null = icmp eq %LLVMValueRef %param_lookup, null
    br i1 %param_lookup_null, label %param_lookup_failed, label %return_looked_up
    
param_lookup_failed:
    ; Debug: Parameter lookup failed
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([40 x i8], [40 x i8]* @.str.debug_param_value_null, i32 0, i32 0), i32 %index_from_ast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %not_found
    
return_looked_up:
    ; Debug logging - parameter value retrieved by index
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_param_value_ok, i32 0, i32 0), i32 %index_from_ast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check if param_lookup is actually non-null before returning
    %param_lookup_check = icmp eq %LLVMValueRef %param_lookup, null
    br i1 %param_lookup_check, label %param_lookup_still_null, label %return_param_value
    
param_lookup_still_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([40 x i8], [40 x i8]* @.str.debug_param_lookup_still_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
return_param_value:
    ; Debug: Parameter value is non-null, returning it
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([35 x i8], [35 x i8]* @.str.debug_returning_param_value, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef %param_lookup
    
cast_back_param:
    ; Extract LLVMValueRef from pointer node
    %param_value_ptr_field = getelementptr %ASTNode, %ASTNode* %param_value_node, i32 0, i32 2
    %param_value_ptr = load i8*, i8** %param_value_ptr_field
    %param_value_ref = bitcast i8* %param_value_ptr to %LLVMValueRef
    
    ; Debug logging - parameter value retrieved
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_param_value_ok, i32 0, i32 0), i32 0)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef %param_value_ref
    
next_pair:
    %index_val_inc = load i32, i32* %index
    %index_new = add i32 %index_val_inc, 1
    store i32 %index_new, i32* %index
    
    %pair_cdr_next = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 5
    %next_pair_val = load %ASTNode*, %ASTNode** %pair_cdr_next
    store %ASTNode* %next_pair_val, %ASTNode** %current_pair
    br label %search_loop
    
not_found:
    ret %LLVMValueRef null
}

; Resolve local value name to LLVMValueRef
; codegen_dsl_resolve_local: Look up local value by name
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Local value name
;   name_len: Name length
; Returns: LLVMValueRef for local value, or null if not found
define %LLVMValueRef @codegen_dsl_resolve_local(%CodeGen* %cg, i8* %name, i64 %name_len) {
entry:
    ; Debug: Looking up local value
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_local, i32 0, i32 0))
    ; Print name safely using length (create null-terminated copy)
    %name_not_null = icmp ne i8* %name, null
    %name_len_valid = icmp ugt i64 %name_len, 0
    %can_print_name = and i1 %name_not_null, %name_len_valid
    br i1 %can_print_name, label %print_name_safe, label %skip_print_name
    
print_name_safe:
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    %name_buf_null = icmp eq i8* %name_buf, null
    br i1 %name_buf_null, label %skip_print_name, label %copy_and_print
    
copy_and_print:
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    call i32 (i8*, ...) @printf(i8* %name_buf)
    call void @free(i8* %name_buf)
    br label %skip_print_name
    
skip_print_name:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get local_values list from CodeGen
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    %local_values = load %ASTNode*, %ASTNode** %local_values_ptr
    
    %local_values_null = icmp eq %ASTNode* %local_values, null
    br i1 %local_values_null, label %not_found, label %search_locals
    
search_locals:
    ; local_values is a list of cons cells: ((name1 . value1) (name2 . value2) ...)
    ; Each cons cell: car = pair (name . value), cdr = next cons cell
    %current_cons = alloca %ASTNode*
    store %ASTNode* %local_values, %ASTNode** %current_cons
    br label %search_loop
    
search_loop:
    %cons_val = load %ASTNode*, %ASTNode** %current_cons
    %cons_null = icmp eq %ASTNode* %cons_val, null
    br i1 %cons_null, label %not_found, label %get_pair_from_cons
    
get_pair_from_cons:
    ; Get pair from cons cell's car
    %cons_car_ptr = getelementptr %ASTNode, %ASTNode* %cons_val, i32 0, i32 4
    %pair_val = load %ASTNode*, %ASTNode** %cons_car_ptr
    %pair_null = icmp eq %ASTNode* %pair_val, null
    br i1 %pair_null, label %next_cons, label %check_pair
    
check_pair:
    ; pair is a list: (name value-ref-as-pointer)
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %name_node_null = icmp eq %ASTNode* %name_node, null
    br i1 %name_node_null, label %next_cons, label %get_name_from_node
    
get_name_from_node:
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %stored_name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %stored_name_len = load i64, i64* %name_len_ptr
    
    ; Compare names
    %len_match = icmp eq i64 %name_len, %stored_name_len
    br i1 %len_match, label %compare_names_local, label %next_cons
    
compare_names_local:
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %name, i8* %stored_name, i32 %name_len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %found_local, label %next_cons
    
found_local:
    ; Get value from pair (stored as pointer in AST node's value field)
    ; pair is (name . value), so cdr is a list containing value node
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 5
    %value_list = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    %value_list_null = icmp eq %ASTNode* %value_list, null
    br i1 %value_list_null, label %not_found, label %get_value_node
    
get_value_node:
    ; Get value node from list
    %value_list_car_ptr = getelementptr %ASTNode, %ASTNode* %value_list, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_list_car_ptr
    %value_node_null = icmp eq %ASTNode* %value_node, null
    br i1 %value_node_null, label %not_found, label %extract_value
    
extract_value:
    ; Extract LLVMValueRef pointer from value node's value field
    %value_ptr_ptr = getelementptr %ASTNode, %ASTNode* %value_node, i32 0, i32 2
    %value_as_ptr = load i8*, i8** %value_ptr_ptr
    %value = bitcast i8* %value_as_ptr to %LLVMValueRef
    ; Debug: Local found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_global_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef %value
    
next_cons:
    ; Move to next cons cell (cdr of current cons cell)
    %cons_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cons_val, i32 0, i32 5
    %next_cons_val = load %ASTNode*, %ASTNode** %cons_cdr_ptr
    store %ASTNode* %next_cons_val, %ASTNode** %current_cons
    br label %search_loop
    
not_found:
    ; Debug: Local not found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_local_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %name)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
}

; Bind local value to name
; codegen_dsl_bind_local: Bind a local value to a name
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Name string
;   name_len: Name length
;   value: LLVMValueRef to bind
; Note: Stores binding as (name . value) pair in local_values list
; Value is stored as pointer in AST node's value field
define void @codegen_dsl_bind_local(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef %value) {
entry:
    ; Debug: Binding local value
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_storing_constant, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %name)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create name atom node
    %name_node = call i8* @malloc(i64 48)
    %name_node_ptr = bitcast i8* %name_node to %ASTNode*
    
    ; Set node type to ATOM
    %name_type_ptr = getelementptr %ASTNode, %ASTNode* %name_node_ptr, i32 0, i32 0
    store i32 0, i32* %name_type_ptr  ; AST_ATOM
    
    ; Set atom type to IDENTIFIER
    %name_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %name_node_ptr, i32 0, i32 1
    store i32 1, i32* %name_atom_type_ptr  ; TOKEN_IDENTIFIER
    
    ; Copy name string
    %name_buf = call i8* @malloc(i64 %name_len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name, i64 %name_len, i1 false)
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node_ptr, i32 0, i32 2
    store i8* %name_buf, i8** %name_val_ptr
    
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node_ptr, i32 0, i32 3
    store i64 %name_len, i64* %name_len_ptr
    
    ; Create value node (store LLVMValueRef as pointer in value field)
    %value_node = call i8* @malloc(i64 48)
    %value_node_ptr = bitcast i8* %value_node to %ASTNode*
    
    ; Set node type to ATOM (we'll use it to store the pointer)
    %value_type_ptr = getelementptr %ASTNode, %ASTNode* %value_node_ptr, i32 0, i32 0
    store i32 0, i32* %value_type_ptr  ; AST_ATOM
    
    ; Store LLVMValueRef pointer in value field (cast to i8*)
    %value_as_ptr = bitcast %LLVMValueRef %value to i8*
    %value_val_ptr = getelementptr %ASTNode, %ASTNode* %value_node_ptr, i32 0, i32 2
    store i8* %value_as_ptr, i8** %value_val_ptr
    
    ; Create pair: (name . value)
    %pair = call i8* @malloc(i64 48)
    %pair_ptr = bitcast i8* %pair to %ASTNode*
    
    ; Set pair type to LIST
    %pair_type_ptr = getelementptr %ASTNode, %ASTNode* %pair_ptr, i32 0, i32 0
    store i32 1, i32* %pair_type_ptr  ; AST_LIST
    
    ; Set car to name node
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %pair_ptr, i32 0, i32 4
    store %ASTNode* %name_node_ptr, %ASTNode** %pair_car_ptr
    
    ; Set cdr to value node (as a list with one element)
    %value_list = call i8* @malloc(i64 48)
    %value_list_ptr = bitcast i8* %value_list to %ASTNode*
    %value_list_type_ptr = getelementptr %ASTNode, %ASTNode* %value_list_ptr, i32 0, i32 0
    store i32 1, i32* %value_list_type_ptr  ; AST_LIST
    %value_list_car_ptr = getelementptr %ASTNode, %ASTNode* %value_list_ptr, i32 0, i32 4
    store %ASTNode* %value_node_ptr, %ASTNode** %value_list_car_ptr
    %value_list_cdr_ptr = getelementptr %ASTNode, %ASTNode* %value_list_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %value_list_cdr_ptr
    
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %pair_ptr, i32 0, i32 5
    store %ASTNode* %value_list_ptr, %ASTNode** %pair_cdr_ptr
    
    ; Prepend to local_values list
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    %current_locals = load %ASTNode*, %ASTNode** %local_values_ptr
    
    ; Debug: Current locals list status
    %current_locals_null_check = icmp eq %ASTNode* %current_locals, null
    br i1 %current_locals_null_check, label %debug_locals_null, label %debug_locals_not_null
    
debug_locals_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_global_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_storing_arg, i32 0, i32 0), i32 0)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %create_cons_cell
    
debug_locals_not_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_global_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %create_cons_cell
    
create_cons_cell:
    ; Create new cons cell for prepending
    %new_cons = call i8* @malloc(i64 48)
    %new_cons_ptr = bitcast i8* %new_cons to %ASTNode*
    %new_cons_type_ptr = getelementptr %ASTNode, %ASTNode* %new_cons_ptr, i32 0, i32 0
    store i32 1, i32* %new_cons_type_ptr  ; AST_LIST
    %new_cons_car_ptr = getelementptr %ASTNode, %ASTNode* %new_cons_ptr, i32 0, i32 4
    store %ASTNode* %pair_ptr, %ASTNode** %new_cons_car_ptr
    %new_cons_cdr_ptr = getelementptr %ASTNode, %ASTNode* %new_cons_ptr, i32 0, i32 5
    store %ASTNode* %current_locals, %ASTNode** %new_cons_cdr_ptr
    
    ; Update local_values
    store %ASTNode* %new_cons_ptr, %ASTNode** %local_values_ptr
    
    ; Debug: Local value stored
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_constant_stored, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ret void
}

; codegen_parse_int_from_ast: defined in codegen.vibe
declare i32 @codegen_parse_int_from_ast(%ASTNode*)

; codegen_parse_int_string: defined in codegen.vibe
declare i32 @codegen_parse_int_string(i8*, i64)

; ============================================================================
; DSL Primitive Implementations
; ============================================================================

; llvm-gep: Build getelementptr instruction
; Signature: (llvm:gep type pointer index1 index2 ...)
; Args: type (ASTNode with type string), pointer (ASTNode), indices (ASTNode list)
define %LLVMValueRef @codegen_dsl_gep(%CodeGen* %cg, %ASTNode* %args) {
entry:
    ; Get builder
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_args
    
get_args:
    ; Extract arguments: type, pointer, indices
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_type
    
get_type:
    ; Get type argument (first element = args.car)
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    
    ; Check if type node is null
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %error, label %extract_type_string
    
extract_type_string:
    ; Extract type string from type node
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type string to LLVMTypeRef
    %gep_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %gep_type_null = icmp eq %LLVMTypeRef %gep_type, null
    br i1 %gep_type_null, label %error, label %get_pointer
    
get_pointer:
    ; Get pointer argument (second element = args.cdr.car)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %args_cdr_null = icmp eq %ASTNode* %args_cdr, null
    br i1 %args_cdr_null, label %error, label %get_pointer_node
    
get_pointer_node:
    %pointer_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %pointer_node = load %ASTNode*, %ASTNode** %pointer_node_ptr
    
    ; Check if pointer node is null
    %pointer_node_null = icmp eq %ASTNode* %pointer_node, null
    br i1 %pointer_node_null, label %error, label %eval_pointer
    
eval_pointer:
    ; Evaluate pointer expression
    %pointer = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %pointer_node)
    %pointer_null = icmp eq %LLVMValueRef %pointer, null
    br i1 %pointer_null, label %error, label %get_indices
    
get_indices:
    ; Get indices list (third element onwards = args.cdr.cdr)
    %indices_list_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 5
    %indices_list_node = load %ASTNode*, %ASTNode** %indices_list_node_ptr
    
    ; Check if indices_list_node is null (no indices provided)
    %indices_is_null = icmp eq %ASTNode* %indices_list_node, null
    br i1 %indices_is_null, label %error, label %eval_indices
    
eval_indices:
    ; Evaluate indices list to array of LLVMValueRef
    ; indices_list_node is the list (0 0) or similar
    
    ; Allocate array (max 10 indices)
    %indices_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %indices_array_ptr = bitcast i8* %indices_array to %LLVMValueRef*
    
    ; Count and evaluate indices
    %index_count = call i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %indices_list_node, %LLVMValueRef* %indices_array_ptr, i32 10)
    
    ; For now, always use empty string for name (name support can be added later)
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    br label %build_gep
    
build_gep:
    ; Validate GEP type before using it
    %gep_type_valid = icmp eq %LLVMTypeRef %gep_type, null
    br i1 %gep_type_valid, label %error, label %build_gep_inst
    
build_gep_inst:
    %index_count_int = zext i32 %index_count to i64
    %gep_result = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %gep_type, %LLVMValueRef %pointer, %LLVMValueRef* %indices_array_ptr, i32 %index_count, i8* %name_str)
    br label %free_array
    
free_array:
    ; Free indices array
    call void @free(i8* %indices_array)
    
    ret %LLVMValueRef %gep_result
    
error:
    ret %LLVMValueRef null
}

; llvm-call: Build function call instruction
; Signature: (llvm-call func-type func args name)
define %LLVMValueRef @codegen_dsl_call(%CodeGen* %cg, %ASTNode* %args) {
entry:
    ; Get builder
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_func
    
get_func:
    ; Get function value (second element - func-type is first but we'll infer it)
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_func_node
    
get_func_node:
    %func_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %func_node = load %ASTNode*, %ASTNode** %func_node_ptr
    
    ; Evaluate function expression
    %func = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %func_node)
    
    ; Debug logging - check function result
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_func_eval_result, i32 0, i32 0))
    %func_is_null_check = icmp eq %LLVMValueRef %func, null
    br i1 %func_is_null_check, label %print_func_null, label %print_func_ok
    
print_func_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    br label %print_func_done
    
print_func_ok:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    br label %print_func_done
    
print_func_done:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %get_func_type
    
get_func_type:
    ; Look up the stored function type using reverse lookup by function value
    ; This uses the exact function type that was stored when the function was
    ; retrieved via llvm-get-function or defined via define-llvm-function
    %stored_func_type = call %LLVMTypeRef @codegen_get_function_type_by_value(%CodeGen* %cg, %LLVMValueRef %func)
    %has_stored_type = icmp ne %LLVMTypeRef %stored_func_type, null
    br i1 %has_stored_type, label %use_stored_func_type, label %fallback_to_llvm_typeof
    
use_stored_func_type:
    ; Use the stored function type (preferred)
    br label %use_func_type
    
fallback_to_llvm_typeof:
    ; Fallback to LLVMTypeOf if stored type not found
    ; This should only happen for functions not stored in llvm_functions list
    %func_type_from_value = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    %func_type_from_value_null = icmp eq %LLVMTypeRef %func_type_from_value, null
    br i1 %func_type_from_value_null, label %func_type_error, label %use_func_type
    
use_func_type:
    ; Use function type from stored lookup or LLVMTypeOf fallback
    %func_type = phi %LLVMTypeRef [ %stored_func_type, %use_stored_func_type ], [ %func_type_from_value, %fallback_to_llvm_typeof ]
    
    ; Check if function type is null (shouldn't be if we got here, but be safe)
    %func_type_null = icmp eq %LLVMTypeRef %func_type, null
    br i1 %func_type_null, label %func_type_error, label %get_args_list
    
func_type_error:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_func_type_null_error, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %error
    
get_args_list:
    ; Get args list (cdr of args, which contains all arguments after the function name)
    ; args is (func-name arg1 arg2 ...), so args.cdr is (arg1 arg2 ...)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_list_raw = load %ASTNode*, %ASTNode** %args_cdr_ptr
    
    ; Debug: Log args list extraction
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_extracting_args_list, i32 0, i32 0))
    %args_list_raw_null = icmp eq %ASTNode* %args_list_raw, null
    br i1 %args_list_raw_null, label %args_list_null_debug, label %args_list_ok_debug
    
args_list_null_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_args
    
args_list_ok_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; Check if args_list is a "list" form
    %args_is_list = icmp ne %ASTNode* %args_list_raw, null
    br i1 %args_is_list, label %check_args_list_form, label %eval_args
    
check_args_list_form:
    %args_car_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 4
    %args_car = load %ASTNode*, %ASTNode** %args_car_ptr
    %args_car_type_ptr = getelementptr %ASTNode, %ASTNode* %args_car, i32 0, i32 0
    %args_car_type = load i32, i32* %args_car_type_ptr
    %is_atom_args = icmp eq i32 %args_car_type, 0
    br i1 %is_atom_args, label %check_list_name_args, label %eval_args
    
check_list_name_args:
    %list_name_args_ptr = getelementptr %ASTNode, %ASTNode* %args_car, i32 0, i32 2
    %list_name_args = load i8*, i8** %list_name_args_ptr
    %list_name_len_args_ptr = getelementptr %ASTNode, %ASTNode* %args_car, i32 0, i32 3
    %list_name_len_args = load i64, i64* %list_name_len_args_ptr
    ; Check for "llvm-array" form (preferred) or "list" form (for backward compatibility)
    %is_array_form_args = call i32 @codegen_dsl_check_primitive(i8* %list_name_args, i64 %list_name_len_args, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_array, i32 0, i32 0), i64 10)
    %is_array_form_args_bool = icmp ne i32 %is_array_form_args, 0
    br i1 %is_array_form_args_bool, label %get_array_args_call, label %check_list_form_args
    
check_list_form_args:
    ; Check for legacy "list" form (for backward compatibility)
    %is_list_form_args = call i32 @codegen_dsl_check_primitive(i8* %list_name_args, i64 %list_name_len_args, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.dsl_list, i32 0, i32 0), i64 4)
    %is_list_form_args_bool = icmp ne i32 %is_list_form_args, 0
    br i1 %is_list_form_args_bool, label %get_list_args_call, label %eval_args
    
get_array_args_call:
    ; Get arguments from llvm-array form: (llvm-array arg1 arg2 ...)
    %args_cdr_array_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 5
    %array_args_call = load %ASTNode*, %ASTNode** %args_cdr_array_ptr
    br label %eval_args
    
get_list_args_call:
    ; Get arguments from legacy list form: (list arg1 arg2 ...)
    %args_cdr_list_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 5
    %list_args_call = load %ASTNode*, %ASTNode** %args_cdr_list_ptr
    br label %eval_args
    
eval_args:
    %args_to_eval = phi %ASTNode* [ %args_list_raw, %check_args_list_form ], [ %args_list_raw, %check_list_form_args ], [ %array_args_call, %get_array_args_call ], [ %list_args_call, %get_list_args_call ], [ %args_list_raw, %args_list_null_debug ], [ %args_list_raw, %args_list_ok_debug ]
    
    ; Evaluate args list
    %args_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %args_array_ptr = bitcast i8* %args_array to %LLVMValueRef*
    %arg_count = call i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %args_to_eval, %LLVMValueRef* %args_array_ptr, i32 10)
    
    ; Get name (optional, would be after arguments if present)
    ; For now, we don't support optional names in llvm:call, so use empty string
    %name_list = alloca %ASTNode*
    store %ASTNode* null, %ASTNode** %name_list
    %name_list_val = load %ASTNode*, %ASTNode** %name_list
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %has_name = icmp ne %ASTNode* %name_list_val, null
    br i1 %has_name, label %get_name_call, label %build_call
    
get_name_call:
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %name_list_val, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name_str_val = load i8*, i8** %name_val_ptr
    br label %build_call
    
build_call:
    %name_phi_call = phi i8* [ %name_str, %eval_args ], [ %name_str_val, %get_name_call ]
    
    ; Additional safety checks before calling
    %func_check = icmp eq %LLVMValueRef %func, null
    br i1 %func_check, label %error_with_free, label %check_func_type_again
    
check_func_type_again:
    %func_type_check = icmp eq %LLVMTypeRef %func_type, null
    br i1 %func_type_check, label %error_with_free, label %do_call
    
do_call:
    ; Validate arguments array - check if any argument is null
    ; For vararg functions like printf, we need to be careful
    %arg_count_zero = icmp eq i32 %arg_count, 0
    br i1 %arg_count_zero, label %call_with_no_args, label %validate_args
    
validate_args:
    ; Check each argument for null (up to arg_count)
    %i = alloca i32
    store i32 0, i32* %i
    br label %validate_loop
    
validate_loop:
    %i_val = load i32, i32* %i
    %done_validate = icmp uge i32 %i_val, %arg_count
    br i1 %done_validate, label %args_valid, label %check_arg
    
check_arg:
    %arg_idx = getelementptr %LLVMValueRef, %LLVMValueRef* %args_array_ptr, i32 %i_val
    %arg_val = load %LLVMValueRef, %LLVMValueRef* %arg_idx
    %arg_null = icmp eq %LLVMValueRef %arg_val, null
    br i1 %arg_null, label %arg_error, label %next_arg
    
next_arg:
    %i_new = add i32 %i_val, 1
    store i32 %i_new, i32* %i
    br label %validate_loop
    
arg_error:
    ; Debug logging - null argument found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_null_arg_error, i32 0, i32 0), i32 %i_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call void @free(i8* %args_array)
    br label %error
    
args_valid:
    ; All arguments are valid, proceed with call
    br label %call_with_args
    
call_with_no_args:
    ; No arguments - pass null array pointer (LLVM allows this for 0 args)
    %call_result_no_args = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* null, i32 0, i8* %name_phi_call)
    call void @free(i8* %args_array)
    ret %LLVMValueRef %call_result_no_args
    
error_with_free:
    ; Free args_array if it was allocated before returning error
    call void @free(i8* %args_array)
    br label %error
    
call_with_args:
    ; Debug logging before call
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_building_call, i32 0, i32 0), i32 %arg_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check all parameters before call
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_checking_builder, i32 0, i32 0))
    %builder_ptr_debug = bitcast %LLVMBuilderRef %builder to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %builder_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_checking_func_type, i32 0, i32 0))
    %func_type_ptr_debug = bitcast %LLVMTypeRef %func_type to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %func_type_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_checking_func, i32 0, i32 0))
    %func_ptr_debug = bitcast %LLVMValueRef %func to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %func_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.debug_checking_args_array, i32 0, i32 0))
    %args_array_ptr_debug = bitcast %LLVMValueRef* %args_array_ptr to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %args_array_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check all arguments
    %arg_idx_debug = alloca i32
    store i32 0, i32* %arg_idx_debug
    br label %debug_args_loop
    
debug_args_loop:
    %arg_idx_val = load i32, i32* %arg_idx_debug
    %done_debug = icmp uge i32 %arg_idx_val, %arg_count
    br i1 %done_debug, label %call_after_debug, label %debug_arg
    
debug_arg:
    %arg_ptr_debug = getelementptr %LLVMValueRef, %LLVMValueRef* %args_array_ptr, i32 %arg_idx_val
    %arg_val_debug = load %LLVMValueRef, %LLVMValueRef* %arg_ptr_debug
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_arg_value_at, i32 0, i32 0), i32 %arg_idx_val)
    %arg_ptr_debug_cast = bitcast %LLVMValueRef %arg_val_debug to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %arg_ptr_debug_cast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %arg_idx_next = add i32 %arg_idx_val, 1
    store i32 %arg_idx_next, i32* %arg_idx_debug
    br label %debug_args_loop
    
call_after_debug:
    %call_result = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args_array_ptr, i32 %arg_count, i8* %name_phi_call)
    
    ; Free args array
    call void @free(i8* %args_array)
    
    ret %LLVMValueRef %call_result
    
error:
    ret %LLVMValueRef null
}

; llvm-ret-void: Build return void instruction
define %LLVMValueRef @codegen_dsl_ret_void(%CodeGen* %cg) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_current_function
    
get_current_function:
    ; Ensure we have a current function (builder should be positioned in its entry block)
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %current_function = load %LLVMValueRef, %LLVMValueRef* %current_function_ptr
    %func_null = icmp eq %LLVMValueRef %current_function, null
    br i1 %func_null, label %error, label %build_ret
    
build_ret:
    ; Build return void instruction - this should add it to the current basic block
    ; The builder should already be positioned at the end of the entry block
    ; after the previous call instruction was built
    %ret_result = call %LLVMValueRef @llvm_build_ret_void(%LLVMBuilderRef %builder)
    ; Validate that return instruction was created
    %ret_null = icmp eq %LLVMValueRef %ret_result, null
    br i1 %ret_null, label %error, label %success
    
success:
    ret %LLVMValueRef %ret_result
    
error:
    ret %LLVMValueRef null
}

; llvm-ret: Build return with value
; Signature: (llvm-ret value)
define %LLVMValueRef @codegen_dsl_ret(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_value
    
get_value:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_value
    
eval_value:
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %error, label %build_ret_val
    
build_ret_val:
    %ret_result = call %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef %builder, %LLVMValueRef %value)
    ret %LLVMValueRef %ret_result
    
error:
    ret %LLVMValueRef null
}

; llvm-get-global: Get global variable by name
; Signature: (llvm-get-global name)
define %LLVMValueRef @codegen_dsl_get_global(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %error, label %get_name_global
    
get_name_global:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_name_node
    
get_name_node:
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %name_len = load i64, i64* %name_len_ptr
    
    ; Debug: Print global name being looked up
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_looking_up_global, i32 0, i32 0))
    %name_len_plus1_global = add i64 %name_len, 1
    %name_buf_global = call i8* @malloc(i64 %name_len_plus1_global)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf_global, i8* %name, i64 %name_len, i1 false)
    %name_null_global = getelementptr i8, i8* %name_buf_global, i64 %name_len
    store i8 0, i8* %name_null_global
    call i32 (i8*, ...) @printf(i8* %name_buf_global)
    call void @free(i8* %name_buf_global)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create null-terminated name for LLVM API
    %name_buf_plus1 = add i64 %name_len, 1
    %name_buf_full = call i8* @malloc(i64 %name_buf_plus1)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf_full, i8* %name, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf_full, i64 %name_len
    store i8 0, i8* %name_null_ptr
    
    %global = call %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef %module, i8* %name_buf_full)
    call void @free(i8* %name_buf_full)
    
    ; Debug: Check if global was found
    %global_null = icmp eq %LLVMValueRef %global, null
    br i1 %global_null, label %global_not_found, label %global_found
    
global_not_found:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_global_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
global_found:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.debug_global_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef %global
    
error:
    ret %LLVMValueRef null
}

; llvm-get-function: Get function by name
; Signature: (llvm-get-function name)
define %LLVMValueRef @codegen_dsl_get_function(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %error, label %get_name_func
    
get_name_func:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_name_node_func
    
get_name_node_func:
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_node_null = icmp eq %ASTNode* %name_node, null
    br i1 %name_node_null, label %error, label %get_name_val
    
get_name_val:
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %name_len = load i64, i64* %name_len_ptr
    
    ; Debug logging - print function name being looked up
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_looking_up_func, i32 0, i32 0))
    ; Print name (create null-terminated copy for printing)
    %print_buf_size = add i64 %name_len, 1
    %print_buf = call i8* @malloc(i64 %print_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %print_buf, i8* %name, i64 %name_len, i1 false)
    %print_null_ptr = getelementptr i8, i8* %print_buf, i64 %name_len
    store i8 0, i8* %print_null_ptr
    call i32 (i8*, ...) @printf(i8* %print_buf)
    call void @free(i8* %print_buf)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create null-terminated string for lookup
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    
    %func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %name_buf)
    
    ; Debug logging - print result
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_get_function_result, i32 0, i32 0))
    %func_is_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_is_null, label %print_null, label %print_not_null
    
print_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str.debug_null, i32 0, i32 0))
    br label %print_done
    
print_not_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_not_null, i32 0, i32 0))
    br label %print_done
    
print_done:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if function was found
    %func_found = icmp ne %LLVMValueRef %func, null
    br i1 %func_found, label %store_func_type, label %func_not_found
    
store_func_type:
    ; Store function and its type for later use in llvm-call
    ; Get function type from stored mapping (if available) or from LLVMTypeOf
    %stored_func_type = call %LLVMTypeRef @codegen_get_function_type(%CodeGen* %cg, i8* %name_buf, i64 %name_len)
    %has_stored_type = icmp ne %LLVMTypeRef %stored_func_type, null
    br i1 %has_stored_type, label %use_stored_type, label %get_type_from_func
    
use_stored_type:
    ; Use stored function type
    br label %store_both
    
get_type_from_func:
    ; Fallback: get type from function value using LLVMTypeOf
    %func_type_from_value = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    br label %store_both
    
store_both:
    ; Use phi to select between stored type and type from function value
    %func_type_to_store = phi %LLVMTypeRef [ %stored_func_type, %use_stored_type ], [ %func_type_from_value, %get_type_from_func ]
    
    ; Store both function value and type for llvm-call to use
    call void @codegen_store_llvm_function(%CodeGen* %cg, i8* %name_buf, i64 %name_len, %LLVMValueRef %func, %LLVMTypeRef %func_type_to_store)
    
    ; Free name buffer
    call void @free(i8* %name_buf)
    
    ret %LLVMValueRef %func
    
func_not_found:
    ; Function not found - this is an error
    ; Print error message
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_func_not_found_error, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
error:
    ret %LLVMValueRef null
}

; llvm-get-param: Get function parameter by index
; Signature: (llvm-get-param index)
define %LLVMValueRef @codegen_dsl_get_param(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %current_function = load %LLVMValueRef, %LLVMValueRef* %current_function_ptr
    
    %func_null = icmp eq %LLVMValueRef %current_function, null
    br i1 %func_null, label %error, label %get_index
    
get_index:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_index_node
    
get_index_node:
    ; Get index node (first element of args list)
    %index_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %index_node = load %ASTNode*, %ASTNode** %index_node_ptr
    
    ; Parse index from AST node
    %index = call i32 @codegen_parse_int_from_ast(%ASTNode* %index_node)
    
    %param = call %LLVMValueRef @llvm_get_param(%LLVMValueRef %current_function, i32 %index)
    ret %LLVMValueRef %param
    
error:
    ret %LLVMValueRef null
}

; llvm-const-int: Create constant integer
; Signature: (llvm-const-int type value sign-extend)
define %LLVMValueRef @codegen_dsl_const_int(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %error, label %get_type_const
    
get_type_const:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_type_node
    
get_type_node:
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type
    %int_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %int_type_null = icmp eq %LLVMTypeRef %int_type, null
    br i1 %int_type_null, label %error, label %get_value_const
    
get_value_const:
    ; Get value (second element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    
    ; Parse value from AST node
    %value_int = call i32 @codegen_parse_int_from_ast(%ASTNode* %value_node)
    %value = zext i32 %value_int to i64
    
    ; Get sign-extend (third element, optional) - default to 0
    %args_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 5
    %sign_extend_list = load %ASTNode*, %ASTNode** %args_cdr_cdr_ptr
    %sign_extend = add i32 0, 0
    %has_sign_extend = icmp ne %ASTNode* %sign_extend_list, null
    br i1 %has_sign_extend, label %get_sign_extend, label %create_const
    
get_sign_extend:
    %sign_extend_node_ptr = getelementptr %ASTNode, %ASTNode* %sign_extend_list, i32 0, i32 4
    %sign_extend_node = load %ASTNode*, %ASTNode** %sign_extend_node_ptr
    %sign_extend_val = call i32 @codegen_parse_int_from_ast(%ASTNode* %sign_extend_node)
    br label %create_const
    
create_const:
    %sign_extend_phi = phi i32 [ %sign_extend, %get_value_const ], [ %sign_extend_val, %get_sign_extend ]
    
    %const_int = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %int_type, i64 %value, i32 %sign_extend)
    ret %LLVMValueRef %const_int
    
error:
    ret %LLVMValueRef null
}

; llvm-const-null: Create null constant
; Signature: (llvm-const-null type)
define %LLVMValueRef @codegen_dsl_const_null(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_type_null
    
get_type_null:
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type
    %null_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %null_type_null = icmp eq %LLVMTypeRef %null_type, null
    br i1 %null_type_null, label %error, label %create_null
    
create_null:
    %null_const = call %LLVMValueRef @llvm_create_constant_null(%LLVMTypeRef %null_type)
    ret %LLVMValueRef %null_const
    
error:
    ret %LLVMValueRef null
}

; llvm:bitcast: Build bitcast instruction
; Signature: (llvm:bitcast value target-type)
define %LLVMValueRef @codegen_dsl_bitcast(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_value
    
get_value:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_value
    
eval_value:
    ; Get value expression (first element)
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    
    ; Evaluate value expression
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %error, label %get_target_type
    
get_target_type:
    ; Get target type (second element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve target type
    %target_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %target_type_null = icmp eq %LLVMTypeRef %target_type, null
    br i1 %target_type_null, label %error, label %build_bitcast
    
build_bitcast:
    ; Build bitcast instruction
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %bitcast_result = call %LLVMValueRef @llvm_build_bitcast(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name_str)
    ret %LLVMValueRef %bitcast_result
    
error:
    ret %LLVMValueRef null
}

; llvm:store: Build store instruction
; Signature: (llvm:store value ptr)
define %LLVMValueRef @codegen_dsl_store(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_value
    
get_value:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_value
    
eval_value:
    ; Get value expression (first element)
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    
    ; Evaluate value expression
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %error, label %get_ptr
    
get_ptr:
    ; Get pointer expression (second element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %ptr_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %ptr_node = load %ASTNode*, %ASTNode** %ptr_node_ptr
    
    ; Evaluate pointer expression
    %ptr = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %ptr_node)
    %ptr_null = icmp eq %LLVMValueRef %ptr, null
    br i1 %ptr_null, label %error, label %build_store
    
build_store:
    ; Build store instruction (returns void, so return null)
    call void @llvm_build_store(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMValueRef %ptr)
    ret %LLVMValueRef null
    
error:
    ret %LLVMValueRef null
}

; codegen_extract_quoted_atom: defined in codegen.vibe
declare i32 @codegen_extract_quoted_atom(%ASTNode*, i8**, i64*)

; codegen_dsl_load: Handle llvm:load form
; Syntax: (llvm:load ptr type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (ptr type)
; Returns: LLVMValueRef for loaded value
define %LLVMValueRef @codegen_dsl_load(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_ptr
    
get_ptr:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_ptr
    
eval_ptr:
    ; Get ptr expression (first element)
    %ptr_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %ptr_node = load %ASTNode*, %ASTNode** %ptr_node_ptr
    %ptr = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %ptr_node)
    %ptr_null = icmp eq %LLVMValueRef %ptr, null
    br i1 %ptr_null, label %error, label %get_type
    
get_type:
    ; Get type string (second element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %error, label %extract_type_string
    
extract_type_string:
    ; Extract type string from atom node
    %type_node_type_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 0
    %type_node_type = load i32, i32* %type_node_type_ptr
    %is_atom = icmp eq i32 %type_node_type, 0  ; AST_ATOM
    br i1 %is_atom, label %get_type_string, label %error
    
get_type_string:
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_val = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type string to LLVMTypeRef
    %load_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_val, i64 %type_len)
    %load_type_null = icmp eq %LLVMTypeRef %load_type, null
    br i1 %load_type_null, label %error, label %build_load
    
build_load:
    ; Build load instruction with empty name
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %load_result = call %LLVMValueRef @llvm_build_load(%LLVMBuilderRef %builder, %LLVMTypeRef %load_type, %LLVMValueRef %ptr, i8* %empty_str)
    ret %LLVMValueRef %load_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_add: Handle llvm:add form
; Syntax: (llvm:add lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for sum
define %LLVMValueRef @codegen_dsl_add(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs
    
get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs
    
eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs
    
get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_add
    
build_add:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %add_result = call %LLVMValueRef @llvm_build_add(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %add_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_or: Handle llvm:or form
; Syntax: (llvm:or lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for result
define %LLVMValueRef @codegen_dsl_or(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs
    
get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs
    
eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs
    
get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_or
    
build_or:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %or_result = call %LLVMValueRef @llvm_build_or(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %or_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_alloca: Handle llvm:alloca form
; Syntax: (llvm:alloca type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (type)
; Returns: LLVMValueRef for allocated pointer
define %LLVMValueRef @codegen_dsl_alloca(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_type

get_type:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %extract_type

extract_type:
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %error, label %get_type_string

get_type_string:
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_val = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr

    ; Resolve type string to LLVMTypeRef
    %alloca_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_val, i64 %type_len)
    %alloca_type_null = icmp eq %LLVMTypeRef %alloca_type, null
    br i1 %alloca_type_null, label %error, label %build_alloca

build_alloca:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %alloca_result = call %LLVMValueRef @llvm_build_alloca(%LLVMBuilderRef %builder, %LLVMTypeRef %alloca_type, i8* %empty_str)
    ret %LLVMValueRef %alloca_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_sub: Handle llvm:sub form
; Syntax: (llvm:sub lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for difference
define %LLVMValueRef @codegen_dsl_sub(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs

get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs

eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs

get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_sub

build_sub:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %sub_result = call %LLVMValueRef @llvm_build_sub(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %sub_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_and: Handle llvm:and form
; Syntax: (llvm:and lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for result
define %LLVMValueRef @codegen_dsl_and(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs

get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs

eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs

get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_and

build_and:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %and_result = call %LLVMValueRef @llvm_build_and(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %and_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_mul: Handle llvm:mul form
; Syntax: (llvm:mul lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for product
define %LLVMValueRef @codegen_dsl_mul(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs

get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs

eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs

get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_mul

build_mul:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %mul_result = call %LLVMValueRef @llvm_build_mul(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %mul_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_trunc: Handle llvm:trunc form
; Syntax: (llvm:trunc value source-type target-type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (value source-type target-type)
; Returns: LLVMValueRef for truncated value
define %LLVMValueRef @codegen_dsl_trunc(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_value

get_value:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_value

eval_value:
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %error, label %get_target_type

get_target_type:
    ; Get target-type (third element, skip source-type)
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %args_cdr2_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 5
    %args_cdr2 = load %ASTNode*, %ASTNode** %args_cdr2_ptr
    %target_type_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr2, i32 0, i32 4
    %target_type_node = load %ASTNode*, %ASTNode** %target_type_node_ptr
    %target_type_node_null = icmp eq %ASTNode* %target_type_node, null
    br i1 %target_type_node_null, label %error, label %extract_target_type_string

extract_target_type_string:
    %target_type_node_type_ptr = getelementptr %ASTNode, %ASTNode* %target_type_node, i32 0, i32 0
    %target_type_node_type = load i32, i32* %target_type_node_type_ptr
    %is_atom = icmp eq i32 %target_type_node_type, 0  ; AST_ATOM
    br i1 %is_atom, label %get_target_type_string, label %error

get_target_type_string:
    %target_type_val_ptr = getelementptr %ASTNode, %ASTNode* %target_type_node, i32 0, i32 2
    %target_type_val = load i8*, i8** %target_type_val_ptr
    %target_type_len_ptr = getelementptr %ASTNode, %ASTNode* %target_type_node, i32 0, i32 3
    %target_type_len = load i64, i64* %target_type_len_ptr

    ; Resolve target type string to LLVMTypeRef
    %trunc_target_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %target_type_val, i64 %target_type_len)
    %trunc_target_type_null = icmp eq %LLVMTypeRef %trunc_target_type, null
    br i1 %trunc_target_type_null, label %error, label %build_trunc

build_trunc:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %trunc_result = call %LLVMValueRef @llvm_build_trunc(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %trunc_target_type, i8* %empty_str)
    ret %LLVMValueRef %trunc_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_select: Handle llvm:select form
; Syntax: (llvm:select cond then-value else-value)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (cond then-value else-value)
; Returns: LLVMValueRef for selected value
define %LLVMValueRef @codegen_dsl_select(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_cond

get_cond:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_cond

eval_cond:
    %cond_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %cond_node = load %ASTNode*, %ASTNode** %cond_node_ptr
    %cond = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %cond_node)
    %cond_null = icmp eq %LLVMValueRef %cond, null
    br i1 %cond_null, label %error, label %get_then

get_then:
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %then_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 4
    %then_node = load %ASTNode*, %ASTNode** %then_node_ptr
    %then_val = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %then_node)
    %then_null = icmp eq %LLVMValueRef %then_val, null
    br i1 %then_null, label %error, label %get_else

get_else:
    %args_cdr2_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 5
    %args_cdr2 = load %ASTNode*, %ASTNode** %args_cdr2_ptr
    %else_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr2, i32 0, i32 4
    %else_node = load %ASTNode*, %ASTNode** %else_node_ptr
    %else_val = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %else_node)
    %else_null = icmp eq %LLVMValueRef %else_val, null
    br i1 %else_null, label %error, label %build_select

build_select:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %select_result = call %LLVMValueRef @llvm_build_select(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMValueRef %then_val, %LLVMValueRef %else_val, i8* %empty_str)
    ret %LLVMValueRef %select_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_phi: Handle llvm:phi form
; Syntax: (llvm:phi type (value1 'label1) (value2 'label2) ...)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (type (value1 'label1) (value2 'label2) ...)
; Returns: LLVMValueRef for phi node
define %LLVMValueRef @codegen_dsl_phi(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_phi_type

get_phi_type:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %extract_phi_type

extract_phi_type:
    ; First arg is the type
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_val = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr

    %phi_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_val, i64 %type_len)
    %phi_type_null = icmp eq %LLVMTypeRef %phi_type, null
    br i1 %phi_type_null, label %error, label %build_phi_node

build_phi_node:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %phi = call %LLVMValueRef @llvm_build_phi(%LLVMBuilderRef %builder, %LLVMTypeRef %phi_type, i8* %empty_str)
    %phi_null = icmp eq %LLVMValueRef %phi, null
    br i1 %phi_null, label %error, label %get_incoming_pairs

get_incoming_pairs:
    ; Remaining args are (value 'label) pairs
    %pairs_start_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %pairs_start = load %ASTNode*, %ASTNode** %pairs_start_ptr
    br label %phi_loop

phi_loop:
    %current_pair_phi = phi %ASTNode* [ %pairs_start, %get_incoming_pairs ], [ %next_pair, %add_incoming_done ]
    %current_pair_null = icmp eq %ASTNode* %current_pair_phi, null
    br i1 %current_pair_null, label %phi_done, label %process_pair

process_pair:
    ; Get the pair list node (car is the pair list)
    %pair_node_ptr = getelementptr %ASTNode, %ASTNode* %current_pair_phi, i32 0, i32 4
    %pair_node = load %ASTNode*, %ASTNode** %pair_node_ptr
    %pair_node_null = icmp eq %ASTNode* %pair_node, null
    br i1 %pair_node_null, label %phi_done, label %extract_value_from_pair

extract_value_from_pair:
    ; pair_node is a LIST with (value 'label)
    ; Get value (car of pair)
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %pair_node, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    %incoming_value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    %incoming_value_null = icmp eq %LLVMValueRef %incoming_value, null
    br i1 %incoming_value_null, label %error, label %extract_label_from_pair

extract_label_from_pair:
    ; Get label (cadr of pair) - it's a quoted atom
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %pair_node, i32 0, i32 5
    %pair_cdr = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    %label_node_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr, i32 0, i32 4
    %label_node = load %ASTNode*, %ASTNode** %label_node_ptr

    ; Extract label name from quoted atom using output parameters
    %phi_label_name_out = alloca i8*
    %phi_label_len_out = alloca i64
    %phi_extract_result = call i32 @codegen_extract_quoted_atom(%ASTNode* %label_node, i8** %phi_label_name_out, i64* %phi_label_len_out)
    %phi_extract_failed = icmp ne i32 %phi_extract_result, 0
    br i1 %phi_extract_failed, label %error, label %get_phi_bb

get_phi_bb:
    %phi_label_name = load i8*, i8** %phi_label_name_out
    %phi_label_len = load i64, i64* %phi_label_len_out

    ; Look up the basic block by label name using get_or_create
    %phi_func_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %phi_func = load %LLVMValueRef, %LLVMValueRef* %phi_func_ptr
    %incoming_bb = call %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %phi_func, i8* %phi_label_name, i64 %phi_label_len)
    %incoming_bb_null = icmp eq %LLVMBasicBlockRef %incoming_bb, null
    br i1 %incoming_bb_null, label %error, label %add_one_incoming

add_one_incoming:
    ; Allocate arrays for one incoming value/block pair
    %val_array = alloca %LLVMValueRef
    %bb_array = alloca %LLVMBasicBlockRef
    store %LLVMValueRef %incoming_value, %LLVMValueRef* %val_array
    store %LLVMBasicBlockRef %incoming_bb, %LLVMBasicBlockRef* %bb_array
    call void @llvm_add_incoming(%LLVMValueRef %phi, %LLVMValueRef* %val_array, %LLVMBasicBlockRef* %bb_array, i32 1)
    br label %add_incoming_done

add_incoming_done:
    ; Move to next pair
    %next_pair_ptr = getelementptr %ASTNode, %ASTNode* %current_pair_phi, i32 0, i32 5
    %next_pair = load %ASTNode*, %ASTNode** %next_pair_ptr
    br label %phi_loop

phi_done:
    ret %LLVMValueRef %phi

error:
    ret %LLVMValueRef null
}

; codegen_dsl_zext: Handle llvm:zext form
; Syntax: (llvm:zext value source-type target-type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (value source-type target-type)
; Returns: LLVMValueRef for extended value
define %LLVMValueRef @codegen_dsl_zext(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_value
    
get_value:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_value
    
eval_value:
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %error, label %get_target_type
    
get_target_type:
    ; Get target-type (third element, skip source-type)
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %args_cdr2_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 5
    %args_cdr2 = load %ASTNode*, %ASTNode** %args_cdr2_ptr
    %target_type_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr2, i32 0, i32 4
    %target_type_node = load %ASTNode*, %ASTNode** %target_type_node_ptr
    %target_type_node_null = icmp eq %ASTNode* %target_type_node, null
    br i1 %target_type_node_null, label %error, label %extract_target_type_string
    
extract_target_type_string:
    %target_type_node_type_ptr = getelementptr %ASTNode, %ASTNode* %target_type_node, i32 0, i32 0
    %target_type_node_type = load i32, i32* %target_type_node_type_ptr
    %is_atom = icmp eq i32 %target_type_node_type, 0  ; AST_ATOM
    br i1 %is_atom, label %get_target_type_string, label %error
    
get_target_type_string:
    %target_type_val_ptr = getelementptr %ASTNode, %ASTNode* %target_type_node, i32 0, i32 2
    %target_type_val = load i8*, i8** %target_type_val_ptr
    %target_type_len_ptr = getelementptr %ASTNode, %ASTNode* %target_type_node, i32 0, i32 3
    %target_type_len = load i64, i64* %target_type_len_ptr
    
    ; Resolve target type string to LLVMTypeRef
    %zext_target_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %target_type_val, i64 %target_type_len)
    %zext_target_type_null = icmp eq %LLVMTypeRef %zext_target_type, null
    br i1 %zext_target_type_null, label %error, label %build_zext
    
build_zext:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %zext_result = call %LLVMValueRef @llvm_build_zext(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %zext_target_type, i8* %empty_str)
    ret %LLVMValueRef %zext_result
    
error:
    ret %LLVMValueRef null
}

; codegen_map_predicate_string: Map predicate string to LLVMIntPredicate enum
; Parameters:
;   pred_str: Predicate string (e.g., "eq", "ne", "uge")
;   pred_len: String length
; Returns: LLVMIntPredicate enum value (i32), or -1 on error
define i32 @codegen_map_predicate_string(i8* %pred_str, i64 %pred_len) {
entry:
    ; Compare with known predicates
    ; "eq" -> 32 (LLVMIntEQ)
    %is_eq = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.pred_eq, i32 0, i32 0), i64 2)
    %is_eq_bool = icmp ne i32 %is_eq, 0
    br i1 %is_eq_bool, label %return_eq, label %check_ne
    
return_eq:
    ret i32 32  ; LLVMIntEQ
    
check_ne:
    %is_ne = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.pred_ne, i32 0, i32 0), i64 2)
    %is_ne_bool = icmp ne i32 %is_ne, 0
    br i1 %is_ne_bool, label %return_ne, label %check_uge
    
return_ne:
    ret i32 33  ; LLVMIntNE
    
check_uge:
    %is_uge = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_uge, i32 0, i32 0), i64 3)
    %is_uge_bool = icmp ne i32 %is_uge, 0
    br i1 %is_uge_bool, label %return_uge, label %check_ult
    
return_uge:
    ret i32 35  ; LLVMIntUGE
    
check_ult:
    %is_ult = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_ult, i32 0, i32 0), i64 3)
    %is_ult_bool = icmp ne i32 %is_ult, 0
    br i1 %is_ult_bool, label %return_ult, label %check_ugt
    
return_ult:
    ret i32 36  ; LLVMIntULT
    
check_ugt:
    %is_ugt = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_ugt, i32 0, i32 0), i64 3)
    %is_ugt_bool = icmp ne i32 %is_ugt, 0
    br i1 %is_ugt_bool, label %return_ugt, label %check_ule
    
return_ugt:
    ret i32 34  ; LLVMIntUGT
    
check_ule:
    %is_ule = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_ule, i32 0, i32 0), i64 3)
    %is_ule_bool = icmp ne i32 %is_ule, 0
    br i1 %is_ule_bool, label %return_ule, label %check_sge
    
return_ule:
    ret i32 37  ; LLVMIntULE
    
check_sge:
    %is_sge = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_sge, i32 0, i32 0), i64 3)
    %is_sge_bool = icmp ne i32 %is_sge, 0
    br i1 %is_sge_bool, label %return_sge, label %check_slt
    
return_sge:
    ret i32 39  ; LLVMIntSGE
    
check_slt:
    %is_slt = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_slt, i32 0, i32 0), i64 3)
    %is_slt_bool = icmp ne i32 %is_slt, 0
    br i1 %is_slt_bool, label %return_slt, label %check_sgt
    
return_slt:
    ret i32 40  ; LLVMIntSLT
    
check_sgt:
    %is_sgt = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_sgt, i32 0, i32 0), i64 3)
    %is_sgt_bool = icmp ne i32 %is_sgt, 0
    br i1 %is_sgt_bool, label %return_sgt, label %check_sle
    
return_sgt:
    ret i32 38  ; LLVMIntSGT
    
check_sle:
    %is_sle = call i32 @codegen_dsl_check_primitive(i8* %pred_str, i64 %pred_len, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.pred_sle, i32 0, i32 0), i64 3)
    %is_sle_bool = icmp ne i32 %is_sle, 0
    br i1 %is_sle_bool, label %return_sle, label %error
    
return_sle:
    ret i32 41  ; LLVMIntSLE
    
error:
    ret i32 -1
}

; codegen_dsl_icmp: Handle llvm:icmp form
; Syntax: (llvm:icmp 'pred lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with ('pred lhs rhs)
; Returns: LLVMValueRef (i1 boolean) for comparison result
define %LLVMValueRef @codegen_dsl_icmp(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_pred
    
get_pred:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %check_pred_quote
    
check_pred_quote:
    ; First arg must be AST_QUOTE node
    %pred_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %pred_node = load %ASTNode*, %ASTNode** %pred_node_ptr
    %pred_node_null = icmp eq %ASTNode* %pred_node, null
    br i1 %pred_node_null, label %error, label %extract_pred
    
extract_pred:
    ; Extract predicate name from quoted atom
    %pred_name_out = alloca i8*
    %pred_len_out = alloca i64
    %extract_result = call i32 @codegen_extract_quoted_atom(%ASTNode* %pred_node, i8** %pred_name_out, i64* %pred_len_out)
    %extract_failed = icmp ne i32 %extract_result, 0
    br i1 %extract_failed, label %error, label %map_predicate
    
map_predicate:
    %pred_name = load i8*, i8** %pred_name_out
    %pred_len = load i64, i64* %pred_len_out
    %pred_enum = call i32 @codegen_map_predicate_string(i8* %pred_name, i64 %pred_len)
    %pred_invalid = icmp eq i32 %pred_enum, -1
    br i1 %pred_invalid, label %error, label %get_lhs
    
get_lhs:
    ; Get lhs (second element)
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs
    
get_rhs:
    ; Get rhs (third element)
    %args_cdr2_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 5
    %args_cdr2 = load %ASTNode*, %ASTNode** %args_cdr2_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr2, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_icmp
    
build_icmp:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %icmp_result = call %LLVMValueRef @llvm_build_icmp(%LLVMBuilderRef %builder, i32 %pred_enum, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %icmp_result
    
error:
    ret %LLVMValueRef null
}

; Label tracking structure (simple linked list node)
%LabelEntry = type { i8*, i64, %LLVMBasicBlockRef, %LabelEntry* }

; codegen_get_or_create_label: Get or create a basic block with given name
; Parameters:
;   cg: CodeGen pointer
;   func: LLVMValueRef for function
;   name: Label name string
;   name_len: Label name length
; Returns: LLVMBasicBlockRef for the label, or null on error
; Note: First checks if a block with this name already exists, then creates if needed
define %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %func, i8* %name, i64 %name_len) {
entry:
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %check_existing
    
check_existing:
    ; First, check if a block with this name already exists
    ; Iterate through all basic blocks in the function
    %first_block = call %LLVMBasicBlockRef @llvm_get_first_basic_block(%LLVMValueRef %func)
    %first_block_null = icmp eq %LLVMBasicBlockRef %first_block, null
    br i1 %first_block_null, label %create_label, label %iterate_blocks
    
iterate_blocks:
    %current_block = phi %LLVMBasicBlockRef [ %first_block, %check_existing ], [ %next_block_val, %check_next_block ]
    
    ; Get the name of the current block
    %block_name = call i8* @llvm_get_basic_block_name(%LLVMBasicBlockRef %current_block)
    %block_name_null = icmp eq i8* %block_name, null
    br i1 %block_name_null, label %check_next_block, label %compare_names
    
compare_names:
    ; Compare block name with desired name
    ; We need to compare the full strings. Since block_name is null-terminated and
    ; name is not (we have name_len), we'll compare up to name_len characters,
    ; then check that block_name is null-terminated at that position
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %block_name, i8* %name, i32 %name_len_int)
    %names_match = icmp eq i32 %cmp_result, 0
    br i1 %names_match, label %check_null_term, label %check_next_block
    
check_null_term:
    ; Check that the block name is exactly name_len characters (null-terminated at name_len)
    ; This ensures "same" matches "same" but not "same1"
    %block_name_at_len = getelementptr i8, i8* %block_name, i64 %name_len
    %block_char_at_len = load i8, i8* %block_name_at_len
    %is_null_term = icmp eq i8 %block_char_at_len, 0
    br i1 %is_null_term, label %found_existing, label %check_next_block
    
found_existing:
    ; Found an existing block with matching name - return it
    ret %LLVMBasicBlockRef %current_block
    
check_next_block:
    ; Move to next block
    %next_block_val = call %LLVMBasicBlockRef @llvm_get_next_basic_block(%LLVMBasicBlockRef %current_block)
    %next_block_null = icmp eq %LLVMBasicBlockRef %next_block_val, null
    br i1 %next_block_null, label %create_label, label %iterate_blocks
    
create_label:
    ; No existing block found - create a new one
    ; Create null-terminated name string
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    
    ; Create basic block with name
    %block = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %func, i8* %name_buf)
    
    ; Note: We don't free name_buf here because LLVM may keep a reference to it
    ; In a production system, we'd want to track allocated strings and free them later
    ret %LLVMBasicBlockRef %block
    
error:
    ret %LLVMBasicBlockRef null
}

; codegen_dsl_br: Handle llvm:br form
; Syntax: (llvm:br 'label-name) or (llvm:br cond 'then-label 'else-label)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list
; Returns: LLVMValueRef for branch instruction
define %LLVMValueRef @codegen_dsl_br(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_func
    
get_func:
    %func_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %func = load %LLVMValueRef, %LLVMValueRef* %func_ptr
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %check_args
    
check_args:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %check_first_arg
    
check_first_arg:
    ; Get first argument
    %first_arg_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %first_arg = load %ASTNode*, %ASTNode** %first_arg_ptr
    %first_arg_null = icmp eq %ASTNode* %first_arg, null
    br i1 %first_arg_null, label %error, label %check_if_quote
    
check_if_quote:
    ; Check if first arg is AST_QUOTE (unconditional) or evaluated value (conditional)
    %first_arg_type_ptr = getelementptr %ASTNode, %ASTNode* %first_arg, i32 0, i32 0
    %first_arg_type = load i32, i32* %first_arg_type_ptr
    %is_quote = icmp eq i32 %first_arg_type, 2  ; AST_QUOTE
    br i1 %is_quote, label %unconditional_br, label %conditional_br
    
unconditional_br:
    ; Extract label name from quoted atom
    %label_name_out = alloca i8*
    %label_len_out = alloca i64
    %extract_result = call i32 @codegen_extract_quoted_atom(%ASTNode* %first_arg, i8** %label_name_out, i64* %label_len_out)
    %extract_failed = icmp ne i32 %extract_result, 0
    br i1 %extract_failed, label %error, label %get_uncond_label
    
get_uncond_label:
    %label_name = load i8*, i8** %label_name_out
    %label_len = load i64, i64* %label_len_out
    %block = call %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %func, i8* %label_name, i64 %label_len)
    %block_null = icmp eq %LLVMBasicBlockRef %block, null
    br i1 %block_null, label %error, label %build_uncond_br
    
build_uncond_br:
    %br_result = call %LLVMValueRef @llvm_build_br(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %block)
    ret %LLVMValueRef %br_result
    
conditional_br:
    ; First arg is condition (already evaluated), second and third are labels
    %cond = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %first_arg)
    %cond_null = icmp eq %LLVMValueRef %cond, null
    br i1 %cond_null, label %error, label %get_then_label
    
get_then_label:
    ; Get then-label (second element, AST_QUOTE)
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %then_label_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 4
    %then_label_node = load %ASTNode*, %ASTNode** %then_label_node_ptr
    %then_label_name_out = alloca i8*
    %then_label_len_out = alloca i64
    %extract_then_result = call i32 @codegen_extract_quoted_atom(%ASTNode* %then_label_node, i8** %then_label_name_out, i64* %then_label_len_out)
    %extract_then_failed = icmp ne i32 %extract_then_result, 0
    br i1 %extract_then_failed, label %error, label %get_else_label
    
get_else_label:
    ; Get else-label (third element, AST_QUOTE)
    %args_cdr2_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 5
    %args_cdr2 = load %ASTNode*, %ASTNode** %args_cdr2_ptr
    %else_label_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr2, i32 0, i32 4
    %else_label_node = load %ASTNode*, %ASTNode** %else_label_node_ptr
    %else_label_name_out = alloca i8*
    %else_label_len_out = alloca i64
    %extract_else_result = call i32 @codegen_extract_quoted_atom(%ASTNode* %else_label_node, i8** %else_label_name_out, i64* %else_label_len_out)
    %extract_else_failed = icmp ne i32 %extract_else_result, 0
    br i1 %extract_else_failed, label %error, label %get_blocks
    
get_blocks:
    %then_label_name = load i8*, i8** %then_label_name_out
    %then_label_len = load i64, i64* %then_label_len_out
    %then_block = call %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %func, i8* %then_label_name, i64 %then_label_len)
    %then_block_null = icmp eq %LLVMBasicBlockRef %then_block, null
    br i1 %then_block_null, label %error, label %get_else_block
    
get_else_block:
    %else_label_name = load i8*, i8** %else_label_name_out
    %else_label_len = load i64, i64* %else_label_len_out
    %else_block = call %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %func, i8* %else_label_name, i64 %else_label_len)
    %else_block_null = icmp eq %LLVMBasicBlockRef %else_block, null
    br i1 %else_block_null, label %error, label %build_cond_br
    
build_cond_br:
    %cond_br_result = call %LLVMValueRef @llvm_build_cond_br(%LLVMBuilderRef %builder, %LLVMValueRef %cond, %LLVMBasicBlockRef %then_block, %LLVMBasicBlockRef %else_block)
    ret %LLVMValueRef %cond_br_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_label: Handle llvm:label form
; Syntax: (llvm:label 'name body ...)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with ('name body ...)
; Returns: LLVMValueRef (basic block)
define %LLVMValueRef @codegen_dsl_label(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_func
    
get_func:
    %func_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %func = load %LLVMValueRef, %LLVMValueRef* %func_ptr
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %get_name
    
get_name:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %extract_name
    
extract_name:
    ; First arg must be AST_QUOTE node with label name
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_node_null = icmp eq %ASTNode* %name_node, null
    br i1 %name_node_null, label %error, label %extract_atom_name
    
extract_atom_name:
    %label_name_out = alloca i8*
    %label_len_out = alloca i64
    %extract_result = call i32 @codegen_extract_quoted_atom(%ASTNode* %name_node, i8** %label_name_out, i64* %label_len_out)
    %extract_failed = icmp ne i32 %extract_result, 0
    br i1 %extract_failed, label %error, label %get_or_create_block
    
get_or_create_block:
    %label_name = load i8*, i8** %label_name_out
    %label_len = load i64, i64* %label_len_out
    %block = call %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %func, i8* %label_name, i64 %label_len)
    %block_null = icmp eq %LLVMBasicBlockRef %block, null
    br i1 %block_null, label %error, label %position_builder
    
position_builder:
    ; Save current builder position before positioning at label block
    ; This allows us to restore it after evaluating the label body
    %saved_block = call %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder)
    
    ; Position builder at end of label block
    ; Note: This must happen BEFORE evaluating the body so instructions go into the label block
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %block)
    
    ; Get body (rest of args)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %body = load %ASTNode*, %ASTNode** %args_cdr_ptr
    
    ; Evaluate body expressions (void version - we don't need the return value)
    ; The builder should now be positioned at the label block, so instructions will go there
    call void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %body)
    
    ; Visitor pattern exit check: verify the label's block has a terminator
    ; We check the label's own block (%block), NOT the current insert block,
    ; because nested labels may have moved the builder to a different block.
    %label_terminator = call %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef %block)
    %label_has_no_term = icmp eq %LLVMValueRef %label_terminator, null
    br i1 %label_has_no_term, label %label_missing_terminator, label %check_restore
    
label_missing_terminator:
    ; Report compilation error: label body has no terminator
    call i32 (i8*, ...) @printf(
        i8* getelementptr inbounds ([37 x i8], [37 x i8]* @.str.err_label_no_terminator, i32 0, i32 0),
        i8* %label_name)
    br label %error
    
check_restore:
    ; Label block is properly terminated. Now restore builder position.
    ; Check if current insert block has moved (due to nested labels in the body).
    %current_block_after = call %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder)
    %current_block_null = icmp eq %LLVMBasicBlockRef %current_block_after, null
    br i1 %current_block_null, label %no_restore, label %check_if_still_on_label
    
check_if_still_on_label:
    ; If builder is still on the label block, it was terminated - don't restore
    ; If builder moved (nested labels), also don't restore to saved_block
    %still_on_label = icmp eq %LLVMBasicBlockRef %current_block_after, %block
    br i1 %still_on_label, label %no_restore, label %check_saved_null
    
no_restore:
    ; Label block was terminated - don't restore builder position
    ; The next sibling (likely another llvm:label) will create a new block and position builder there
    br label %return_block
    
check_saved_null:
    %saved_block_null = icmp eq %LLVMBasicBlockRef %saved_block, null
    br i1 %saved_block_null, label %return_block, label %restore_position
    
restore_position:
    ; Restore builder to the position it was at before we positioned it at the label block
    ; This ensures subsequent sibling expressions continue in the correct block
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %saved_block)
    br label %return_block
    
return_block:
    ; Return basic block as LLVMValueRef (cast)
    %block_phi = phi %LLVMBasicBlockRef [ %block, %no_restore ], [ %block, %restore_position ], [ %block, %check_saved_null ]
    %block_as_value = bitcast %LLVMBasicBlockRef %block_phi to %LLVMValueRef
    ret %LLVMValueRef %block_as_value
    
error:
    ret %LLVMValueRef null
}

; codegen_eval_let_star: Handle let* special form
; Syntax: (let* ((var1 value1) (var2 value2) ...) body ...)
; Parameters:
;   cg: CodeGen pointer
;   expr: AST node for let* form
; Returns: LLVMValueRef (last expression value) or null
; Semantics: Sequential binding - each binding can use previous bindings
define %LLVMValueRef @codegen_eval_let_star(%CodeGen* %cg, %ASTNode* %expr) {
entry:
    %expr_null = icmp eq %ASTNode* %expr, null
    br i1 %expr_null, label %error, label %get_bindings
    
get_bindings:
    ; Extract bindings list and body from expr
    ; The parser creates: (let* bindings-list body)
    ;   Structure: (let* . (bindings-list . body))
    ;   - expr.cdr = (bindings-list . body) = cons cell
    ;   - expr.cdr.car = bindings-list = ((var1 val1) (var2 val2) ...)
    ;   - expr.cdr.cdr = body = ((body-expr1) (body-expr2) ...)
    %expr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 5
    %expr_cdr = load %ASTNode*, %ASTNode** %expr_cdr_ptr
    %expr_cdr_null = icmp eq %ASTNode* %expr_cdr, null
    br i1 %expr_cdr_null, label %error, label %extract_bindings_list
    
extract_bindings_list:
    ; Extract bindings list from expr.cdr.car
    %bindings_list_car_ptr = getelementptr %ASTNode, %ASTNode* %expr_cdr, i32 0, i32 4
    %bindings_list = load %ASTNode*, %ASTNode** %bindings_list_car_ptr
    
    ; Debug: Check bindings_list type
    %bindings_list_type_ptr = getelementptr %ASTNode, %ASTNode* %bindings_list, i32 0, i32 0
    %bindings_list_type = load i32, i32* %bindings_list_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_bindings_list_type, i32 0, i32 0), i32 %bindings_list_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %bindings_null = icmp eq %ASTNode* %bindings_list, null
    br i1 %bindings_null, label %error, label %extract_body_from_expr
    
extract_body_from_expr:
    ; Extract body from expr.cdr.cdr (body comes after bindings-list)
    %body_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr_cdr, i32 0, i32 5
    %body = load %ASTNode*, %ASTNode** %body_cdr_ptr
    
    ; Debug: Extracted bindings and body
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_let_star_recognized, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %body_ptr = alloca %ASTNode*
    store %ASTNode* %body, %ASTNode** %body_ptr
    br label %setup_iteration
    
setup_iteration:
    ; Process bindings sequentially
    ; bindings_list is ((var1 val1) (var2 val2) ...) - a list of binding pairs
    ; We iterate through bindings_list, processing each binding pair
    %current_bindings = alloca %ASTNode*
    store %ASTNode* %bindings_list, %ASTNode** %current_bindings
    br label %bind_loop
    
bind_loop:
    ; Get current bindings list
    %bindings_iter = load %ASTNode*, %ASTNode** %current_bindings
    %bindings_iter_null = icmp eq %ASTNode* %bindings_iter, null
    br i1 %bindings_iter_null, label %debug_no_more_bindings, label %get_binding_pair
    
debug_no_more_bindings:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([34 x i8], [34 x i8]* @.str.debug_no_more_bindings, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
get_binding_pair:
    ; Debug: Processing bindings list
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_processing_bindings_list, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get the first element from the current bindings list
    ; bindings_iter is a cons cell: (binding-pair . rest)
    ; bindings_iter.car is the binding pair: (name value-expr)
    %binding_pair_car_ptr = getelementptr %ASTNode, %ASTNode* %bindings_iter, i32 0, i32 4
    %binding_val = load %ASTNode*, %ASTNode** %binding_pair_car_ptr
    
    ; Debug: Check what binding_val is
    %binding_val_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 0
    %binding_val_type = load i32, i32* %binding_val_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_binding_val_type, i32 0, i32 0), i32 %binding_val_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check binding_val.car type (should be atom for name)
    %binding_val_car_check_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 4
    %binding_val_car_check = load %ASTNode*, %ASTNode** %binding_val_car_check_ptr
    %binding_val_car_check_null = icmp eq %ASTNode* %binding_val_car_check, null
    br i1 %binding_val_car_check_null, label %check_binding_type, label %debug_car_type
    
debug_car_type:
    %binding_val_car_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_val_car_check, i32 0, i32 0
    %binding_val_car_type = load i32, i32* %binding_val_car_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_binding_val_car_type, i32 0, i32 0), i32 %binding_val_car_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %check_binding_type
    
    %binding_null = icmp eq %ASTNode* %binding_val, null
    br i1 %binding_null, label %debug_binding_null, label %check_binding_type
    
debug_binding_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_binding_pair_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
check_binding_type:
    ; Check if this is a list (binding pair) or something else
    %binding_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 0
    %binding_type = load i32, i32* %binding_type_ptr
    %is_list = icmp eq i32 %binding_type, 1  ; AST_NODE_TYPE_LIST = 1
    
    ; Debug: Check binding type
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_binding_type_check, i32 0, i32 0), i32 %binding_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    br i1 %is_list, label %check_binding_pair_structure, label %debug_not_list
    
debug_not_list:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_binding_not_list, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
check_binding_pair_structure:
    ; A binding pair is: (name value-expr) where name is an atom, value-expr can be atom/literal/list
    ; The parser creates: (lexer (llvm:call ...))
    ; So binding_val.car is the name atom, binding_val.cdr is the value expression
    ; However, if binding_val.car is a list (type 1), we need to unwrap it to get the actual atom
    %binding_val_car_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 4
    %binding_name_wrapper = load %ASTNode*, %ASTNode** %binding_val_car_ptr
    %binding_name_wrapper_null = icmp eq %ASTNode* %binding_name_wrapper, null
    br i1 %binding_name_wrapper_null, label %debug_name_null, label %check_wrapper_type
    
debug_name_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_binding_name_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
check_wrapper_type:
    ; Check if binding_name_wrapper is a list (needs unwrapping) or an atom (direct use)
    %wrapper_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_name_wrapper, i32 0, i32 0
    %wrapper_type = load i32, i32* %wrapper_type_ptr
    %wrapper_is_list = icmp eq i32 %wrapper_type, 1  ; AST_NODE_TYPE_LIST = 1
    br i1 %wrapper_is_list, label %unwrap_name, label %use_name_directly
    
unwrap_name:
    ; binding_name_wrapper is a list, extract the atom from its car
    %wrapper_car_ptr = getelementptr %ASTNode, %ASTNode* %binding_name_wrapper, i32 0, i32 4
    %binding_name_unwrapped = load %ASTNode*, %ASTNode** %wrapper_car_ptr
    %binding_name_unwrap_null = icmp eq %ASTNode* %binding_name_unwrapped, null
    br i1 %binding_name_unwrap_null, label %debug_name_null, label %check_name_is_atom
    
use_name_directly:
    ; binding_name_wrapper is already an atom, use it directly
    br label %check_name_is_atom
    
check_name_is_atom:
    ; Get the actual name node (either unwrapped or direct)
    %binding_name = phi %ASTNode* [%binding_name_unwrapped, %unwrap_name], [%binding_name_wrapper, %use_name_directly]
    
    ; Check if the name is an atom (identifier)
    %name_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_name, i32 0, i32 0
    %name_type = load i32, i32* %name_type_ptr
    
    ; Debug: Check name type
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_name_type_check, i32 0, i32 0), i32 %name_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %name_is_atom = icmp eq i32 %name_type, 0  ; AST_NODE_TYPE_ATOM = 0
    br i1 %name_is_atom, label %process_binding, label %debug_name_not_atom
    
debug_name_not_atom:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_name_not_atom, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
process_binding:
    ; Debug: Processing binding
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_processing_binding, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; binding_name is already extracted and validated as an atom in check_name_is_atom
    ; Extract name string from the validated atom
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %binding_name, i32 0, i32 2
    %name_str = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %binding_name, i32 0, i32 3
    %name_len = load i64, i64* %name_len_ptr
    
    ; Debug: Extracted name
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_extracted_name, i32 0, i32 0))
    %name_str_debug_valid = icmp ne i8* %name_str, null
    br i1 %name_str_debug_valid, label %print_name_debug, label %skip_name_debug
    
print_name_debug:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name_debug
    
skip_name_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if name is empty (length 0 or null pointer)
    %name_len_zero = icmp eq i64 %name_len, 0
    %name_str_null = icmp eq i8* %name_str, null
    %name_empty = or i1 %name_len_zero, %name_str_null
    br i1 %name_empty, label %eval_body, label %get_value_expr
    
get_value_expr:
    ; Get value expression (cdr.car of binding)
    ; The parser creates: (name value-expr) where name is atom, value-expr can be atom/literal/list
    ; In cons cell representation: (name . (value-expr . rest))
    ; So binding_val.cdr is the cons cell for (value-expr . rest)
    ; The value expression is binding_val.cdr.car (the actual value expression)
    %binding_cdr_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 5
    %value_expr_cons = load %ASTNode*, %ASTNode** %binding_cdr_ptr
    %value_expr_cons_null = icmp eq %ASTNode* %value_expr_cons, null
    br i1 %value_expr_cons_null, label %next_binding, label %extract_value_from_cons
    
extract_value_from_cons:
    ; Extract the actual value expression from the cons cell
    %value_expr_car_ptr = getelementptr %ASTNode, %ASTNode* %value_expr_cons, i32 0, i32 4
    %value_expr = load %ASTNode*, %ASTNode** %value_expr_car_ptr
    %value_expr_null = icmp eq %ASTNode* %value_expr, null
    br i1 %value_expr_null, label %next_binding, label %eval_value
    
eval_value:
    ; value_expr is the value expression (atom, literal, or list)
    
    ; Debug: Check value_expr type
    %value_expr_type_ptr = getelementptr %ASTNode, %ASTNode* %value_expr, i32 0, i32 0
    %value_expr_type = load i32, i32* %value_expr_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_value_expr_type, i32 0, i32 0), i32 %value_expr_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Evaluating value expression for binding
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_local, i32 0, i32 0))
    %name_str_valid = icmp ne i8* %name_str, null
    br i1 %name_str_valid, label %print_name, label %skip_name
    
print_name:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name
    
skip_name:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.debug_evaluating_value, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Evaluate value expression (in current scope with previous bindings)
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_expr)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %value_eval_failed, label %bind_value
    
value_eval_failed:
    ; Debug: Value evaluation failed
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_local, i32 0, i32 0))
    %name_str_valid_failed = icmp ne i8* %name_str, null
    br i1 %name_str_valid_failed, label %print_name_failed, label %skip_name_failed
    
print_name_failed:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name_failed
    
skip_name_failed:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.debug_value_eval_failed, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %next_binding
    
bind_value:
    ; Bind variable name to value
    ; Debug: About to bind local value
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_binding_local_value, i32 0, i32 0))
    %name_str_bind_valid = icmp ne i8* %name_str, null
    br i1 %name_str_bind_valid, label %print_name_bind, label %skip_name_bind
    
print_name_bind:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name_bind
    
skip_name_bind:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call void @codegen_dsl_bind_local(%CodeGen* %cg, i8* %name_str, i64 %name_len, %LLVMValueRef %value)
    br label %next_binding
    
next_binding:
    ; Move to next binding in the bindings list
    ; Get cdr of current bindings list to get rest of bindings
    %bindings_iter_cdr_ptr = getelementptr %ASTNode, %ASTNode* %bindings_iter, i32 0, i32 5
    %bindings_iter_cdr = load %ASTNode*, %ASTNode** %bindings_iter_cdr_ptr
    %bindings_iter_cdr_null = icmp eq %ASTNode* %bindings_iter_cdr, null
    br i1 %bindings_iter_cdr_null, label %eval_body, label %update_bindings_iter
    
update_bindings_iter:
    ; Update current_bindings to point to the rest of the bindings list
    store %ASTNode* %bindings_iter_cdr, %ASTNode** %current_bindings
    br label %bind_loop
    
eval_body:
    ; Load body from body_ptr (extracted after processing bindings)
    %body_loaded = load %ASTNode*, %ASTNode** %body_ptr
    ; Evaluate body expressions in sequence (in final scope with all bindings)
    %body_null = icmp eq %ASTNode* %body_loaded, null
    br i1 %body_null, label %return_null, label %eval_body_loop
    
eval_body_loop:
    %current_expr = alloca %ASTNode*
    store %ASTNode* %body_loaded, %ASTNode** %current_expr
    %last_result = alloca %LLVMValueRef
    store %LLVMValueRef null, %LLVMValueRef* %last_result
    br label %body_iter
    
body_iter:
    %expr_val = load %ASTNode*, %ASTNode** %current_expr
    %expr_val_null = icmp eq %ASTNode* %expr_val, null
    br i1 %expr_val_null, label %return_last, label %eval_expr
    
eval_expr:
    %body_expr_car_ptr = getelementptr %ASTNode, %ASTNode* %expr_val, i32 0, i32 4
    %body_expr_car = load %ASTNode*, %ASTNode** %body_expr_car_ptr
    
    ; Evaluate expression
    %expr_result = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %body_expr_car)
    
    ; Store result (even if null, for void expressions)
    store %LLVMValueRef %expr_result, %LLVMValueRef* %last_result
    
    ; Move to next expression
    %body_expr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr_val, i32 0, i32 5
    %body_expr_cdr = load %ASTNode*, %ASTNode** %body_expr_cdr_ptr
    store %ASTNode* %body_expr_cdr, %ASTNode** %current_expr
    br label %body_iter
    
return_last:
    %result = load %LLVMValueRef, %LLVMValueRef* %last_result
    ret %LLVMValueRef %result
    
return_null:
    ret %LLVMValueRef null
    
error:
    ret %LLVMValueRef null
}

; Evaluate list of DSL expressions to array
; codegen_eval_dsl_list: Evaluate list of expressions and store in array
; Parameters:
;   cg: Pointer to CodeGen structure
;   list: AST node list of expressions
;   array: Array to store results
;   max_count: Maximum number of elements
; Returns: Number of elements evaluated
define i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %list, %LLVMValueRef* %array, i32 %max_count) {
entry:
    %list_null = icmp eq %ASTNode* %list, null
    br i1 %list_null, label %return_zero, label %count_loop
    
return_zero:
    ret i32 0
    
count_loop:
    ; Count elements first
    %count = alloca i32
    store i32 0, i32* %count
    %current = alloca %ASTNode*
    store %ASTNode* %list, %ASTNode** %current
    br label %count_iter
    
count_iter:
    %current_val = load %ASTNode*, %ASTNode** %current
    %current_null = icmp eq %ASTNode* %current_val, null
    br i1 %current_null, label %eval_loop, label %count_inc
    
count_inc:
    %count_val = load i32, i32* %count
    %count_new = add i32 %count_val, 1
    store i32 %count_new, i32* %count
    
    %current_cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %current_cdr = load %ASTNode*, %ASTNode** %current_cdr_ptr
    store %ASTNode* %current_cdr, %ASTNode** %current
    br label %count_iter
    
eval_loop:
    ; Evaluate each element
    %count_final = load i32, i32* %count
    %count_ge_max = icmp uge i32 %count_final, %max_count
    br i1 %count_ge_max, label %return_count, label %eval_elements
    
eval_elements:
    %i = alloca i32
    store i32 0, i32* %i
    %current_eval = alloca %ASTNode*
    store %ASTNode* %list, %ASTNode** %current_eval
    br label %eval_iter
    
eval_iter:
    %i_val = load i32, i32* %i
    %count_check = load i32, i32* %count
    %done = icmp uge i32 %i_val, %count_check
    br i1 %done, label %return_count, label %eval_current
    
eval_current:
    %current_eval_val = load %ASTNode*, %ASTNode** %current_eval
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_eval_val, i32 0, i32 4
    %car = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Evaluate expression
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %car)
    
    ; Debug: Check value before storing
    %i_val_for_idx = load i32, i32* %i
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_storing_arg, i32 0, i32 0), i32 %i_val_for_idx)
    %value_null_check = icmp eq %LLVMValueRef %value, null
    br i1 %value_null_check, label %value_null_before_store, label %value_ok_before_store
    
value_null_before_store:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %store_value
    
value_ok_before_store:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %store_value
    
store_value:
    ; Store in array
    %array_idx = getelementptr %LLVMValueRef, %LLVMValueRef* %array, i32 %i_val_for_idx
    store %LLVMValueRef %value, %LLVMValueRef* %array_idx
    
    ; Debug: Verify value was stored
    %stored_value = load %LLVMValueRef, %LLVMValueRef* %array_idx
    %stored_null = icmp eq %LLVMValueRef %stored_value, null
    br i1 %stored_null, label %stored_value_null, label %value_stored_ok
    
stored_value_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([35 x i8], [35 x i8]* @.str.debug_stored_value_null, i32 0, i32 0), i32 %i_val_for_idx)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %continue_after_store
    
value_stored_ok:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_value_stored_ok, i32 0, i32 0), i32 %i_val_for_idx)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %continue_after_store
    
continue_after_store:
    
    ; Move to next
    %i_val_after = load i32, i32* %i
    %i_new = add i32 %i_val_after, 1
    store i32 %i_new, i32* %i
    
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_eval_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current_eval
    br label %eval_iter
    
return_count:
    %count_ret = load i32, i32* %count
    ret i32 %count_ret
}

; ============================================================================
; define-llvm-function Implementation
; ============================================================================

; Handle define-llvm-function AST node
; codegen_define_llvm_function: Process define-llvm-function form using DSL
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-llvm-function form
; Returns: 0 on success, -1 on error
; Syntax: (define-llvm-function (name (param1 type1) (param2 type2) ...) return-type (dsl-body ...))
define i32 @codegen_define_llvm_function(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([40 x i8], [40 x i8]* @.str.debug_define_llvm_function_start, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Clear local_values list at start of function definition
    ; This ensures bindings from previous functions don't leak into the new function
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_ptr
    
    ; AST structure: LIST { ATOM: "define-llvm-function", LIST: signature, ATOM: return-type, LIST: dsl-body }
    ; Get signature list (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %sig_list_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %sig_list = load %ASTNode*, %ASTNode** %sig_list_node_ptr
    
    ; Extract function name (first element of signature list)
    %sig_car_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 4
    %func_name_node = load %ASTNode*, %ASTNode** %sig_car_ptr
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
    ; Get parameters with types (rest of signature list)
    %sig_cdr_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 5
    %params_list = load %ASTNode*, %ASTNode** %sig_cdr_ptr
    
    ; Get return type (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %return_type_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %return_type_node = load %ASTNode*, %ASTNode** %return_type_node_ptr
    %return_type_val_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 2
    %return_type = load i8*, i8** %return_type_val_ptr
    %return_type_len_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 3
    %return_type_len = load i64, i64* %return_type_len_ptr
    
    ; Get DSL body (fourth element - list)
    ; Structure: (define-llvm-function signature return-type body)
    ; cdr = (signature return-type body)
    ; cdr.cdr = (return-type body)
    ; cdr.cdr.cdr = body - this is the list of expressions (or a wrapper)
    ; Try both: cdr_cdr_cdr directly and cdr_cdr_cdr.car
    %cdr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 5
    %cdr_cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_cdr_ptr
    
    ; Debug logging - log DSL body extraction
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_extracting_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %cdr_cdr_cdr_null = icmp eq %ASTNode* %cdr_cdr_cdr, null
    br i1 %cdr_cdr_cdr_null, label %error, label %try_body_direct
    
try_body_direct:
    ; First try: use cdr_cdr_cdr directly as the body
    ; Check if it's a list (AST_LIST = 1)
    %cdr_cdr_cdr_type_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 0
    %cdr_cdr_cdr_type = load i32, i32* %cdr_cdr_cdr_type_ptr
    %is_list_direct = icmp eq i32 %cdr_cdr_cdr_type, 1  ; AST_LIST
    br i1 %is_list_direct, label %use_direct_body, label %try_body_car
    
use_direct_body:
    ; Use cdr_cdr_cdr directly as the body
    br label %check_body_done
    
try_body_car:
    ; Second try: use cdr_cdr_cdr.car as the body
    %dsl_body_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 4
    %dsl_body_car = load %ASTNode*, %ASTNode** %dsl_body_node_ptr
    br label %check_body_done
    
check_body_done:
    %dsl_body = phi %ASTNode* [ %cdr_cdr_cdr, %use_direct_body ], [ %dsl_body_car, %try_body_car ]
    
    ; Debug logging - log extracted DSL body
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_dsl_body_extracted, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %any_null = or i1 %context_null, %module_null
    br i1 %any_null, label %error, label %resolve_return_type
    
resolve_return_type:
    ; Resolve return type string to LLVMTypeRef
    %return_type_ref = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %return_type, i64 %return_type_len)
    %return_type_null = icmp eq %LLVMTypeRef %return_type_ref, null
    br i1 %return_type_null, label %error, label %collect_params
    
collect_params:
    ; Collect parameter types
    ; Allocate array for parameter types (max 10 params)
    %param_types_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %param_types_ptr = bitcast i8* %param_types_array to %LLVMTypeRef*
    
    ; Count and resolve parameter types
    %param_count = call i32 @codegen_collect_param_types(%CodeGen* %cg, %ASTNode* %params_list, %LLVMTypeRef* %param_types_ptr, i32 10)
    
    ; Debug: Print parameter count collected
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([31 x i8], [31 x i8]* @.str.debug_collected_param_count, i32 0, i32 0), i32 %param_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create function type
    ; If param_count is 0, pass null for param_types (LLVM requirement)
    %has_params = icmp ne i32 %param_count, 0
    br i1 %has_params, label %create_func_type_with_params, label %create_func_type_no_params
    
create_func_type_with_params:
    %func_type = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* %param_types_ptr, i32 %param_count, i32 0)
    br label %check_func_type
    
create_func_type_no_params:
    %func_type_no_params = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* null, i32 0, i32 0)
    br label %check_func_type
    
check_func_type:
    %func_type_phi = phi %LLVMTypeRef [ %func_type, %create_func_type_with_params ], [ %func_type_no_params, %create_func_type_no_params ]
    %param_types_array_phi = phi i8* [ %param_types_array, %create_func_type_with_params ], [ %param_types_array, %create_func_type_no_params ]
    %func_type_null = icmp eq %LLVMTypeRef %func_type_phi, null
    br i1 %func_type_null, label %free_param_types, label %add_function
    
free_param_types:
    call void @free(i8* %param_types_array_phi)
    br label %error
    
add_function:
    ; Add function to module (or reuse existing forward declaration)
    ; Create null-terminated function name
    %func_name_buf_plus1 = add i64 %func_name_len, 1
    %func_name_buf_full = call i8* @malloc(i64 %func_name_buf_plus1)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_name_buf_full, i8* %func_name, i64 %func_name_len, i1 false)
    %null_ptr = getelementptr i8, i8* %func_name_buf_full, i64 %func_name_len
    store i8 0, i8* %null_ptr
    
    ; Check if function already exists (e.g. from a forward declaration)
    %existing_func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %func_name_buf_full)
    %existing_null = icmp eq %LLVMValueRef %existing_func, null
    br i1 %existing_null, label %create_new_function, label %reuse_existing_function

create_new_function:
    %new_func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %func_name_buf_full, %LLVMTypeRef %func_type_phi)
    call void @free(i8* %func_name_buf_full)
    %new_func_null = icmp eq %LLVMValueRef %new_func, null
    br i1 %new_func_null, label %free_param_types, label %set_param_names

reuse_existing_function:
    ; Reuse the existing forward declaration - the definition body will be added to it
    call void @free(i8* %func_name_buf_full)
    br label %set_param_names
    
set_param_names:
    ; Merge function value from either new creation or reuse of existing declaration
    %func = phi %LLVMValueRef [ %new_func, %create_new_function ], [ %existing_func, %reuse_existing_function ]
    
    ; Create entry basic block FIRST (required before accessing parameters)
    ; Use non-null name (some LLVM versions may require this)
    %entry_block_name = bitcast [6 x i8]* @.str.entry_block_name to i8*
    %entry_bb = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %func, i8* %entry_block_name)
    
    ; Create builder BEFORE accessing parameters (builder positioning may initialize function state)
    %builder = call %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef %context)
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %free_param_types, label %position_builder
    
position_builder:
    ; Position builder at end of entry block (this may initialize function's parameter list)
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %entry_bb)
    
    ; NOW set parameter names and build parameter mapping (after builder is positioned)
    %param_names_list = call %ASTNode* @codegen_build_param_names(%CodeGen* %cg, %LLVMValueRef %func, %ASTNode* %params_list)
    
    ; Store function and builder in CodeGen
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    store %LLVMValueRef %func, %LLVMValueRef* %current_function_ptr
    
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    store %LLVMBuilderRef %builder, %LLVMBuilderRef* %builder_ptr
    
    %param_names_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 9
    store %ASTNode* %param_names_list, %ASTNode** %param_names_ptr
    
    ; Store function for later retrieval during function calls
    call void @codegen_store_llvm_function(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMValueRef %func, %LLVMTypeRef %func_type_phi)
    
    ; Evaluate DSL body (this should generate a return statement)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_evaluating_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %dsl_body)
    
    ; Visitor pattern exit check: verify the entry block has a terminator
    ; Every basic block must have a terminator (br, ret, etc.)
    ; If the DSL body didn't terminate the entry block, that's a compilation error.
    %entry_terminator = call %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef %entry_bb)
    %entry_has_no_term = icmp eq %LLVMValueRef %entry_terminator, null
    br i1 %entry_has_no_term, label %entry_missing_terminator, label %cleanup_builder
    
entry_missing_terminator:
    ; Report compilation error: entry block has no terminator
    call i32 (i8*, ...) @printf(
        i8* getelementptr inbounds ([55 x i8], [55 x i8]* @.str.err_entry_no_terminator, i32 0, i32 0),
        i8* %func_name)
    br label %error
    
cleanup_builder:
    ; Clean up builder
    call void @llvm_dispose_builder(%LLVMBuilderRef %builder)
    
    ; Clear DSL evaluation fields
    store %LLVMValueRef null, %LLVMValueRef* %current_function_ptr
    store %LLVMBuilderRef null, %LLVMBuilderRef* %builder_ptr
    store %ASTNode* null, %ASTNode** %param_names_ptr
    
    ; Clear local_values list at end of function definition
    ; This ensures bindings don't leak to the next function
    %local_values_cleanup_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_cleanup_ptr
    
    ; Free param types array
    call void @free(i8* %param_types_array)
    
    ret i32 0
    
error:
    ret i32 -1
}

; Handle define-llvm-ffi-function AST node
; codegen_define_llvm_ffi_function: Process define-llvm-ffi-function form using FFI
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-llvm-ffi-function form
; Returns: 0 on success, -1 on error
; Syntax: (define-llvm-ffi-function (name (param1 type1) (param2 type2) ...) return-type (library-name symbol-name) [is-vararg])
define i32 @codegen_define_llvm_ffi_function(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([44 x i8], [44 x i8]* @.str.debug_define_llvm_ffi_function_start, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; AST structure: LIST { ATOM: "define-llvm-ffi-function", LIST: signature, ATOM: return-type, LIST: (library-name symbol-name) }
    ; Get signature list (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %sig_list_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %sig_list = load %ASTNode*, %ASTNode** %sig_list_node_ptr
    
    ; Extract function name (first element of signature list)
    %sig_car_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 4
    %func_name_node = load %ASTNode*, %ASTNode** %sig_car_ptr
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
    ; Get parameters with types (rest of signature list)
    %sig_cdr_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 5
    %params_list = load %ASTNode*, %ASTNode** %sig_cdr_ptr
    
    ; Get return type (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %return_type_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %return_type_node = load %ASTNode*, %ASTNode** %return_type_node_ptr
    %return_type_val_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 2
    %return_type = load i8*, i8** %return_type_val_ptr
    %return_type_len_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 3
    %return_type_len = load i64, i64* %return_type_len_ptr
    
    ; Get library/symbol info (fourth element): (library-name symbol-name)
    %cdr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 5
    %cdr_cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_cdr_ptr
    %lib_info_list_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 4
    %lib_info_list = load %ASTNode*, %ASTNode** %lib_info_list_node_ptr
    
    ; Extract library name (first element of lib_info_list)
    %lib_info_car_ptr = getelementptr %ASTNode, %ASTNode* %lib_info_list, i32 0, i32 4
    %lib_name_node = load %ASTNode*, %ASTNode** %lib_info_car_ptr
    %lib_name_val_ptr = getelementptr %ASTNode, %ASTNode* %lib_name_node, i32 0, i32 2
    %lib_name = load i8*, i8** %lib_name_val_ptr
    %lib_name_len_ptr = getelementptr %ASTNode, %ASTNode* %lib_name_node, i32 0, i32 3
    %lib_name_len = load i64, i64* %lib_name_len_ptr
    
    ; Extract symbol name (second element of lib_info_list)
    %lib_info_cdr_ptr = getelementptr %ASTNode, %ASTNode* %lib_info_list, i32 0, i32 5
    %lib_info_cdr = load %ASTNode*, %ASTNode** %lib_info_cdr_ptr
    %symbol_info_car_ptr = getelementptr %ASTNode, %ASTNode* %lib_info_cdr, i32 0, i32 4
    %symbol_name_node = load %ASTNode*, %ASTNode** %symbol_info_car_ptr
    %symbol_name_val_ptr = getelementptr %ASTNode, %ASTNode* %symbol_name_node, i32 0, i32 2
    %symbol_name = load i8*, i8** %symbol_name_val_ptr
    %symbol_name_len_ptr = getelementptr %ASTNode, %ASTNode* %symbol_name_node, i32 0, i32 3
    %symbol_name_len = load i64, i64* %symbol_name_len_ptr
    
    ; Check for optional vararg flag (fifth element of top-level form)
    ; The vararg flag is after the library info in the top-level list, not inside it
    ; Top-level: (define-ffi-function signature return-type (lib sym) [vararg])
    ; cdr_cdr_cdr = cell4 (lib info), cdr_cdr_cdr.cdr = cell5 (vararg flag)
    %vararg_cell_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 5
    %vararg_cell = load %ASTNode*, %ASTNode** %vararg_cell_ptr
    %is_vararg = alloca i32
    store i32 0, i32* %is_vararg
    %has_vararg_flag = icmp ne %ASTNode* %vararg_cell, null
    br i1 %has_vararg_flag, label %check_vararg_flag, label %load_library
    
check_vararg_flag:
    ; Check if vararg flag is present (should be #t or #f)
    %vararg_flag_node_ptr = getelementptr %ASTNode, %ASTNode* %vararg_cell, i32 0, i32 4
    %vararg_flag_node = load %ASTNode*, %ASTNode** %vararg_flag_node_ptr
    %vararg_flag_val_ptr = getelementptr %ASTNode, %ASTNode* %vararg_flag_node, i32 0, i32 2
    %vararg_flag = load i8*, i8** %vararg_flag_val_ptr
    ; Check if it's "#t" (2 chars)
    %vararg_flag_len_ptr = getelementptr %ASTNode, %ASTNode* %vararg_flag_node, i32 0, i32 3
    %vararg_flag_len = load i64, i64* %vararg_flag_len_ptr
    %is_t = icmp eq i64 %vararg_flag_len, 2
    br i1 %is_t, label %set_vararg, label %load_library
    
set_vararg:
    store i32 1, i32* %is_vararg
    br label %load_library
    
load_library:
    ; Create null-terminated library name
    %lib_name_buf_size = add i64 %lib_name_len, 1
    %lib_name_buf = call i8* @malloc(i64 %lib_name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %lib_name_buf, i8* %lib_name, i64 %lib_name_len, i1 false)
    %lib_null_ptr = getelementptr i8, i8* %lib_name_buf, i64 %lib_name_len
    store i8 0, i8* %lib_null_ptr
    
    ; Load library using FFI
    %lib_handle = call %LibraryHandle* @ffi_load_library(i8* %lib_name_buf)
    call void @free(i8* %lib_name_buf)
    
    %lib_handle_null = icmp eq %LibraryHandle* %lib_handle, null
    br i1 %lib_handle_null, label %error, label %get_symbol
    
get_symbol:
    ; Create null-terminated symbol name
    %symbol_name_buf_size = add i64 %symbol_name_len, 1
    %symbol_name_buf = call i8* @malloc(i64 %symbol_name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %symbol_name_buf, i8* %symbol_name, i64 %symbol_name_len, i1 false)
    %symbol_null_ptr = getelementptr i8, i8* %symbol_name_buf, i64 %symbol_name_len
    store i8 0, i8* %symbol_null_ptr
    
    ; Get symbol from library
    %func_ptr = call %FunctionPtr @ffi_get_symbol(%LibraryHandle* %lib_handle, i8* %symbol_name_buf)
    call void @free(i8* %symbol_name_buf)
    
    %func_ptr_null = icmp eq %FunctionPtr %func_ptr, null
    br i1 %func_ptr_null, label %error, label %get_llvm_context
    
get_llvm_context:
    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %any_null = or i1 %context_null, %module_null
    br i1 %any_null, label %error, label %resolve_return_type_ffi
    
resolve_return_type_ffi:
    ; Resolve return type string to LLVMTypeRef
    %return_type_ref = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %return_type, i64 %return_type_len)
    %return_type_null = icmp eq %LLVMTypeRef %return_type_ref, null
    br i1 %return_type_null, label %error, label %collect_params_ffi
    
collect_params_ffi:
    ; Collect parameter types
    %param_types_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %param_types_ptr = bitcast i8* %param_types_array to %LLVMTypeRef*
    
    ; Count and resolve parameter types
    %param_count = call i32 @codegen_collect_param_types(%CodeGen* %cg, %ASTNode* %params_list, %LLVMTypeRef* %param_types_ptr, i32 10)
    
    ; Create function type (with vararg support if specified)
    %is_vararg_val = load i32, i32* %is_vararg
    %has_params_ffi = icmp ne i32 %param_count, 0
    br i1 %has_params_ffi, label %create_func_type_with_params_ffi, label %create_func_type_no_params_ffi
    
create_func_type_with_params_ffi:
    %func_type = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* %param_types_ptr, i32 %param_count, i32 %is_vararg_val)
    br label %check_func_type_ffi
    
create_func_type_no_params_ffi:
    %func_type_no_params = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* null, i32 0, i32 %is_vararg_val)
    br label %check_func_type_ffi
    
check_func_type_ffi:
    %func_type_phi = phi %LLVMTypeRef [ %func_type, %create_func_type_with_params_ffi ], [ %func_type_no_params, %create_func_type_no_params_ffi ]
    %func_type_null = icmp eq %LLVMTypeRef %func_type_phi, null
    br i1 %func_type_null, label %free_param_types_ffi, label %add_function_ffi
    
free_param_types_ffi:
    call void @free(i8* %param_types_array)
    br label %error
    
add_function_ffi:
    ; Add function declaration to module (external linkage)
    %func_name_buf_size = add i64 %func_name_len, 1
    %func_name_buf = call i8* @malloc(i64 %func_name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_name_buf, i8* %func_name, i64 %func_name_len, i1 false)
    %func_null_ptr = getelementptr i8, i8* %func_name_buf, i64 %func_name_len
    store i8 0, i8* %func_null_ptr
    
    %func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %func_name_buf, %LLVMTypeRef %func_type_phi)
    call void @free(i8* %func_name_buf)
    
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %free_param_types_ffi, label %set_external_linkage
    
set_external_linkage:
    ; Set external linkage (ExternalLinkage = 0)
    call void @llvm_set_linkage(%LLVMValueRef %func, i32 0)
    
    ; Store function and type for later retrieval
    call void @codegen_store_llvm_function(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMValueRef %func, %LLVMTypeRef %func_type_phi)
    call void @codegen_store_function_type(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMTypeRef %func_type_phi)
    
    ; Free param types array
    call void @free(i8* %param_types_array)
    
    ret i32 0
    
error:
    ret i32 -1
}

; ============================================================================
; declare-llvm-function Implementation
; ============================================================================

; Handle declare-llvm-function AST node
; codegen_declare_llvm_function: Process declare-llvm-function form
; Creates a function declaration (no body) so that other .vibe functions can
; call functions defined in separately-linked modules (e.g. _no_vibe.ll files).
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for declare-llvm-function form
; Returns: 0 on success, -1 on error
; Syntax: (declare-llvm-function (name (param1 type1) (param2 type2) ...) return-type)
define i32 @codegen_declare_llvm_function(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([40 x i8], [40 x i8]* @.str.debug_declare_llvm_function_start, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))

    ; AST structure: LIST { ATOM: "declare-llvm-function", LIST: signature, ATOM: return-type }
    ; Get signature list (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %sig_list_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %sig_list = load %ASTNode*, %ASTNode** %sig_list_node_ptr

    ; Extract function name (first element of signature list)
    %sig_car_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 4
    %func_name_node = load %ASTNode*, %ASTNode** %sig_car_ptr
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr

    ; Get parameters with types (rest of signature list)
    %sig_cdr_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 5
    %params_list = load %ASTNode*, %ASTNode** %sig_cdr_ptr

    ; Get return type (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %return_type_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %return_type_node = load %ASTNode*, %ASTNode** %return_type_node_ptr
    %return_type_val_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 2
    %return_type = load i8*, i8** %return_type_val_ptr
    %return_type_len_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 3
    %return_type_len = load i64, i64* %return_type_len_ptr

    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr

    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %any_null = or i1 %context_null, %module_null
    br i1 %any_null, label %decl_error, label %resolve_return_type_decl

resolve_return_type_decl:
    ; Resolve return type string to LLVMTypeRef
    %return_type_ref = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %return_type, i64 %return_type_len)
    %return_type_null = icmp eq %LLVMTypeRef %return_type_ref, null
    br i1 %return_type_null, label %decl_error, label %collect_params_decl

collect_params_decl:
    ; Collect parameter types
    %param_types_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %param_types_ptr = bitcast i8* %param_types_array to %LLVMTypeRef*

    ; Count and resolve parameter types
    %param_count = call i32 @codegen_collect_param_types(%CodeGen* %cg, %ASTNode* %params_list, %LLVMTypeRef* %param_types_ptr, i32 10)

    ; Create function type
    %has_params = icmp ne i32 %param_count, 0
    br i1 %has_params, label %create_func_type_with_params_decl, label %create_func_type_no_params_decl

create_func_type_with_params_decl:
    %func_type = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* %param_types_ptr, i32 %param_count, i32 0)
    br label %check_func_type_decl

create_func_type_no_params_decl:
    %func_type_no_params = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* null, i32 0, i32 0)
    br label %check_func_type_decl

check_func_type_decl:
    %func_type_phi = phi %LLVMTypeRef [ %func_type, %create_func_type_with_params_decl ], [ %func_type_no_params, %create_func_type_no_params_decl ]
    %func_type_null = icmp eq %LLVMTypeRef %func_type_phi, null
    br i1 %func_type_null, label %free_param_types_decl, label %add_function_decl

free_param_types_decl:
    call void @free(i8* %param_types_array)
    br label %decl_error

add_function_decl:
    ; Add function declaration to module (no body, external linkage)
    %func_name_buf_size = add i64 %func_name_len, 1
    %func_name_buf = call i8* @malloc(i64 %func_name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_name_buf, i8* %func_name, i64 %func_name_len, i1 false)
    %func_null_ptr = getelementptr i8, i8* %func_name_buf, i64 %func_name_len
    store i8 0, i8* %func_null_ptr

    %func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %func_name_buf, %LLVMTypeRef %func_type_phi)
    call void @free(i8* %func_name_buf)

    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %free_param_types_decl, label %set_external_linkage_decl

set_external_linkage_decl:
    ; Set external linkage (ExternalLinkage = 0)
    call void @llvm_set_linkage(%LLVMValueRef %func, i32 0)

    ; Store function and type for later retrieval during llvm:call
    call void @codegen_store_llvm_function(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMValueRef %func, %LLVMTypeRef %func_type_phi)
    call void @codegen_store_function_type(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMTypeRef %func_type_phi)

    ; Free param types array
    call void @free(i8* %param_types_array)

    ret i32 0

decl_error:
    ret i32 -1
}

; Collect parameter types from parameter list
; codegen_collect_param_types: Extract and resolve parameter types
; Parameters:
;   cg: Pointer to CodeGen structure
;   params: AST node list of (param-name type) pairs
;   array: Array to store types
;   max_count: Maximum number of parameters
; Returns: Number of parameters
define i32 @codegen_collect_param_types(%CodeGen* %cg, %ASTNode* %params, %LLVMTypeRef* %array, i32 %max_count) {
entry:
    ; Debug: Check if params is null
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_collect_params_start, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %params_null = icmp eq %ASTNode* %params, null
    br i1 %params_null, label %return_zero, label %collect_loop
    
return_zero:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_params_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret i32 0
    
collect_loop:
    %count = alloca i32
    store i32 0, i32* %count
    %current = alloca %ASTNode*
    store %ASTNode* %params, %ASTNode** %current
    br label %collect_iter
    
collect_iter:
    %current_val = load %ASTNode*, %ASTNode** %current
    %current_null = icmp eq %ASTNode* %current_val, null
    br i1 %current_null, label %return_count, label %get_param_type
    
get_param_type:
    %count_val = load i32, i32* %count
    %count_ge_max = icmp uge i32 %count_val, %max_count
    br i1 %count_ge_max, label %return_count, label %extract_type
    
extract_type:
    ; Debug: Processing parameter
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_processing_param, i32 0, i32 0), i32 %count_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get param pair: (param-name type)
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 4
    %param_pair = load %ASTNode*, %ASTNode** %car_ptr
    %param_pair_null = icmp eq %ASTNode* %param_pair, null
    br i1 %param_pair_null, label %param_pair_null_debug, label %get_pair_cdr
    
param_pair_null_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_param_pair_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %return_count
    
get_pair_cdr:
    ; Get type (second element of pair)
    ; Structure: (name . (type . nil))
    ; So we need: pair.cdr.car to get the type node
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 5
    %pair_cdr = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    %pair_cdr_null = icmp eq %ASTNode* %pair_cdr, null
    br i1 %pair_cdr_null, label %pair_cdr_null_debug, label %get_type_node
    
pair_cdr_null_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_pair_cdr_null_collect, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %return_count
    
get_type_node:
    ; Get car of the cdr list to get the type node
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %type_node_null_debug, label %get_type_string
    
type_node_null_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([31 x i8], [31 x i8]* @.str.debug_type_node_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %return_count
    
get_type_string:
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Debug: Print type string
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_resolving_type, i32 0, i32 0))
    %type_str_null = icmp eq i8* %type_str, null
    %type_len_zero = icmp eq i64 %type_len, 0
    %type_invalid = or i1 %type_str_null, %type_len_zero
    br i1 %type_invalid, label %type_invalid_debug, label %print_type_str
    
type_invalid_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %return_count
    
print_type_str:
    %type_len_plus1 = add i64 %type_len, 1
    %type_buf = call i8* @malloc(i64 %type_len_plus1)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %type_buf, i8* %type_str, i64 %type_len, i1 false)
    %type_null_ptr = getelementptr i8, i8* %type_buf, i64 %type_len
    store i8 0, i8* %type_null_ptr
    call i32 (i8*, ...) @printf(i8* %type_buf)
    call void @free(i8* %type_buf)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Resolve type
    %param_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    
    ; Validate parameter type before storing
    %param_type_null = icmp eq %LLVMTypeRef %param_type, null
    br i1 %param_type_null, label %type_resolve_failed, label %store_param_type
    
type_resolve_failed:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_type_resolve_failed, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %return_count
    
store_param_type:
    ; Store in array
    %count_for_idx = load i32, i32* %count
    %array_idx = getelementptr %LLVMTypeRef, %LLVMTypeRef* %array, i32 %count_for_idx
    store %LLVMTypeRef %param_type, %LLVMTypeRef* %array_idx
    
    ; Increment count
    %count_new = add i32 %count_for_idx, 1
    store i32 %count_new, i32* %count
    
    ; Move to next
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current
    br label %collect_iter
    
return_count:
    %count_ret = load i32, i32* %count
    ret i32 %count_ret
}

; Build parameter names mapping
; codegen_build_param_names: Create AST list of (name index) pairs
; Parameters:
;   cg: Pointer to CodeGen structure
;   func: LLVMValueRef for function
;   params: AST node list of (param-name type) pairs
; Returns: ASTNode* list of (name index) pairs
define %ASTNode* @codegen_build_param_names(%CodeGen* %cg, %LLVMValueRef %func, %ASTNode* %params) {
entry:
    %params_null = icmp eq %ASTNode* %params, null
    br i1 %params_null, label %return_null, label %build_list
    
return_null:
    ret %ASTNode* null
    
build_list:
    %result = alloca %ASTNode*
    store %ASTNode* null, %ASTNode** %result
    %current = alloca %ASTNode*
    store %ASTNode* %params, %ASTNode** %current
    %index = alloca i32
    store i32 0, i32* %index
    br label %build_loop
    
build_loop:
    %current_val = load %ASTNode*, %ASTNode** %current
    %current_null = icmp eq %ASTNode* %current_val, null
    br i1 %current_null, label %return_result, label %create_pair
    
create_pair:
    ; Get param pair: (param-name type)
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 4
    %param_pair = load %ASTNode*, %ASTNode** %car_ptr
    %param_pair_null = icmp eq %ASTNode* %param_pair, null
    br i1 %param_pair_null, label %skip_pair, label %get_param_name
    
get_param_name:
    ; Get param name (first element of pair)
    ; param_pair is (name type), so param_pair.car should be the name atom
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 4
    %param_name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %param_name_node_null = icmp eq %ASTNode* %param_name_node, null
    br i1 %param_name_node_null, label %skip_pair, label %check_name_node_type
    
check_name_node_type:
    ; Check if name node is actually an atom (type 0)
    %name_node_type_check_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 0
    %name_node_type_check = load i32, i32* %name_node_type_check_ptr
    %is_atom_check = icmp eq i32 %name_node_type_check, 0  ; AST_ATOM
    br i1 %is_atom_check, label %check_name_node, label %try_extract_from_list
    
try_extract_from_list:
    ; If name node is a list, try to extract the atom from it
    ; This might happen if the parameter structure is different than expected
    %list_car_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 4
    %list_car = load %ASTNode*, %ASTNode** %list_car_ptr
    %list_car_null = icmp eq %ASTNode* %list_car, null
    br i1 %list_car_null, label %skip_pair, label %check_list_car_type
    
check_list_car_type:
    ; Check if car is an atom
    %list_car_type_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 0
    %list_car_type = load i32, i32* %list_car_type_ptr
    %list_car_is_atom = icmp eq i32 %list_car_type, 0  ; AST_ATOM
    br i1 %list_car_is_atom, label %use_list_car, label %skip_pair
    
use_list_car:
    ; Use the atom from the list as the name node
    br label %check_name_node
    
check_name_node:
    ; Get the correct name node (either original or extracted from list)
    %param_name_node_phi = phi %ASTNode* [ %param_name_node, %check_name_node_type ], [ %list_car, %use_list_car ]
    ; Debug: Check name node value
    %name_val_check_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node_phi, i32 0, i32 2
    %name_val_check = load i8*, i8** %name_val_check_ptr
    %name_len_check_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node_phi, i32 0, i32 3
    %name_len_check = load i64, i64* %name_len_check_ptr
    
    ; Debug logging - print name node info
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_building_param_name, i32 0, i32 0))
    %name_val_check_null = icmp eq i8* %name_val_check, null
    %name_len_check_zero = icmp eq i64 %name_len_check, 0
    %name_check_invalid = or i1 %name_val_check_null, %name_len_check_zero
    br i1 %name_check_invalid, label %print_name_invalid, label %print_name_valid
    
print_name_invalid:
    %is_null_msg_build = select i1 %name_val_check_null, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0), i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_empty_str, i32 0, i32 0)
    call i32 (i8*, ...) @printf(i8* %is_null_msg_build)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %skip_pair
    
print_name_valid:
    ; Print name value
    %name_buf_build = call i8* @malloc(i64 %name_len_check)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf_build, i8* %name_val_check, i64 %name_len_check, i1 false)
    %name_null_build = getelementptr i8, i8* %name_buf_build, i64 %name_len_check
    store i8 0, i8* %name_null_build
    call i32 (i8*, ...) @printf(i8* %name_buf_build)
    call void @free(i8* %name_buf_build)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %get_index
    
get_index:
    ; Get current index
    %index_val = load i32, i32* %index
    
    ; Always store the index - we'll look up the parameter value later during DSL evaluation
    ; when the function is fully initialized. This avoids issues with LLVMGetParam returning
    ; null when called before the function is fully set up.
    ; Create an index node to store
    %index_node = call %ASTNode* @codegen_create_int_node(i32 %index_val)
    
    ; Create (name . index) pair - we'll look up the parameter value when resolving
    %name_index_pair = call %ASTNode* @codegen_create_pair(%ASTNode* %param_name_node_phi, %ASTNode* %index_node)
    
    ; Prepend to result list
    %result_val = load %ASTNode*, %ASTNode** %result
    %new_cons = call %ASTNode* @codegen_create_cons(%ASTNode* %name_index_pair, %ASTNode* %result_val)
    store %ASTNode* %new_cons, %ASTNode** %result
    
    ; Increment index and move to next
    %index_new = add i32 %index_val, 1
    store i32 %index_new, i32* %index
    br label %move_to_next_param
    
skip_pair:
    ; Skip this pair if it's invalid - move to next without incrementing index
    br label %move_to_next_param
    
move_to_next_param:
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current
    
    ; NOTE: We skip setting parameter names in LLVM for now because LLVMGetParam
    ; triggers BuildLazyArguments() which can crash if the function state isn't fully initialized.
    ; Parameter names aren't strictly necessary for code generation - we can access parameters
    ; by index. We'll set names later if needed, or skip them entirely.
    ; The mapping we're building (name -> index) is sufficient for DSL evaluation.
    
    br label %build_loop
    
return_result:
    %result_ret = load %ASTNode*, %ASTNode** %result
    ret %ASTNode* %result_ret
}

; Create integer AST node
; codegen_create_int_node: Create an AST node for an integer
; Parameters:
;   value: Integer value
; Returns: ASTNode* for number atom
define %ASTNode* @codegen_create_int_node(i32 %value) {
entry:
    ; Allocate node
    %node = call i8* @malloc(i64 48)
    %node_ptr = bitcast i8* %node to %ASTNode*
    
    ; Set node type to ATOM
    %type_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 0
    store i32 0, i32* %type_ptr  ; AST_ATOM
    
    ; Set atom type to TOKEN_NUMBER
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 1
    store i32 2, i32* %atom_type_ptr  ; TOKEN_NUMBER
    
    ; Convert integer to string (simplified - max 10 digits)
    %str_buf = call i8* @malloc(i64 12)
    %str_len = call i64 @codegen_int_to_string(i32 %value, i8* %str_buf)
    
    ; Store string in node
    %value_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 2
    store i8* %str_buf, i8** %value_ptr
    
    %len_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 3
    store i64 %str_len, i64* %len_ptr
    
    ; Set car/cdr to null
    %car_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 4
    store %ASTNode* null, %ASTNode** %car_ptr
    
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %cdr_ptr
    
    ret %ASTNode* %node_ptr
}

; Convert integer to string
; codegen_int_to_string: Convert integer to string representation
; Parameters:
;   value: Integer value
;   buf: Buffer to write to (must be at least 12 bytes)
; Returns: Length of string
define i64 @codegen_int_to_string(i32 %value, i8* %buf) {
entry:
    %is_zero = icmp eq i32 %value, 0
    br i1 %is_zero, label %write_zero, label %convert
    
write_zero:
    store i8 48, i8* %buf  ; '0'
    ret i64 1
    
convert:
    ; Build string backwards, then reverse
    %digits = alloca [10 x i8]
    %digit_count = alloca i32
    store i32 0, i32* %digit_count
    %val = alloca i32
    store i32 %value, i32* %val
    br label %digit_loop
    
digit_loop:
    %val_current = load i32, i32* %val
    %is_done = icmp eq i32 %val_current, 0
    br i1 %is_done, label %reverse, label %extract_digit
    
extract_digit:
    %remainder = urem i32 %val_current, 10
    %digit_char_i32 = add i32 %remainder, 48  ; Convert to '0'-'9'
    %digit_char = trunc i32 %digit_char_i32 to i8
    
    %count = load i32, i32* %digit_count
    %digit_ptr = getelementptr [10 x i8], [10 x i8]* %digits, i32 0, i32 %count
    store i8 %digit_char, i8* %digit_ptr
    
    %count_new = add i32 %count, 1
    store i32 %count_new, i32* %digit_count
    
    %val_new = udiv i32 %val_current, 10
    store i32 %val_new, i32* %val
    br label %digit_loop
    
reverse:
    %count_final = load i32, i32* %digit_count
    %i = alloca i32
    store i32 0, i32* %i
    br label %reverse_loop
    
reverse_loop:
    %i_val = load i32, i32* %i
    %count_check = load i32, i32* %digit_count
    %done = icmp uge i32 %i_val, %count_check
    br i1 %done, label %return_len, label %copy_digit
    
copy_digit:
    %src_idx = sub i32 %count_check, 1
    %src_idx_sub = sub i32 %src_idx, %i_val
    %src_ptr = getelementptr [10 x i8], [10 x i8]* %digits, i32 0, i32 %src_idx_sub
    %digit = load i8, i8* %src_ptr
    
    %dest_ptr = getelementptr i8, i8* %buf, i32 %i_val
    store i8 %digit, i8* %dest_ptr
    
    %i_new = add i32 %i_val, 1
    store i32 %i_new, i32* %i
    br label %reverse_loop
    
return_len:
    %count_ret = load i32, i32* %digit_count
    %count_ret_64 = zext i32 %count_ret to i64
    ret i64 %count_ret_64
}

; codegen_create_pair: defined in codegen.vibe
declare %ASTNode* @codegen_create_pair(%ASTNode*, %ASTNode*)

; codegen_create_cons: defined in codegen.vibe
declare %ASTNode* @codegen_create_cons(%ASTNode*, %ASTNode*)

; codegen_create_string_node: defined in codegen.vibe
declare %ASTNode* @codegen_create_string_node(i8*, i64)

; Store function type for later retrieval
; codegen_store_function_type: Store function type mapping
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Function name (not null-terminated)
;   name_len: Name length
;   func_type: LLVMTypeRef for function type
define void @codegen_store_function_type(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMTypeRef %func_type) {
entry:
    ; Validate function type is not null
    %func_type_null = icmp eq %LLVMTypeRef %func_type, null
    br i1 %func_type_null, label %skip_store, label %store_type
    
skip_store:
    ; Skip storing if type is null (shouldn't happen, but safety check)
    ret void
    
store_type:
    ; Create name node (string atom)
    %name_node = call %ASTNode* @codegen_create_string_node(i8* %name, i64 %name_len)
    
    ; Create type node - store LLVMTypeRef pointer in value field
    ; We'll use a special AST node type to store the type pointer
    %type_node = call i8* @malloc(i64 48)
    %type_node_ptr = bitcast i8* %type_node to %ASTNode*
    ; Initialize all fields to safe defaults
    %type_node_type_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 0
    store i32 0, i32* %type_node_type_ptr  ; AST_ATOM
    %type_node_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 1
    store i32 99, i32* %type_node_atom_type_ptr  ; Special marker: TOKEN_TYPE_REF = 99
    %type_node_value_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 2
    %func_type_as_i8 = bitcast %LLVMTypeRef %func_type to i8*
    store i8* %func_type_as_i8, i8** %type_node_value_ptr
    %type_node_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 3
    store i64 8, i64* %type_node_len_ptr  ; Size of pointer
    %type_node_car_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 4
    store %ASTNode* null, %ASTNode** %type_node_car_ptr
    %type_node_cdr_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %type_node_cdr_ptr
    %type_node_line_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 6
    store i32 0, i32* %type_node_line_ptr
    %type_node_column_ptr = getelementptr %ASTNode, %ASTNode* %type_node_ptr, i32 0, i32 7
    store i32 0, i32* %type_node_column_ptr
    
    ; Create (name type) pair
    %name_type_pair = call %ASTNode* @codegen_create_pair(%ASTNode* %name_node, %ASTNode* %type_node_ptr)
    
    ; Get current function_types list
    %function_types_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 11
    %current_types = load %ASTNode*, %ASTNode** %function_types_ptr
    
    ; Prepend to list
    %new_types_list = call %ASTNode* @codegen_create_cons(%ASTNode* %name_type_pair, %ASTNode* %current_types)
    store %ASTNode* %new_types_list, %ASTNode** %function_types_ptr
    
    br label %done
    
done:
    ret void
}

; Retrieve function type by name
; codegen_get_function_type: Look up function type by name
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Function name (not null-terminated)
;   name_len: Name length
; Returns: LLVMTypeRef for function type, or null if not found
define %LLVMTypeRef @codegen_get_function_type(%CodeGen* %cg, i8* %name, i64 %name_len) {
entry:
    ; Get function_types list
    %function_types_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 11
    %function_types = load %ASTNode*, %ASTNode** %function_types_ptr
    
    %types_null = icmp eq %ASTNode* %function_types, null
    br i1 %types_null, label %not_found, label %search_loop
    
search_loop:
    %current_pair = alloca %ASTNode*
    store %ASTNode* %function_types, %ASTNode** %current_pair
    br label %iterate
    
iterate:
    %pair_val = load %ASTNode*, %ASTNode** %current_pair
    %pair_null = icmp eq %ASTNode* %pair_val, null
    br i1 %pair_null, label %not_found, label %check_name
    
check_name:
    ; pair is (name type)
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    
    ; Get name from name node
    %stored_name_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %stored_name = load i8*, i8** %stored_name_ptr
    %stored_name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %stored_name_len = load i64, i64* %stored_name_len_ptr
    
    ; Compare names
    %len_match = icmp eq i64 %name_len, %stored_name_len
    br i1 %len_match, label %compare_names, label %next_pair
    
compare_names:
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %name, i8* %stored_name, i32 %name_len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %found, label %next_pair
    
found:
    ; Get type from pair: (name . (type . nil))
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 5
    %pair_cdr = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    
    %pair_cdr_null = icmp eq %ASTNode* %pair_cdr, null
    br i1 %pair_cdr_null, label %not_found, label %get_type_node
    
get_type_node:
    ; Get car of cdr (the type node)
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %not_found, label %extract_type
    
extract_type:
    ; Extract LLVMTypeRef from type node's value field
    %type_value_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_value = load i8*, i8** %type_value_ptr
    %func_type = bitcast i8* %type_value to %LLVMTypeRef
    ret %LLVMTypeRef %func_type
    
next_pair:
    %pair_cdr_next = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 5
    %next_pair_val = load %ASTNode*, %ASTNode** %pair_cdr_next
    store %ASTNode* %next_pair_val, %ASTNode** %current_pair
    br label %iterate
    
not_found:
    ret %LLVMTypeRef null
}

; Get function type from function value (reverse lookup)
; codegen_get_function_type_by_value: Look up function type by function value
; Parameters:
;   cg: Pointer to CodeGen structure
;   func_value: LLVMValueRef for the function
; Returns: LLVMTypeRef for function type, or null if not found
define %LLVMTypeRef @codegen_get_function_type_by_value(%CodeGen* %cg, %LLVMValueRef %func_value) {
entry:
    ; Get llvm_functions list
    %llvm_functions_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 14
    %functions = load %ASTNode*, %ASTNode** %llvm_functions_ptr
    
    %functions_null = icmp eq %ASTNode* %functions, null
    br i1 %functions_null, label %not_found_by_value, label %search_loop_by_value
    
search_loop_by_value:
    %current_by_value = alloca %ASTNode*
    store %ASTNode* %functions, %ASTNode** %current_by_value
    br label %iterate_by_value
    
iterate_by_value:
    %current_val_by_value = load %ASTNode*, %ASTNode** %current_by_value
    %current_null_by_value = icmp eq %ASTNode* %current_val_by_value, null
    br i1 %current_null_by_value, label %not_found_by_value, label %check_pair_by_value
    
check_pair_by_value:
    ; Get pair from car: (name . (func_value . func_type))
    %car_ptr_by_value = getelementptr %ASTNode, %ASTNode* %current_val_by_value, i32 0, i32 4
    %pair_by_value = load %ASTNode*, %ASTNode** %car_ptr_by_value
    %pair_null_by_value = icmp eq %ASTNode* %pair_by_value, null
    br i1 %pair_null_by_value, label %next_by_value, label %get_value_type_pair
    
get_value_type_pair:
    ; Get (func_value . func_type) from pair.cdr
    %pair_cdr_ptr_by_value = getelementptr %ASTNode, %ASTNode* %pair_by_value, i32 0, i32 5
    %value_type_pair_by_value = load %ASTNode*, %ASTNode** %pair_cdr_ptr_by_value
    %value_type_pair_null_by_value = icmp eq %ASTNode* %value_type_pair_by_value, null
    br i1 %value_type_pair_null_by_value, label %next_by_value, label %extract_func_value_by_value
    
extract_func_value_by_value:
    ; Get func_value from value_type_pair.car
    %value_type_car_ptr_by_value = getelementptr %ASTNode, %ASTNode* %value_type_pair_by_value, i32 0, i32 4
    %func_value_node_by_value = load %ASTNode*, %ASTNode** %value_type_car_ptr_by_value
    %func_value_node_null_by_value = icmp eq %ASTNode* %func_value_node_by_value, null
    br i1 %func_value_node_null_by_value, label %next_by_value, label %compare_values
    
compare_values:
    ; Extract stored func_value
    %func_value_ptr_field_by_value = getelementptr %ASTNode, %ASTNode* %func_value_node_by_value, i32 0, i32 2
    %stored_func_value_ptr = load i8*, i8** %func_value_ptr_field_by_value
    %stored_func_value = bitcast i8* %stored_func_value_ptr to %LLVMValueRef
    
    ; Compare function values (pointer comparison)
    %values_match = icmp eq %LLVMValueRef %stored_func_value, %func_value
    br i1 %values_match, label %extract_func_type_by_value, label %next_by_value
    
extract_func_type_by_value:
    ; Get func_type from value_type_pair.cdr
    %value_type_cdr_ptr_by_value = getelementptr %ASTNode, %ASTNode* %value_type_pair_by_value, i32 0, i32 5
    %func_type_node_by_value = load %ASTNode*, %ASTNode** %value_type_cdr_ptr_by_value
    %func_type_node_null_by_value = icmp eq %ASTNode* %func_type_node_by_value, null
    br i1 %func_type_node_null_by_value, label %not_found_by_value, label %cast_back_type
    
cast_back_type:
    ; Extract func_type
    %func_type_ptr_field_by_value = getelementptr %ASTNode, %ASTNode* %func_type_node_by_value, i32 0, i32 2
    %func_type_ptr_by_value = load i8*, i8** %func_type_ptr_field_by_value
    %func_type_ref_by_value = bitcast i8* %func_type_ptr_by_value to %LLVMTypeRef
    ret %LLVMTypeRef %func_type_ref_by_value
    
next_by_value:
    ; Move to next in list
    %cdr_ptr_by_value = getelementptr %ASTNode, %ASTNode* %current_val_by_value, i32 0, i32 5
    %cdr_by_value = load %ASTNode*, %ASTNode** %cdr_ptr_by_value
    store %ASTNode* %cdr_by_value, %ASTNode** %current_by_value
    br label %iterate_by_value
    
not_found_by_value:
    ret %LLVMTypeRef null
}

; codegen_dsl_undef: Handle llvm:undef form
; Syntax: (llvm:undef type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (type)
; Returns: LLVMValueRef for undef value of given type
define %LLVMValueRef @codegen_dsl_undef(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %extract_type

extract_type:
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_node_null = icmp eq %ASTNode* %type_node, null
    br i1 %type_node_null, label %error, label %get_type_string

get_type_string:
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_val = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr

    ; Resolve type string to LLVMTypeRef
    %undef_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_val, i64 %type_len)
    %undef_type_null = icmp eq %LLVMTypeRef %undef_type, null
    br i1 %undef_type_null, label %error, label %build_undef

build_undef:
    %undef_result = call %LLVMValueRef @llvm_get_undef(%LLVMTypeRef %undef_type)
    ret %LLVMValueRef %undef_result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_insertvalue: Handle llvm:insertvalue form
; Syntax: (llvm:insertvalue agg-val elt-val index)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (agg-val elt-val index)
; Returns: LLVMValueRef for new aggregate with value inserted
define %LLVMValueRef @codegen_dsl_insertvalue(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_agg

get_agg:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_agg

eval_agg:
    ; First argument: aggregate value
    %agg_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %agg_node = load %ASTNode*, %ASTNode** %agg_node_ptr
    %agg = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %agg_node)
    %agg_null = icmp eq %LLVMValueRef %agg, null
    br i1 %agg_null, label %error, label %get_elt

get_elt:
    ; Second argument: element value
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %args_cdr1_null = icmp eq %ASTNode* %args_cdr1, null
    br i1 %args_cdr1_null, label %error, label %eval_elt

eval_elt:
    %elt_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 4
    %elt_node = load %ASTNode*, %ASTNode** %elt_node_ptr
    %elt = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %elt_node)
    %elt_null = icmp eq %LLVMValueRef %elt, null
    br i1 %elt_null, label %error, label %get_index

get_index:
    ; Third argument: index (integer literal)
    %args_cdr2_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 5
    %args_cdr2 = load %ASTNode*, %ASTNode** %args_cdr2_ptr
    %args_cdr2_null = icmp eq %ASTNode* %args_cdr2, null
    br i1 %args_cdr2_null, label %error, label %parse_index

parse_index:
    %index_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr2, i32 0, i32 4
    %index_node = load %ASTNode*, %ASTNode** %index_node_ptr
    %index = call i32 @codegen_parse_int_from_ast(%ASTNode* %index_node)

    ; Build insertvalue instruction
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %result = call %LLVMValueRef @llvm_build_insert_value(%LLVMBuilderRef %builder, %LLVMValueRef %agg, %LLVMValueRef %elt, i32 %index, i8* %empty_str)
    ret %LLVMValueRef %result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_extractvalue: Handle llvm:extractvalue form
; Syntax: (llvm:extractvalue agg-val index)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (agg-val index)
; Returns: LLVMValueRef for extracted element
define %LLVMValueRef @codegen_dsl_extractvalue(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_agg

get_agg:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_agg

eval_agg:
    ; First argument: aggregate value
    %agg_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %agg_node = load %ASTNode*, %ASTNode** %agg_node_ptr
    %agg = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %agg_node)
    %agg_null = icmp eq %LLVMValueRef %agg, null
    br i1 %agg_null, label %error, label %get_index

get_index:
    ; Second argument: index (integer literal)
    %args_cdr1_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr1 = load %ASTNode*, %ASTNode** %args_cdr1_ptr
    %args_cdr1_null = icmp eq %ASTNode* %args_cdr1, null
    br i1 %args_cdr1_null, label %error, label %parse_index

parse_index:
    %index_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr1, i32 0, i32 4
    %index_node = load %ASTNode*, %ASTNode** %index_node_ptr
    %index = call i32 @codegen_parse_int_from_ast(%ASTNode* %index_node)

    ; Build extractvalue instruction
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %result = call %LLVMValueRef @llvm_build_extract_value(%LLVMBuilderRef %builder, %LLVMValueRef %agg, i32 %index, i8* %empty_str)
    ret %LLVMValueRef %result

error:
    ret %LLVMValueRef null
}

; codegen_dsl_urem: Handle llvm:urem form
; Syntax: (llvm:urem lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for unsigned remainder
define %LLVMValueRef @codegen_dsl_urem(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs
    
get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs
    
eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs
    
get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_urem
    
build_urem:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %urem_result = call %LLVMValueRef @llvm_build_urem(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %urem_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_udiv: Handle llvm:udiv form
; Syntax: (llvm:udiv lhs rhs)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (lhs rhs)
; Returns: LLVMValueRef for unsigned division
define %LLVMValueRef @codegen_dsl_udiv(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_lhs
    
get_lhs:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_lhs
    
eval_lhs:
    %lhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %lhs_node = load %ASTNode*, %ASTNode** %lhs_node_ptr
    %lhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %lhs_node)
    %lhs_null = icmp eq %LLVMValueRef %lhs, null
    br i1 %lhs_null, label %error, label %get_rhs
    
get_rhs:
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %rhs_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %rhs_node = load %ASTNode*, %ASTNode** %rhs_node_ptr
    %rhs = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %rhs_node)
    %rhs_null = icmp eq %LLVMValueRef %rhs, null
    br i1 %rhs_null, label %error, label %build_udiv
    
build_udiv:
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %udiv_result = call %LLVMValueRef @llvm_build_udiv(%LLVMBuilderRef %builder, %LLVMValueRef %lhs, %LLVMValueRef %rhs, i8* %empty_str)
    ret %LLVMValueRef %udiv_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_ptrtoint: Handle llvm:ptrtoint form
; Syntax: (llvm:ptrtoint value target-type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (value target-type)
; Returns: LLVMValueRef for pointer-to-integer conversion
define %LLVMValueRef @codegen_dsl_ptrtoint(%CodeGen* %cg, %ASTNode* %args) {
entry:
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_value

get_value:
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %eval_value

eval_value:
    ; Get value expression (first element)
    %value_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %value_node = load %ASTNode*, %ASTNode** %value_node_ptr
    
    ; Evaluate value expression
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_node)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %error, label %get_target_type

get_target_type:
    ; Get target type (second element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve target type
    %target_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %target_type_null = icmp eq %LLVMTypeRef %target_type, null
    br i1 %target_type_null, label %error, label %build_ptrtoint

build_ptrtoint:
    ; Build ptrtoint instruction
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %ptrtoint_result = call %LLVMValueRef @llvm_build_ptrtoint(%LLVMBuilderRef %builder, %LLVMValueRef %value, %LLVMTypeRef %target_type, i8* %name_str)
    ret %LLVMValueRef %ptrtoint_result

error:
    ret %LLVMValueRef null
}

; Evaluate DSL body (list of expressions)
; codegen_eval_dsl_body: Evaluate list of DSL expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   body: AST node list of DSL expressions
define void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %body) {
entry:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_dsl_body_start, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %body_null = icmp eq %ASTNode* %body, null
    br i1 %body_null, label %done, label %check_body_type
    
check_body_type:
    ; Verify body is a list (AST_LIST = 1)
    %body_type_ptr = getelementptr %ASTNode, %ASTNode* %body, i32 0, i32 0
    %body_type = load i32, i32* %body_type_ptr
    %is_list = icmp eq i32 %body_type, 1  ; AST_LIST
    
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_body_type_check, i32 0, i32 0), i32 %body_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    br i1 %is_list, label %eval_loop, label %done
    
eval_loop:
    %current = alloca %ASTNode*
    store %ASTNode* %body, %ASTNode** %current
    br label %eval_iter
    
eval_iter:
    %current_val = load %ASTNode*, %ASTNode** %current
    %current_null = icmp eq %ASTNode* %current_val, null
    br i1 %current_null, label %done, label %eval_expr
    
eval_expr:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 4
    %car = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_dsl_body_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Evaluate expression (result is discarded for statements)
    ; Note: This should generate instructions including terminators like ret
    %expr_result = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %car)
    
    ; Move to next
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current
    br label %eval_iter
    
done:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([23 x i8], [23 x i8]* @.str.debug_dsl_body_done, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret void
}

; Declare external functions
declare i8* @malloc(i64)
declare i8* @realloc(i8*, i64)
declare void @free(i8*)
declare i64 @strlen(i8*)
declare i32 @memcmp(i8*, i8*, i64)
declare i32 @strncmp(i8*, i8*, i32)
; LLVM memcpy intrinsic - signature matches runtime.ll
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
