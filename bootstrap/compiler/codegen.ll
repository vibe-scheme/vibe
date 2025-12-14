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

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

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
;   param_names: ASTNode* list of (name index) pairs for parameter name mapping
;   local_values: ASTNode* list of (name LLVMValueRef) pairs for local value binding
;   function_types: ASTNode* list of (name LLVMTypeRef) pairs for function type mapping
%CodeGen = type { i8*, i64, i64, i32, i32, %LLVMContextRef, %LLVMModuleRef, %LLVMBuilderRef, %LLVMValueRef, %ASTNode*, %ASTNode*, %ASTNode* }

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
declare %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)
declare %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef, i8*, i32, i32)
declare %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef, i64, i32)
declare %LLVMValueRef @llvm_create_constant_null(%LLVMTypeRef)
declare %LLVMValueRef @llvm_add_function(%LLVMModuleRef, i8*, %LLVMTypeRef)
declare %LLVMValueRef @llvm_get_param(%LLVMValueRef, i32)
declare void @llvm_set_value_name(%LLVMValueRef, i8*)
declare %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef, i8*)
declare %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef)
declare void @llvm_dispose_builder(%LLVMBuilderRef)
declare void @llvm_position_builder_at_end(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_build_ret_void(%LLVMBuilderRef)
declare %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef, %LLVMValueRef)
declare %LLVMValueRef @llvm_build_call(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
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
declare i32 @open(i8*, i32, ...)
declare i64 @write(i32, i8*, i32)
declare i32 @close(i32)

; Initialize code generator
; codegen_init: Initialize code generator
; Returns: Pointer to CodeGen structure
define %CodeGen* @codegen_init() {
entry:
    ; Allocate CodeGen structure (now includes LLVM context/module/builder pointers + DSL fields + function types)
    %cg = call i8* @malloc(i64 88)  ; 8 + 8 + 8 + 4 + 4 + 8 + 8 + 8 + 8 + 8 + 8 + 8 = 88 bytes
    %cg_ptr = bitcast i8* %cg to %CodeGen*
    
    ; Initialize LLVM FFI
    %ffi_init_result = call i32 @llvm_ffi_init()
    
    ; Create LLVM context
    %llvm_context = call %LLVMContextRef @llvm_create_context()
    %context_null = icmp eq %LLVMContextRef %llvm_context, null
    br i1 %context_null, label %error, label %create_module
    
create_module:
    ; Create LLVM module
    ; Use bitcast to convert the constant array pointer to i8*
    %module_name_array = bitcast [5 x i8]* @.str.module_name to i8*
    %llvm_module = call %LLVMModuleRef @llvm_create_module(%LLVMContextRef %llvm_context, i8* %module_name_array)
    %module_null = icmp eq %LLVMModuleRef %llvm_module, null
    br i1 %module_null, label %dispose_context, label %set_target
    
set_target:
    ; Set target triple via LLVM API
    ; Use bitcast to convert the constant array pointer to i8*
    %target_triple_array = bitcast [27 x i8]* @.str.target_triple_value to i8*
    call void @llvm_set_target(%LLVMModuleRef %llvm_module, i8* %target_triple_array)
    
    ; Set data layout via LLVM API
    %data_layout_array = bitcast [35 x i8]* @.str.data_layout_value to i8*
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
    
    ; Write target triple header (46 bytes without null terminator) - text IR approach (backward compatibility)
    call void @codegen_append(%CodeGen* %cg_ptr, i8* getelementptr inbounds ([47 x i8], [47 x i8]* @.str.target_triple, i32 0, i32 0), i64 46)
    
    ; Add printf declaration via LLVM API
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %llvm_context)
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %llvm_context)
    %i8_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type, i32 0)
    
    ; Create function type: i32 (i8*, ...) - vararg function
    %printf_param_types = alloca %LLVMTypeRef, i32 1
    store %LLVMTypeRef %i8_ptr_type, %LLVMTypeRef* %printf_param_types
    %printf_func_type = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %i32_type, %LLVMTypeRef* %printf_param_types, i32 1, i32 1)
    
    ; Add printf function to module
    %printf_name = getelementptr [7 x i8], [7 x i8]* @.str.printf_name, i32 0, i32 0
    %printf_func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %llvm_module, i8* %printf_name, %LLVMTypeRef %printf_func_type)
    
    ; Note: ExternalLinkage is the default for functions added via LLVMAddFunction
    ; We don't need to set linkage explicitly for external declarations
    
    ; Write printf declaration (41 bytes without null terminator) - text IR approach (backward compatibility)
    call void @codegen_append(%CodeGen* %cg_ptr, i8* getelementptr inbounds ([42 x i8], [42 x i8]* @.str.printf_decl, i32 0, i32 0), i64 41)
    
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
; codegen_define_bitcode_type: Generate LLVM type definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-bitcode-type form
; Returns: 0 on success, -1 on error
; Syntax: (define-bitcode-type TypeName (field1 type1) (field2 type2) ...)
; TODO: Future version will use llvm_create_struct_type() via FFI instead of text IR
define i32 @codegen_define_bitcode_type(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; AST structure: LIST { ATOM: "define-bitcode-type", ATOM: "TypeName", LIST: fields, ... }
    ; Get type name (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %type_name_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %type_name_node = load %ASTNode*, %ASTNode** %type_name_node_ptr
    %type_name_val_ptr = getelementptr %ASTNode, %ASTNode* %type_name_node, i32 0, i32 2
    %type_name = load i8*, i8** %type_name_val_ptr
    
    ; Get fields list (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %fields_list = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    
    ; Get type name length
    %type_name_len_ptr = getelementptr %ASTNode, %ASTNode* %type_name_node, i32 0, i32 3
    %type_name_len = load i64, i64* %type_name_len_ptr
    
    ; Generate: %TypeName = type { type1, type2, ... }
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.percent, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %type_name, i64 %type_name_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.type_equals, i32 0, i32 0), i64 7)
    call void @codegen_append_type_fields(%CodeGen* %cg, %ASTNode* %fields_list)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0), i64 1)
    
    ret i32 0
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
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.comma_space, i32 0, i32 0), i64 2)
    %next_car_ptr = getelementptr %ASTNode, %ASTNode* %next, i32 0, i32 4
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
    
    ; Check for more fields
    %next_cdr_ptr = getelementptr %ASTNode, %ASTNode* %next, i32 0, i32 5
    %next_next = load %ASTNode*, %ASTNode** %next_cdr_ptr
    %has_more_more = icmp ne %ASTNode* %next_next, null
    br i1 %has_more_more, label %append_more, label %done
    
done:
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rbrace, i32 0, i32 0), i64 1)
    ret void
}

; Handle define-bitcode-constant AST node
; codegen_define_bitcode_constant: Generate LLVM constant definition
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-bitcode-constant form
; Returns: 0 on success, -1 on error
; Syntax: (define-bitcode-constant name type value)
; TODO: Future version will use llvm_create_constant_string() via FFI instead of text IR
define i32 @codegen_define_bitcode_constant(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; AST structure: LIST { ATOM: "define-bitcode-constant", ATOM: "name", ATOM: "type", ATOM/STRING: value }
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
    ; Get LLVM context and module for parsing
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %either_null = or i1 %context_null, %module_null
    ; Parse if both context and module are non-null, otherwise fall back to text IR
    br i1 %either_null, label %text_only_constant, label %parse_constant
    
parse_constant:
    ; Build constant IR text in a buffer for parsing
    ; Estimate buffer size: module header (~100) + constant definition
    ; Account for escaped bytevector data (can be up to 3x original size for null bytes)
    ; Add extra padding for safety
    %value_len_escaped = mul i64 %value_len, 3  ; Worst case: all null bytes
    %const_ir_size = add i64 500, %name_len  ; Increased base size
    %const_ir_size2 = add i64 %const_ir_size, %type_len
    %const_ir_size3 = add i64 %const_ir_size2, %value_len_escaped
    %const_ir_size4 = add i64 %const_ir_size3, 100  ; Extra padding
    %const_ir_buf = call i8* @malloc(i64 %const_ir_size4)
    %buf_null_const = icmp eq i8* %const_ir_buf, null
    br i1 %buf_null_const, label %text_only_constant, label %build_constant_ir
    
build_constant_ir:
    ; Build module IR with constant: "target datalayout = \"...\"\ntarget triple = \"...\"\n\n@name = constant type c\"...\"\n"
    %pos_const = alloca i64
    store i64 0, i64* %pos_const
    
    ; Write data layout and target triple (reuse logic from codegen_parse_function_ir)
    %data_layout_array = bitcast [38 x i8]* @.str.data_layout_value to i8*
    %data_layout_len = add i64 37, 0
    %data_layout_prefix_len = add i64 21, 0
    %data_layout_suffix_len = add i64 2, 0
    %data_layout_total = add i64 %data_layout_prefix_len, %data_layout_len
    %data_layout_with_suffix = add i64 %data_layout_total, %data_layout_suffix_len
    
    %target_triple_array = bitcast [27 x i8]* @.str.target_triple_value to i8*
    %target_triple_len = add i64 26, 0
    %target_triple_prefix_len = add i64 17, 0
    %target_triple_suffix_len = add i64 3, 0
    %target_triple_total = add i64 %target_triple_prefix_len, %target_triple_len
    %target_triple_with_suffix = add i64 %target_triple_total, %target_triple_suffix_len
    
    %module_prefix_len = add i64 %data_layout_with_suffix, %target_triple_with_suffix
    
    ; Write data layout
    %pos_val_c1 = load i64, i64* %pos_const
    %dest_c1 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c1
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c1, i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.data_layout_prefix, i32 0, i32 0), i64 21, i1 false)
    %pos_val_c2 = add i64 %pos_val_c1, 21
    store i64 %pos_val_c2, i64* %pos_const
    
    %pos_val_c3 = load i64, i64* %pos_const
    %dest_c2 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c3
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c2, i8* %data_layout_array, i64 %data_layout_len, i1 false)
    %pos_val_c4 = add i64 %pos_val_c3, %data_layout_len
    store i64 %pos_val_c4, i64* %pos_const
    
    %pos_val_c5 = load i64, i64* %pos_const
    %dest_c3 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c5
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c3, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.data_layout_suffix, i32 0, i32 0), i64 2, i1 false)
    %pos_val_c6 = add i64 %pos_val_c5, 2
    store i64 %pos_val_c6, i64* %pos_const
    
    ; Write target triple
    %pos_val_c7 = load i64, i64* %pos_const
    %dest_c4 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c7
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c4, i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.target_triple_prefix, i32 0, i32 0), i64 17, i1 false)
    %pos_val_c8 = add i64 %pos_val_c7, 17
    store i64 %pos_val_c8, i64* %pos_const
    
    %pos_val_c9 = load i64, i64* %pos_const
    %dest_c5 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c9
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c5, i8* %target_triple_array, i64 %target_triple_len, i1 false)
    %pos_val_c10 = add i64 %pos_val_c9, %target_triple_len
    store i64 %pos_val_c10, i64* %pos_const
    
    %pos_val_c11 = load i64, i64* %pos_const
    %dest_c6 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c11
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c6, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.target_triple_suffix, i32 0, i32 0), i64 3, i1 false)
    %pos_val_c12 = add i64 %pos_val_c11, 3
    store i64 %pos_val_c12, i64* %pos_const
    
    ; Write constant definition: "@name = constant type c\"...\"\n"
    %pos_val_c13 = load i64, i64* %pos_const
    %dest_c7 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c13
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c7, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1, i1 false)
    %pos_val_c14 = add i64 %pos_val_c13, 1
    store i64 %pos_val_c14, i64* %pos_const
    
    %pos_val_c15 = load i64, i64* %pos_const
    %dest_c8 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c15
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c8, i8* %name, i64 %name_len, i1 false)
    %pos_val_c16 = add i64 %pos_val_c15, %name_len
    store i64 %pos_val_c16, i64* %pos_const
    
    %pos_val_c17 = load i64, i64* %pos_const
    %dest_c9 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c17
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c9, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.constant_equals, i32 0, i32 0), i64 11, i1 false)
    %pos_val_c18 = add i64 %pos_val_c17, 11
    store i64 %pos_val_c18, i64* %pos_const
    
    %pos_val_c19 = load i64, i64* %pos_const
    %dest_c10 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c19
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c10, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1, i1 false)
    %pos_val_c20 = add i64 %pos_val_c19, 1
    store i64 %pos_val_c20, i64* %pos_const
    
    %pos_val_c21 = load i64, i64* %pos_const
    %dest_c11 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c21
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c11, i8* %type, i64 %type_len, i1 false)
    %pos_val_c22 = add i64 %pos_val_c21, %type_len
    store i64 %pos_val_c22, i64* %pos_const
    
    %pos_val_c23 = load i64, i64* %pos_const
    %dest_c12 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c23
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c12, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1, i1 false)
    %pos_val_c24 = add i64 %pos_val_c23, 1
    store i64 %pos_val_c24, i64* %pos_const
    
    %pos_val_c25 = load i64, i64* %pos_const
    %dest_c13 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c25
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c13, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.c_quote_open, i32 0, i32 0), i64 2, i1 false)
    %pos_val_c26 = add i64 %pos_val_c25, 2
    store i64 %pos_val_c26, i64* %pos_const
    
    ; Append bytevector data with escaping using helper function
    call void @codegen_write_bytevector_to_buffer(i8* %const_ir_buf, i64* %pos_const, i8* %value, i64 %value_len)
    %pos_val_c28 = load i64, i64* %pos_const
    
    %pos_val_c29 = load i64, i64* %pos_const
    %dest_c15 = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c29
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest_c15, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.quote, i32 0, i32 0), i64 1, i1 false)
    %pos_val_c30 = add i64 %pos_val_c29, 1
    store i64 %pos_val_c30, i64* %pos_const
    
    %pos_val_c31 = load i64, i64* %pos_const
    %newline_ptr_const = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c31
    store i8 10, i8* %newline_ptr_const
    %pos_val_c32 = add i64 %pos_val_c31, 1
    %null_ptr_const = getelementptr i8, i8* %const_ir_buf, i64 %pos_val_c32
    store i8 0, i8* %null_ptr_const
    
    ; Parse constant IR into module
    %total_len_const = sub i64 %pos_val_c32, 1
    %temp_module_ptr_const = alloca %LLVMModuleRef
    %parse_result_const = call i32 @llvm_parse_ir_in_context(%LLVMContextRef %context, i8* %const_ir_buf, i64 %total_len_const, %LLVMModuleRef* %temp_module_ptr_const)
    
    ; Free buffer
    call void @free(i8* %const_ir_buf)
    
    ; Check parse result
    %parse_failed_const = icmp ne i32 %parse_result_const, 0
    br i1 %parse_failed_const, label %text_only_constant, label %link_constant
    
link_constant:
    ; Link temp module into main module
    %temp_module_const = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr_const
    %temp_module_null_const = icmp eq %LLVMModuleRef %temp_module_const, null
    br i1 %temp_module_null_const, label %text_only_constant, label %do_link_const
    
do_link_const:
    %link_result_const = call i32 @llvm_link_modules2(%LLVMModuleRef %module, %LLVMModuleRef %temp_module_const)
    %link_failed_const = icmp ne i32 %link_result_const, 0
    br i1 %link_failed_const, label %dispose_and_error_const, label %verify_after_link_const
    
verify_after_link_const:
    ; Verify module after linking (action 2 = print to stderr, but we'll just check return value)
    %verify_error_msg_const = alloca i8*
    store i8* null, i8** %verify_error_msg_const
    %verify_result_const = call i32 @llvm_verify_module(%LLVMModuleRef %module, i32 1, i8** %verify_error_msg_const)
    ; Verification errors are warnings, not fatal - continue anyway
    br label %dispose_temp_const
    
dispose_temp_const:
    ; Don't dispose temp module after linking - LLVMLinkModules2 automatically handles cleanup
    ; Disposing it causes a crash because the module is already invalidated after linking
    ; Linking succeeded - constant is now in main module
    ret i32 0
    
dispose_and_error_const:
    ; Don't dispose temp module - if linking failed, module is still valid and should be disposed
    ; But to be safe, we'll skip disposal (small memory leak on error path is acceptable)
    ; call void @llvm_dispose_module(%LLVMModuleRef %temp_module_const)
    br label %text_only_constant
    
text_only_constant:
    ; Also generate text IR for backward compatibility
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
    ; DEBUG: Write that we're processing define-bitcode-function
    %debug_define_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_define_fd = call i32 @open(i8* %debug_define_name, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_define_fd_valid = icmp sge i32 %debug_define_fd, 0
    br i1 %debug_define_fd_valid, label %write_define_debug, label %continue_define
    
write_define_debug:
    %define_msg = getelementptr [40 x i8], [40 x i8]* @.str.processing_define_bitcode, i32 0, i32 0
    call i64 @write(i32 %debug_define_fd, i8* %define_msg, i32 39)
    call i32 @close(i32 %debug_define_fd)
    br label %continue_define
    
continue_define:
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
    
    ; DEBUG: Write function IR to debug file before parsing
    ; This helps us see what IR is being generated
    %debug_func_ir_name = getelementptr [20 x i8], [20 x i8]* @.str.debug_func_ir, i32 0, i32 0
    %debug_fd = call i32 @open(i8* %debug_func_ir_name, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_fd_valid = icmp sge i32 %debug_fd, 0
    br i1 %debug_fd_valid, label %write_debug, label %parse_func
    
write_debug:
    %pos_val17_int = trunc i64 %pos_val17 to i32
    call i64 @write(i32 %debug_fd, i8* %func_def_buf, i32 %pos_val17_int)
    call i32 @close(i32 %debug_fd)
    br label %parse_func
    
parse_func:
    ; DEBUG: Write that we're calling codegen_parse_function_ir
    %debug_parse_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_parse_fd = call i32 @open(i8* %debug_parse_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_parse_fd_valid = icmp sge i32 %debug_parse_fd, 0
    br i1 %debug_parse_fd_valid, label %write_parse_debug, label %do_parse
    
write_parse_debug:
    %parse_msg = getelementptr [34 x i8], [34 x i8]* @.str.calling_parse_func_ir, i32 0, i32 0
    call i64 @write(i32 %debug_parse_fd, i8* %parse_msg, i32 33)
    call i32 @close(i32 %debug_parse_fd)
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
    ; DEBUG: Write that we're checking function before call
    %debug_check_before_call_name = getelementptr [21 x i8], [21 x i8]* @.str.debug_call, i32 0, i32 0
    %debug_check_before_call_fd = call i32 @open(i8* %debug_check_before_call_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_check_before_call_fd_valid = icmp sge i32 %debug_check_before_call_fd, 0
    br i1 %debug_check_before_call_fd_valid, label %write_check_before_call, label %lookup_func
    
write_check_before_call:
    %check_before_call_msg = getelementptr [39 x i8], [39 x i8]* @.str.checking_func_before_call, i32 0, i32 0
    call i64 @write(i32 %debug_check_before_call_fd, i8* %check_before_call_msg, i32 38)
    %func_name_len_check = call i64 @strlen(i8* %func_name)
    %func_name_len_check_int = trunc i64 %func_name_len_check to i32
    call i64 @write(i32 %debug_check_before_call_fd, i8* %func_name, i32 %func_name_len_check_int)
    %newline_check = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_check_before_call_fd, i8* %newline_check, i32 1)
    call i32 @close(i32 %debug_check_before_call_fd)
    br label %lookup_func
    
lookup_func:
    ; Look up function in module
    ; Note: Function names in LLVM are stored without @ prefix
    %func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %func_name)
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error_not_found, label %build_call

error_not_found:
    ; Function not found in module - write debug output and return error
    ; DEBUG: Write function name being looked up to debug file
    %debug_call_name = getelementptr [21 x i8], [21 x i8]* @.str.debug_call, i32 0, i32 0
    %debug_call_fd = call i32 @open(i8* %debug_call_name, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_call_fd_valid = icmp sge i32 %debug_call_fd, 0
    br i1 %debug_call_fd_valid, label %write_call_debug, label %return_error
    
write_call_debug:
    %call_not_found_prefix = getelementptr [36 x i8], [36 x i8]* @.str.func_not_found_in_call, i32 0, i32 0
    call i64 @write(i32 %debug_call_fd, i8* %call_not_found_prefix, i32 35)
    %func_name_len_call = call i64 @strlen(i8* %func_name)
    %func_name_len_call_int = trunc i64 %func_name_len_call to i32
    call i64 @write(i32 %debug_call_fd, i8* %func_name, i32 %func_name_len_call_int)
    %newline_char_call = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_call_fd, i8* %newline_char_call, i32 1)
    call i32 @close(i32 %debug_call_fd)
    br label %return_error
    
return_error:
    ; TODO: This should not happen if functions are properly linked
    ret i32 -1
    
build_call:
    ; Get context for types
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    ; For printf, function type is i32 (i8*, ...)
    ; Get i32 and i8* types
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
    
    ; Get the function's actual type from the function value
    ; Function values have pointer type, so get the pointee type (the function signature)
    %func_ptr_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    %func_ptr_type_null = icmp eq %LLVMTypeRef %func_ptr_type, null
    br i1 %func_ptr_type_null, label %text_only, label %get_func_type
    
get_func_type:
    ; Look up stored function type by name
    %func_name_len_lookup = call i64 @strlen(i8* %func_name)
    %stored_func_type = call %LLVMTypeRef @codegen_get_function_type(%CodeGen* %cg, i8* %func_name, i64 %func_name_len_lookup)
    %stored_type_null = icmp eq %LLVMTypeRef %stored_func_type, null
    br i1 %stored_type_null, label %text_only, label %build_call_inst
    
build_call_inst:
    ; Build call instruction using the stored function type
    ; Use empty string instead of null for name (LLVMBuildCall2 may not handle null properly)
    %empty_str_call = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %call_result = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %stored_func_type, %LLVMValueRef %func, %LLVMValueRef* %args_ptr, i32 %args_count, i8* %empty_str_call)
    br label %done
    
text_only:
    ; Generate: call void @func_name(args...)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.call_void, i32 0, i32 0), i64 9)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    %func_name_len = call i64 @strlen(i8* %func_name)
    call void @codegen_append(%CodeGen* %cg, i8* %func_name, i64 %func_name_len)
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
define i32 @codegen_main(%CodeGen* %cg, %ASTNode* %exprs) {
entry:
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
    
    ; DEBUG: Write function call being processed to debug file
    %debug_top_level_name = getelementptr [25 x i8], [25 x i8]* @.str.debug_top_level, i32 0, i32 0
    %debug_top_level_fd = call i32 @open(i8* %debug_top_level_name, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_top_level_fd_valid = icmp sge i32 %debug_top_level_fd, 0
    br i1 %debug_top_level_fd_valid, label %write_top_level_debug, label %do_call
    
write_top_level_debug:
    %processing_call_prefix = getelementptr [27 x i8], [27 x i8]* @.str.processing_call, i32 0, i32 0
    call i64 @write(i32 %debug_top_level_fd, i8* %processing_call_prefix, i32 26)
    %func_name_len_top = call i64 @strlen(i8* %func_name)
    %func_name_len_top_int = trunc i64 %func_name_len_top to i32
    call i64 @write(i32 %debug_top_level_fd, i8* %func_name, i32 %func_name_len_top_int)
    %newline_char_top = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_top_level_fd, i8* %newline_char_top, i32 1)
    call i32 @close(i32 %debug_top_level_fd)
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
    %data_layout_array = bitcast [38 x i8]* @.str.data_layout_value to i8*
    %data_layout_len = add i64 37, 0  ; length without null (e-m:o-i64:64-f80:128-n8:16:32:64-S128 = 37 chars)
    %data_layout_prefix_len = add i64 21, 0  ; "target datalayout = \"" (21 chars)
    %data_layout_suffix_len = add i64 2, 0   ; "\"\n" (2 chars)
    %data_layout_total = add i64 %data_layout_prefix_len, %data_layout_len
    %data_layout_with_suffix = add i64 %data_layout_total, %data_layout_suffix_len
    
    %target_triple_array = bitcast [27 x i8]* @.str.target_triple_value to i8*
    %target_triple_len = add i64 26, 0  ; length without null (x86_64-apple-macosx10.15.0 = 26 chars)
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
    
    ; DEBUG: Write wrapped module IR to debug file before parsing
    %debug_module_ir_name = getelementptr [20 x i8], [20 x i8]* @.str.debug_module_ir, i32 0, i32 0
    %debug_module_fd = call i32 @open(i8* %debug_module_ir_name, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_module_fd_valid = icmp sge i32 %debug_module_fd, 0
    br i1 %debug_module_fd_valid, label %write_module_debug, label %parse_module
    
write_module_debug:
    %total_len_int = trunc i64 %total_len to i32
    call i64 @write(i32 %debug_module_fd, i8* %module_ir_buf, i32 %total_len_int)
    call i32 @close(i32 %debug_module_fd)
    br label %parse_module
    
parse_module:
    ; Parse into temporary module (temp_module_ptr already allocated in entry block)
    ; Note: LLVMParseIRInContext creates the module itself (it's an output parameter)
    %parse_result = call i32 @llvm_parse_ir_in_context(%LLVMContextRef %context, i8* %module_ir_buf, i64 %total_len, %LLVMModuleRef* %temp_module_ptr)
    
    ; Free buffer
    call void @free(i8* %module_ir_buf)
    
    ; DEBUG: Write parse result to debug file
    %debug_parse_result_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_parse_result_fd = call i32 @open(i8* %debug_parse_result_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_parse_result_fd_valid = icmp sge i32 %debug_parse_result_fd, 0
    br i1 %debug_parse_result_fd_valid, label %write_parse_result_debug, label %check_parse_result
    
write_parse_result_debug:
    ; Check if parse succeeded (result == 0) or failed (result != 0)
    %parse_result_zero = icmp eq i32 %parse_result, 0
    br i1 %parse_result_zero, label %write_parse_success, label %write_parse_failure
    
write_parse_success:
    %parse_success_msg = getelementptr [34 x i8], [34 x i8]* @.str.parse_succeeded, i32 0, i32 0
    call i64 @write(i32 %debug_parse_result_fd, i8* %parse_success_msg, i32 33)
    %newline_parse_success = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_parse_result_fd, i8* %newline_parse_success, i32 1)
    call i32 @close(i32 %debug_parse_result_fd)
    br label %check_parse_result
    
write_parse_failure:
    %parse_failure_msg = getelementptr [32 x i8], [32 x i8]* @.str.parse_failed, i32 0, i32 0
    call i64 @write(i32 %debug_parse_result_fd, i8* %parse_failure_msg, i32 31)
    %newline_parse_failure = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_parse_result_fd, i8* %newline_parse_failure, i32 1)
    call i32 @close(i32 %debug_parse_result_fd)
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
    ; Note: Don't dispose temp module - LLVMLinkModules2 invalidates it
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
; codegen_emit_debug_files: Emit debug bitcode and IR files for inspection
; Parameters:
;   cg: Pointer to CodeGen structure
;   base_filename: Base filename (without extension)
; Returns: 0 on success, -1 on error
define i32 @codegen_emit_debug_files(%CodeGen* %cg, i8* %base_filename) {
entry:
    ; Get module from CodeGen structure
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    %module_null = icmp eq %LLVMModuleRef %module, null
    br i1 %module_null, label %error, label %emit_files
    
emit_files:
    ; Build debug filenames: base_filename.debug.bc and base_filename.debug.ll
    ; For simplicity, we'll use fixed suffixes
    ; TODO: Implement proper string concatenation for filenames
    ; For now, just emit to fixed debug filenames
    %debug_bc_name = getelementptr [20 x i8], [20 x i8]* @.str.debug_bc, i32 0, i32 0
    %debug_ll_name = getelementptr [20 x i8], [20 x i8]* @.str.debug_ll, i32 0, i32 0
    
    ; Write bitcode file
    %bc_error_msg = alloca i8*
    store i8* null, i8** %bc_error_msg
    %bc_result = call i32 @llvm_write_bitcode_to_file(%LLVMModuleRef %module, i8* %debug_bc_name)
    %bc_failed = icmp ne i32 %bc_result, 0
    br i1 %bc_failed, label %error, label %write_ir
    
write_ir:
    ; Print IR to file
    %ir_error_msg = alloca i8*
    store i8* null, i8** %ir_error_msg
    %ir_result = call i32 @llvm_print_module_to_file(%LLVMModuleRef %module, i8* %debug_ll_name, i8** %ir_error_msg)
    %ir_failed = icmp ne i32 %ir_result, 0
    br i1 %ir_failed, label %error, label %verify_module
    
verify_module:
    ; Verify module
    %verify_error_msg = alloca i8*
    store i8* null, i8** %verify_error_msg
    %verify_result = call i32 @llvm_verify_module(%LLVMModuleRef %module, i32 1, i8** %verify_error_msg)
    ; Verification errors are warnings, not fatal
    br label %success
    
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
    %triple_array = bitcast [27 x i8]* @.str.target_triple_value to i8*
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

; String literals
@.str.target_triple = private unnamed_addr constant [47 x i8] c"target triple = \22x86_64-apple-macosx10.15.0\22\0A\0A\00"
@.str.printf_decl = private unnamed_addr constant [42 x i8] c"declare i32 @printf(i8* nocapture, ...)\0A\0A\00"
@.str.module_name = private unnamed_addr constant [5 x i8] c"vibe\00"
@.str.target_triple_value = private unnamed_addr constant [27 x i8] c"x86_64-apple-macosx10.15.0\00"
@.str.data_layout_value = private unnamed_addr constant [38 x i8] c"e-m:o-i64:64-f80:128-n8:16:32:64-S128\00"
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
@.str.debug_bc = private unnamed_addr constant [16 x i8] c"debug_output.bc\00"
@.str.debug_ll = private unnamed_addr constant [16 x i8] c"debug_output.ll\00"
@.str.debug_func_ir = private unnamed_addr constant [17 x i8] c"debug_func_ir.ll\00"
@.str.debug_module_ir = private unnamed_addr constant [19 x i8] c"debug_module_ir.ll\00"
@.str.debug_verify = private unnamed_addr constant [21 x i8] c"debug_verify_func.ll\00"
@.str.debug_call = private unnamed_addr constant [21 x i8] c"debug_call_lookup.ll\00"
@.str.debug_top_level = private unnamed_addr constant [25 x i8] c"debug_top_level_exprs.ll\00"
@.str.debug_extract = private unnamed_addr constant [27 x i8] c"debug_extract_func_name.ll\00"
@.str.func_not_found_after_link = private unnamed_addr constant [42 x i8] c"ERROR: Function not found after linking: \00"
@.str.func_not_found_in_call = private unnamed_addr constant [36 x i8] c"ERROR: Function not found in call: \00"
@.str.processing_call = private unnamed_addr constant [27 x i8] c"Processing function call: \00"
@.str.func_name_extraction_failed = private unnamed_addr constant [47 x i8] c"ERROR: Failed to extract function name from IR\00"
@.str.extracting_from_ir = private unnamed_addr constant [32 x i8] c"Extracting function name from: \00"
@.str.extracted_name = private unnamed_addr constant [26 x i8] c"Extracted function name: \00"
@.str.reached_verify_after_link = private unnamed_addr constant [33 x i8] c"DEBUG: Reached verify_after_link\00"
@.str.about_to_link = private unnamed_addr constant [22 x i8] c"About to link modules\00"
@.str.processing_define_bitcode = private unnamed_addr constant [40 x i8] c"Processing define-bitcode-function node\00"
@.str.calling_parse_func_ir = private unnamed_addr constant [34 x i8] c"Calling codegen_parse_function_ir\00"
@.str.parse_succeeded = private unnamed_addr constant [34 x i8] c"DEBUG: Parse succeeded (result=0)\00"
@.str.parse_failed = private unnamed_addr constant [32 x i8] c"DEBUG: Parse failed (result!=0)\00"
@.str.link_succeeded = private unnamed_addr constant [33 x i8] c"DEBUG: Link succeeded (result=0)\00"
@.str.link_failed = private unnamed_addr constant [31 x i8] c"DEBUG: Link failed (result!=0)\00"
@.str.external_hello_string = private unnamed_addr constant [45 x i8] c"@hello_string = external constant [14 x i8]\0A\00"
@.str.func_found_after_link = private unnamed_addr constant [36 x i8] c"DEBUG: Function found after linking\00"
@.str.checking_func_before_call = private unnamed_addr constant [39 x i8] c"DEBUG: Checking function before call: \00"
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
@.str.dsl_gep = private unnamed_addr constant [9 x i8] c"llvm-gep\00"
@.str.dsl_call = private unnamed_addr constant [10 x i8] c"llvm-call\00"
@.str.dsl_ret_void = private unnamed_addr constant [14 x i8] c"llvm-ret-void\00"
@.str.dsl_ret = private unnamed_addr constant [9 x i8] c"llvm-ret\00"
@.str.dsl_get_global = private unnamed_addr constant [16 x i8] c"llvm-get-global\00"
@.str.dsl_get_function = private unnamed_addr constant [18 x i8] c"llvm-get-function\00"
@.str.dsl_get_param = private unnamed_addr constant [15 x i8] c"llvm-get-param\00"
@.str.dsl_const_int = private unnamed_addr constant [15 x i8] c"llvm-const-int\00"
@.str.dsl_const_null = private unnamed_addr constant [16 x i8] c"llvm-const-null\00"
@.str.dsl_list = private unnamed_addr constant [5 x i8] c"list\00"

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
    ; Get LLVM context from CodeGen
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    ; Check for null context
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %error, label %check_void
    
check_void:
    ; Check for "void" (with or without vertical bars)
    ; Handle "|void|" (5 chars) or "void" (4 chars)
    %is_void_len = icmp eq i64 %type_len, 4
    %is_void_len_bar = icmp eq i64 %type_len, 5
    %is_void_len_check = or i1 %is_void_len, %is_void_len_bar
    br i1 %is_void_len_check, label %check_void_str, label %check_i8
    
check_void_str:
    ; Compare with "void" (4 chars) or "|void|" (5 chars)
    %void_str = getelementptr [5 x i8], [5 x i8]* @.str.type_void, i32 0, i32 0
    %void_cmp = call i32 @strncmp(i8* %type_str, i8* %void_str, i32 4)
    %is_void = icmp eq i32 %void_cmp, 0
    br i1 %is_void, label %return_void, label %check_void_bar
    
check_void_bar:
    ; Check if it's "|void|" - skip first char and compare "void"
    %type_str_plus1 = getelementptr i8, i8* %type_str, i64 1
    %void_cmp_bar = call i32 @strncmp(i8* %type_str_plus1, i8* %void_str, i32 4)
    %is_void_bar = icmp eq i32 %void_cmp_bar, 0
    br i1 %is_void_bar, label %return_void, label %check_i8
    
return_void:
    %void_type = call %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %void_type
    
check_i8:
    ; Check for "i8" (with or without vertical bars)
    %is_i8_len = icmp eq i64 %type_len, 2
    %is_i8_len_bar = icmp eq i64 %type_len, 4
    %is_i8_len_check = or i1 %is_i8_len, %is_i8_len_bar
    br i1 %is_i8_len_check, label %check_i8_str, label %check_i32
    
check_i8_str:
    %i8_str = getelementptr [3 x i8], [3 x i8]* @.str.type_i8, i32 0, i32 0
    %i8_cmp = call i32 @strncmp(i8* %type_str, i8* %i8_str, i32 2)
    %is_i8 = icmp eq i32 %i8_cmp, 0
    br i1 %is_i8, label %return_i8, label %check_i8_bar
    
check_i8_bar:
    ; Check if it's "|i8|" - skip first char and compare "i8"
    %type_str_plus1_i8 = getelementptr i8, i8* %type_str, i64 1
    %i8_cmp_bar = call i32 @strncmp(i8* %type_str_plus1_i8, i8* %i8_str, i32 2)
    %is_i8_bar = icmp eq i32 %i8_cmp_bar, 0
    br i1 %is_i8_bar, label %return_i8, label %check_i8_ptr
    
check_i8_ptr:
    ; Check for "i8*" or "|i8*|"
    %is_i8_ptr_len = icmp eq i64 %type_len, 3
    %is_i8_ptr_len_bar = icmp eq i64 %type_len, 5
    %is_i8_ptr_len_check = or i1 %is_i8_ptr_len, %is_i8_ptr_len_bar
    br i1 %is_i8_ptr_len_check, label %check_i8_ptr_str, label %check_i32
    
check_i8_ptr_str:
    %i8_ptr_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i8_ptr, i32 0, i32 0
    %i8_ptr_cmp = call i32 @strncmp(i8* %type_str, i8* %i8_ptr_str, i32 3)
    %is_i8_ptr = icmp eq i32 %i8_ptr_cmp, 0
    br i1 %is_i8_ptr, label %return_i8_ptr, label %check_i8_ptr_bar
    
check_i8_ptr_bar:
    ; Check if it's "|i8*|" - skip first char and compare "i8*"
    %type_str_plus1_i8_ptr = getelementptr i8, i8* %type_str, i64 1
    %i8_ptr_cmp_bar = call i32 @strncmp(i8* %type_str_plus1_i8_ptr, i8* %i8_ptr_str, i32 3)
    %is_i8_ptr_bar = icmp eq i32 %i8_ptr_cmp_bar, 0
    br i1 %is_i8_ptr_bar, label %return_i8_ptr, label %check_i32
    
return_i8:
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i8_type
    
return_i8_ptr:
    %i8_type_base = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type_base, i32 0)
    ret %LLVMTypeRef %i8_ptr_type
    
check_i32:
    ; Check for "i32" (with or without vertical bars)
    %is_i32_len = icmp eq i64 %type_len, 3
    %is_i32_len_bar = icmp eq i64 %type_len, 5
    %is_i32_len_check = or i1 %is_i32_len, %is_i32_len_bar
    br i1 %is_i32_len_check, label %check_i32_str, label %check_i64
    
check_i32_str:
    %i32_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i32, i32 0, i32 0
    %i32_cmp = call i32 @strncmp(i8* %type_str, i8* %i32_str, i32 3)
    %is_i32 = icmp eq i32 %i32_cmp, 0
    br i1 %is_i32, label %return_i32, label %check_i32_bar
    
check_i32_bar:
    ; Check if it's "|i32|" - skip first char and compare "i32"
    %type_str_plus1_i32 = getelementptr i8, i8* %type_str, i64 1
    %i32_cmp_bar = call i32 @strncmp(i8* %type_str_plus1_i32, i8* %i32_str, i32 3)
    %is_i32_bar = icmp eq i32 %i32_cmp_bar, 0
    br i1 %is_i32_bar, label %return_i32, label %check_i64
    
return_i32:
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i32_type
    
check_i64:
    ; Check for "i64" (with or without vertical bars)
    %is_i64_len = icmp eq i64 %type_len, 3
    %is_i64_len_bar = icmp eq i64 %type_len, 5
    %is_i64_len_check = or i1 %is_i64_len, %is_i64_len_bar
    br i1 %is_i64_len_check, label %check_i64_str, label %check_array
    
check_i64_str:
    %i64_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i64, i32 0, i32 0
    %i64_cmp = call i32 @strncmp(i8* %type_str, i8* %i64_str, i32 3)
    %is_i64 = icmp eq i32 %i64_cmp, 0
    br i1 %is_i64, label %return_i64, label %check_i64_bar
    
check_i64_bar:
    ; Check if it's "|i64|" - skip first char and compare "i64"
    %type_str_plus1_i64 = getelementptr i8, i8* %type_str, i64 1
    %i64_cmp_bar = call i32 @strncmp(i8* %type_str_plus1_i64, i8* %i64_str, i32 3)
    %is_i64_bar = icmp eq i32 %i64_cmp_bar, 0
    br i1 %is_i64_bar, label %return_i64, label %check_array
    
return_i64:
    %i64_type = call %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i64_type
    
check_array:
    ; Check for array types like "[14 x i8]" or "|[14 x i8]|"
    ; Look for opening bracket '['
    %first_char = load i8, i8* %type_str
    %is_bracket = icmp eq i8 %first_char, 91  ; '[' = 91
    %first_char_bar = icmp eq i8 %first_char, 124  ; '|' = 124
    br i1 %is_bracket, label %parse_array, label %check_array_bar
    
check_array_bar:
    br i1 %first_char_bar, label %check_array_bar_content, label %error
    
check_array_bar_content:
    ; Skip '|' and check for '['
    %type_str_plus1_arr = getelementptr i8, i8* %type_str, i64 1
    %second_char = load i8, i8* %type_str_plus1_arr
    %is_bracket_bar = icmp eq i8 %second_char, 91  ; '['
    br i1 %is_bracket_bar, label %parse_array_bar, label %error
    
parse_array_bar:
    ; Parse array with vertical bars: "|[N x i8]|"
    ; Skip first '|', parse "[N x i8]", skip last '|'
    %array_start = getelementptr i8, i8* %type_str, i64 1
    %array_len_minus2 = sub i64 %type_len, 2  ; Subtract both '|' chars
    br label %parse_array_common
    
parse_array:
    ; Parse array without vertical bars: "[N x i8]"
    %array_start_no_bar = getelementptr i8, i8* %type_str, i64 0
    %array_len_no_bar = add i64 %type_len, 0
    br label %parse_array_common
    
parse_array_common:
    ; Common array parsing logic
    ; For now, we'll implement a simple parser that handles "[N x i8]" format
    ; TODO: Implement full array type parsing
    ; For bootstrap, we'll return i8* pointer type as a placeholder
    ; In a full implementation, we'd parse the number and element type
    %i8_type_arr = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_ptr_type_arr = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type_arr, i32 0)
    ret %LLVMTypeRef %i8_ptr_type_arr
    
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
    ret %LLVMValueRef null
    
check_type:
    %expr_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 0
    %expr_type = load i32, i32* %expr_type_ptr
    
    ; Check if atom (type 0) or list (type 1)
    %is_atom = icmp eq i32 %expr_type, 0  ; AST_ATOM
    br i1 %is_atom, label %handle_atom, label %handle_list
    
handle_atom:
    ; Get atom value and length
    %atom_val_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 2
    %atom_val = load i8*, i8** %atom_val_ptr
    %atom_len_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 3
    %atom_len = load i64, i64* %atom_len_ptr
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    
    ; Check atom type: TOKEN_IDENTIFIER (symbol), TOKEN_STRING, TOKEN_NUMBER
    ; For now, we'll treat identifiers as symbols (primitives or parameters)
    ; Strings and numbers would need special handling
    
    ; Try to resolve as parameter name first
    %param_value = call %LLVMValueRef @codegen_dsl_resolve_param(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %param_not_null = icmp ne %LLVMValueRef %param_value, null
    br i1 %param_not_null, label %return_param, label %try_primitive
    
return_param:
    ret %LLVMValueRef %param_value
    
try_primitive:
    ; Try to resolve as local value name
    %local_value = call %LLVMValueRef @codegen_dsl_resolve_local(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %local_not_null = icmp ne %LLVMValueRef %local_value, null
    br i1 %local_not_null, label %return_local, label %return_null_atom
    
return_local:
    ret %LLVMValueRef %local_value
    
return_null_atom:
    ret %LLVMValueRef null
    
handle_list:
    ; List is a function call: (primitive-name arg1 arg2 ...)
    %list_car_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 4
    %list_car = load %ASTNode*, %ASTNode** %list_car_ptr
    
    ; Get function name (first element)
    %func_name_node_null = icmp eq %ASTNode* %list_car, null
    br i1 %func_name_node_null, label %return_null, label %get_func_name
    
get_func_name:
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
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
    %is_get_function = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.dsl_get_function, i32 0, i32 0), i64 16)
    %is_get_function_bool = icmp ne i32 %is_get_function, 0
    br i1 %is_get_function_bool, label %call_get_function, label %check_get_param
    
call_get_function:
    %get_function_result = call %LLVMValueRef @codegen_dsl_get_function(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_function_result
    
check_get_param:
    %is_get_param = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.dsl_get_param, i32 0, i32 0), i64 13)
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
    %is_const_null = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.dsl_const_null, i32 0, i32 0), i64 14)
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
    br i1 %is_list_bool, label %handle_list_form, label %unknown_primitive
    
handle_list_form:
    ; For "list" form, we just return the args_list as-is
    ; The caller will evaluate each element when needed
    ; Actually, we can't return an AST node as LLVMValueRef
    ; So "list" needs special handling in the caller
    ; For now, return null and handle it in the caller
    ret %LLVMValueRef null
    
unknown_primitive:
    ; Unknown primitive - return null (error case)
    ret %LLVMValueRef null
}

; Helper function to check if identifier matches primitive name
; codegen_dsl_check_primitive: Check if identifier matches a primitive name
; Parameters:
;   id: Identifier string
;   id_len: Identifier length
;   target: Target string to match
;   target_len: Target length
; Returns: 1 if matches, 0 otherwise
define i32 @codegen_dsl_check_primitive(i8* %id, i64 %id_len, i8* %target, i64 %target_len) {
entry:
    %len_match = icmp eq i64 %id_len, %target_len
    br i1 %len_match, label %compare, label %no_match
    
compare:
    %len_int = trunc i64 %id_len to i32
    %cmp_result = call i32 @strncmp(i8* %id, i8* %target, i32 %len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %match, label %no_match
    
match:
    ret i32 1
    
no_match:
    ret i32 0
}

; Resolve parameter name to LLVMValueRef
; codegen_dsl_resolve_param: Look up parameter by name
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Parameter name
;   name_len: Name length
; Returns: LLVMValueRef for parameter, or null if not found
define %LLVMValueRef @codegen_dsl_resolve_param(%CodeGen* %cg, i8* %name, i64 %name_len) {
entry:
    ; Get param_names list from CodeGen
    %param_names_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 9
    %param_names = load %ASTNode*, %ASTNode** %param_names_ptr
    
    %param_names_null = icmp eq %ASTNode* %param_names, null
    br i1 %param_names_null, label %not_found, label %search_params
    
search_params:
    ; param_names is a list of (name index) pairs
    ; For now, we'll use a simple linear search
    ; TODO: Optimize with hash table if needed
    
    ; Get current function
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    %current_function = load %LLVMValueRef, %LLVMValueRef* %current_function_ptr
    
    %func_null = icmp eq %LLVMValueRef %current_function, null
    br i1 %func_null, label %not_found, label %iterate_params
    
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
    ; pair is a list: (name index)
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %stored_name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %stored_name_len = load i64, i64* %name_len_ptr
    
    ; Compare names
    %len_match = icmp eq i64 %name_len, %stored_name_len
    br i1 %len_match, label %compare_names, label %next_pair
    
compare_names:
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %name, i8* %stored_name, i32 %name_len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %found, label %next_pair
    
found:
    ; Get index from pair
    ; pair structure: (name . (index . nil))
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 5
    %pair_cdr = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    
    ; Check if cdr is null (shouldn't be, but safety check)
    %pair_cdr_null = icmp eq %ASTNode* %pair_cdr, null
    br i1 %pair_cdr_null, label %not_found, label %get_index_node
    
get_index_node:
    ; Verify pair_cdr is a LIST node (safety check)
    %pair_cdr_type_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr, i32 0, i32 0
    %pair_cdr_type = load i32, i32* %pair_cdr_type_ptr
    %is_list = icmp eq i32 %pair_cdr_type, 1  ; AST_LIST
    br i1 %is_list, label %get_index_car, label %not_found
    
get_index_car:
    ; Get car of cdr (the index node)
    %index_node_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr, i32 0, i32 4
    %index_node = load %ASTNode*, %ASTNode** %index_node_ptr
    
    ; Check if index node is null
    %index_node_null = icmp eq %ASTNode* %index_node, null
    br i1 %index_node_null, label %not_found, label %parse_index
    
parse_index:
    ; Parse index from AST node (should be a number)
    %index_val = call i32 @codegen_parse_int_from_ast(%ASTNode* %index_node)
    
    ; Get parameter by index
    %param = call %LLVMValueRef @llvm_get_param(%LLVMValueRef %current_function, i32 %index_val)
    ret %LLVMValueRef %param
    
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
    ; Get local_values list from CodeGen
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    %local_values = load %ASTNode*, %ASTNode** %local_values_ptr
    
    %local_values_null = icmp eq %ASTNode* %local_values, null
    br i1 %local_values_null, label %not_found, label %search_locals
    
search_locals:
    %current_pair = alloca %ASTNode*
    store %ASTNode* %local_values, %ASTNode** %current_pair
    br label %search_loop
    
search_loop:
    %pair_val = load %ASTNode*, %ASTNode** %current_pair
    %pair_null = icmp eq %ASTNode* %pair_val, null
    br i1 %pair_null, label %not_found, label %check_pair
    
check_pair:
    ; pair is a list: (name value-ref-as-pointer)
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %stored_name = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 3
    %stored_name_len = load i64, i64* %name_len_ptr
    
    ; Compare names
    %len_match = icmp eq i64 %name_len, %stored_name_len
    br i1 %len_match, label %compare_names_local, label %next_pair_local
    
compare_names_local:
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %name, i8* %stored_name, i32 %name_len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %found_local, label %next_pair_local
    
found_local:
    ; Get value from pair (stored as pointer in AST node's value field)
    ; For now, we'll store the value differently - need to think about this
    ; Actually, we can't store LLVMValueRef directly in AST
    ; We need a different approach - maybe a hash table or separate structure
    ; For bootstrap, let's use a simpler approach: store in a separate array
    ; But that's complex. For now, return null and we'll handle it differently
    ret %LLVMValueRef null
    
next_pair_local:
    %pair_cdr_next = getelementptr %ASTNode, %ASTNode* %pair_val, i32 0, i32 5
    %next_pair_val = load %ASTNode*, %ASTNode** %pair_cdr_next
    store %ASTNode* %next_pair_val, %ASTNode** %current_pair
    br label %search_loop
    
not_found:
    ret %LLVMValueRef null
}

; Bind local value to name
; codegen_dsl_bind_local: Bind a local value to a name
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Name string
;   name_len: Name length
;   value: LLVMValueRef to bind
; Note: For bootstrap, we'll store this in a simple list structure
; In a full implementation, we'd use a hash table
define void @codegen_dsl_bind_local(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef %value) {
entry:
    ; For now, this is a placeholder
    ; Storing LLVMValueRef in AST is complex
    ; We'll need a different data structure
    ; For bootstrap, we can skip this and handle it differently
    ret void
}

; Parse integer from AST node
; codegen_parse_int_from_ast: Parse integer value from AST node
; Parameters:
;   node: AST node (should be a number atom)
; Returns: Integer value, or 0 on error
define i32 @codegen_parse_int_from_ast(%ASTNode* %node) {
entry:
    %node_null = icmp eq %ASTNode* %node, null
    br i1 %node_null, label %error, label %check_type
    
check_type:
    %node_type_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 0
    %node_type = load i32, i32* %node_type_ptr
    %is_atom = icmp eq i32 %node_type, 0  ; AST_ATOM
    br i1 %is_atom, label %check_number, label %error
    
check_number:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    %is_number = icmp eq i32 %atom_type, 2  ; TOKEN_NUMBER
    br i1 %is_number, label %parse_number, label %error
    
parse_number:
    %value_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 2
    %value_str = load i8*, i8** %value_ptr
    %value_len_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 3
    %value_len = load i64, i64* %value_len_ptr
    
    ; Parse string to integer
    %result = call i32 @codegen_parse_int_string(i8* %value_str, i64 %value_len)
    ret i32 %result
    
error:
    ret i32 0
}

; Parse integer from string
; codegen_parse_int_string: Parse integer from string representation
; Parameters:
;   str: String pointer
;   len: String length
; Returns: Integer value
define i32 @codegen_parse_int_string(i8* %str, i64 %len) {
entry:
    %result = alloca i32
    store i32 0, i32* %result
    %i = alloca i64
    store i64 0, i64* %i
    br label %loop
    
loop:
    %i_val = load i64, i64* %i
    %done = icmp uge i64 %i_val, %len
    br i1 %done, label %return, label %process_char
    
process_char:
    %char_ptr = getelementptr i8, i8* %str, i64 %i_val
    %char = load i8, i8* %char_ptr
    %char_int = zext i8 %char to i32
    
    ; Check if digit
    %is_digit = icmp uge i32 %char_int, 48  ; '0'
    %is_digit2 = icmp ule i32 %char_int, 57  ; '9'
    %is_digit_both = and i1 %is_digit, %is_digit2
    br i1 %is_digit_both, label %accumulate, label %return
    
accumulate:
    %result_val = load i32, i32* %result
    %result_new = mul i32 %result_val, 10
    %digit_val = sub i32 %char_int, 48
    %result_final = add i32 %result_new, %digit_val
    store i32 %result_final, i32* %result
    
    %i_new = add i64 %i_val, 1
    store i64 %i_new, i64* %i
    br label %loop
    
return:
    %result_ret = load i32, i32* %result
    ret i32 %result_ret
}

; ============================================================================
; DSL Primitive Implementations
; ============================================================================

; llvm-gep: Build getelementptr instruction
; Signature: (llvm-gep type pointer indices name)
; Args: type (ASTNode with type string), pointer (ASTNode), indices (ASTNode list), name (ASTNode string, optional)
define %LLVMValueRef @codegen_dsl_gep(%CodeGen* %cg, %ASTNode* %args) {
entry:
    ; Get builder
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_args
    
get_args:
    ; Extract arguments: type, pointer, indices, name
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_type
    
get_type:
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type
    %gep_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    %gep_type_null = icmp eq %LLVMTypeRef %gep_type, null
    br i1 %gep_type_null, label %error, label %get_pointer
    
get_pointer:
    ; Get pointer argument (second element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %pointer_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %pointer_node = load %ASTNode*, %ASTNode** %pointer_node_ptr
    
    ; Evaluate pointer expression
    %pointer = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %pointer_node)
    %pointer_null = icmp eq %LLVMValueRef %pointer, null
    br i1 %pointer_null, label %error, label %get_indices
    
get_indices:
    ; Get indices list (third element)
    %args_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 5
    %indices_list_node = load %ASTNode*, %ASTNode** %args_cdr_cdr_ptr
    %indices_list_ptr = getelementptr %ASTNode, %ASTNode* %indices_list_node, i32 0, i32 4
    %indices_list_raw = load %ASTNode*, %ASTNode** %indices_list_ptr
    
    ; Check if indices_list is a "list" form - if so, get its arguments
    %indices_is_list = icmp ne %ASTNode* %indices_list_raw, null
    br i1 %indices_is_list, label %check_list_form, label %eval_indices
    
check_list_form:
    ; Check if first element is "list"
    %indices_car_ptr = getelementptr %ASTNode, %ASTNode* %indices_list_raw, i32 0, i32 4
    %indices_car = load %ASTNode*, %ASTNode** %indices_car_ptr
    %indices_car_type_ptr = getelementptr %ASTNode, %ASTNode* %indices_car, i32 0, i32 0
    %indices_car_type = load i32, i32* %indices_car_type_ptr
    %is_atom_check = icmp eq i32 %indices_car_type, 0
    br i1 %is_atom_check, label %check_list_name, label %eval_indices
    
check_list_name:
    %list_name_ptr = getelementptr %ASTNode, %ASTNode* %indices_car, i32 0, i32 2
    %list_name = load i8*, i8** %list_name_ptr
    %list_name_len_ptr = getelementptr %ASTNode, %ASTNode* %indices_car, i32 0, i32 3
    %list_name_len = load i64, i64* %list_name_len_ptr
    %is_list_form = call i32 @codegen_dsl_check_primitive(i8* %list_name, i64 %list_name_len, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.dsl_list, i32 0, i32 0), i64 4)
    %is_list_form_bool = icmp ne i32 %is_list_form, 0
    br i1 %is_list_form_bool, label %get_list_args, label %eval_indices
    
get_list_args:
    ; Get arguments of list form
    %indices_cdr_ptr = getelementptr %ASTNode, %ASTNode* %indices_list_raw, i32 0, i32 5
    %list_args = load %ASTNode*, %ASTNode** %indices_cdr_ptr
    br label %eval_indices
    
eval_indices:
    ; Evaluate indices list to array of LLVMValueRef
    ; Use the list (either direct or from list form)
    %indices_to_eval = phi %ASTNode* [ %indices_list_raw, %get_indices ], [ %indices_list_raw, %check_list_form ], [ %indices_list_raw, %check_list_name ], [ %list_args, %get_list_args ]
    
    ; Allocate array (max 10 indices)
    %indices_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %indices_array_ptr = bitcast i8* %indices_array to %LLVMValueRef*
    
    ; Count and evaluate indices
    %index_count = call i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %indices_to_eval, %LLVMValueRef* %indices_array_ptr, i32 10)
    
    ; Get name (fourth element, optional)
    %args_cdr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 5
    %args_cdr_cdr_cdr = load %ASTNode*, %ASTNode** %args_cdr_cdr_cdr_ptr
    %name_list_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr_cdr_cdr, i32 0, i32 4
    %name_list = load %ASTNode*, %ASTNode** %name_list_node_ptr
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %has_name = icmp ne %ASTNode* %name_list, null
    br i1 %has_name, label %get_name, label %build_gep
    
get_name:
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %name_list, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name_str_val = load i8*, i8** %name_val_ptr
    br label %build_gep
    
build_gep:
    %name_phi = phi i8* [ %name_str, %eval_indices ], [ %name_str_val, %get_name ]
    
    ; Validate GEP type before using it
    %gep_type_valid = icmp eq %LLVMTypeRef %gep_type, null
    br i1 %gep_type_valid, label %error, label %build_gep_inst
    
build_gep_inst:
    %index_count_int = zext i32 %index_count to i64
    %gep_result = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %gep_type, %LLVMValueRef %pointer, %LLVMValueRef* %indices_array_ptr, i32 %index_count, i8* %name_phi)
    
    ; If name is provided and not empty, bind the result to that name
    %name_is_not_empty_str = icmp ne i8* %name_phi, %name_str
    %name_is_not_null = icmp ne i8* %name_phi, null
    %should_bind = and i1 %name_is_not_empty_str, %name_is_not_null
    br i1 %should_bind, label %bind_value, label %free_array
    
bind_value:
    ; Bind GEP result to name (if name is not empty string)
    ; Get name length by checking if it's the empty string
    %name_first_char = load i8, i8* %name_phi
    %name_is_empty = icmp eq i8 %name_first_char, 0
    br i1 %name_is_empty, label %free_array, label %do_bind
    
do_bind:
    ; Calculate name length (simplified - would need proper strlen)
    %name_len_approx = add i64 10, 0  ; Approximate - in real impl would call strlen
    call void @codegen_dsl_bind_local(%CodeGen* %cg, i8* %name_phi, i64 %name_len_approx, %LLVMValueRef %gep_result)
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
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %get_func_type
    
get_func_type:
    ; Get function type from function value
    %func_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    
    ; Get args list (third element)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_cdr = load %ASTNode*, %ASTNode** %args_cdr_ptr
    %args_list_node_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 4
    %args_list_raw = load %ASTNode*, %ASTNode** %args_list_node_ptr
    
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
    %is_list_form_args = call i32 @codegen_dsl_check_primitive(i8* %list_name_args, i64 %list_name_len_args, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.dsl_list, i32 0, i32 0), i64 4)
    %is_list_form_args_bool = icmp ne i32 %is_list_form_args, 0
    br i1 %is_list_form_args_bool, label %get_list_args_call, label %eval_args
    
get_list_args_call:
    %args_cdr_list_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 5
    %list_args_call = load %ASTNode*, %ASTNode** %args_cdr_list_ptr
    br label %eval_args
    
eval_args:
    %args_to_eval = phi %ASTNode* [ %args_list_raw, %get_func_type ], [ %args_list_raw, %check_args_list_form ], [ %args_list_raw, %check_list_name_args ], [ %list_args_call, %get_list_args_call ]
    
    ; Evaluate args list
    %args_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %args_array_ptr = bitcast i8* %args_array to %LLVMValueRef*
    %arg_count = call i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %args_to_eval, %LLVMValueRef* %args_array_ptr, i32 10)
    
    ; Get name (fourth element, optional)
    %args_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args_cdr, i32 0, i32 5
    %name_list = load %ASTNode*, %ASTNode** %args_cdr_cdr_ptr
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %has_name = icmp ne %ASTNode* %name_list, null
    br i1 %has_name, label %get_name_call, label %build_call
    
get_name_call:
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %name_list, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name_str_val = load i8*, i8** %name_val_ptr
    br label %build_call
    
build_call:
    %name_phi_call = phi i8* [ %name_str, %eval_args ], [ %name_str_val, %get_name_call ]
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
    
    %global = call %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef %module, i8* %name)
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
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name = load i8*, i8** %name_val_ptr
    
    %func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %name)
    ret %LLVMValueRef %func
    
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
    
    ; Store in array
    %i_val_for_idx = load i32, i32* %i
    %array_idx = getelementptr %LLVMValueRef, %LLVMValueRef* %array, i32 %i_val_for_idx
    store %LLVMValueRef %value, %LLVMValueRef* %array_idx
    
    ; Move to next
    %i_new = add i32 %i_val, 1
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
    ; Add function to module
    ; Create null-terminated function name
    %func_name_buf = call i8* @malloc(i64 %func_name_len)
    %func_name_buf_plus1 = add i64 %func_name_len, 1
    %func_name_buf_full = call i8* @malloc(i64 %func_name_buf_plus1)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_name_buf_full, i8* %func_name, i64 %func_name_len, i1 false)
    %null_ptr = getelementptr i8, i8* %func_name_buf_full, i64 %func_name_len
    store i8 0, i8* %null_ptr
    
    %func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %func_name_buf_full, %LLVMTypeRef %func_type_phi)
    call void @free(i8* %func_name_buf_full)
    
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %free_param_types, label %set_param_names
    
set_param_names:
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
    
    ; Store function type for later retrieval during function calls
    ; NOTE: Temporarily disabled to debug crash - storing type pointer may be causing issues
    ; call void @codegen_store_function_type(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMTypeRef %func_type_phi)
    
    ; Evaluate DSL body
    call void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %dsl_body)
    
    ; Clean up builder
    call void @llvm_dispose_builder(%LLVMBuilderRef %builder)
    
    ; Clear DSL evaluation fields
    store %LLVMValueRef null, %LLVMValueRef* %current_function_ptr
    store %LLVMBuilderRef null, %LLVMBuilderRef* %builder_ptr
    store %ASTNode* null, %ASTNode** %param_names_ptr
    
    ; Free param types array
    call void @free(i8* %param_types_array)
    
    ret i32 0
    
error:
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
    %params_null = icmp eq %ASTNode* %params, null
    br i1 %params_null, label %return_zero, label %collect_loop
    
return_zero:
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
    ; Get param pair: (param-name type)
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 4
    %param_pair = load %ASTNode*, %ASTNode** %car_ptr
    
    ; Get type (second element of pair)
    %pair_cdr_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 5
    %pair_cdr = load %ASTNode*, %ASTNode** %pair_cdr_ptr
    %type_node_ptr = getelementptr %ASTNode, %ASTNode* %pair_cdr, i32 0, i32 4
    %type_node = load %ASTNode*, %ASTNode** %type_node_ptr
    %type_val_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 2
    %type_str = load i8*, i8** %type_val_ptr
    %type_len_ptr = getelementptr %ASTNode, %ASTNode* %type_node, i32 0, i32 3
    %type_len = load i64, i64* %type_len_ptr
    
    ; Resolve type
    %param_type = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len)
    
    ; Validate parameter type before storing
    %param_type_null = icmp eq %LLVMTypeRef %param_type, null
    br i1 %param_type_null, label %return_count, label %store_param_type
    
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
    
    ; Get param name (first element of pair)
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 4
    %param_name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    
    ; Get current index
    %index_val = load i32, i32* %index
    
    ; Create index node (number atom)
    %index_node = call %ASTNode* @codegen_create_int_node(i32 %index_val)
    
    ; Create (name index) pair
    %name_index_pair = call %ASTNode* @codegen_create_pair(%ASTNode* %param_name_node, %ASTNode* %index_node)
    
    ; Prepend to result list
    %result_val = load %ASTNode*, %ASTNode** %result
    %new_cons = call %ASTNode* @codegen_create_cons(%ASTNode* %name_index_pair, %ASTNode* %result_val)
    store %ASTNode* %new_cons, %ASTNode** %result
    
    ; Increment index and move to next
    %index_new = add i32 %index_val, 1
    store i32 %index_new, i32* %index
    
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

; Create pair (cons cell)
; codegen_create_pair: Create a cons cell with two elements
; Parameters:
;   car: First element
;   cdr: Second element (will be wrapped in list)
; Returns: ASTNode* list
define %ASTNode* @codegen_create_pair(%ASTNode* %car, %ASTNode* %cdr) {
entry:
    ; Create cons cell
    %cons = call i8* @malloc(i64 48)
    %cons_ptr = bitcast i8* %cons to %ASTNode*
    
    ; Initialize all fields to safe defaults
    ; Field 0: type = AST_LIST
    %type_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 0
    store i32 1, i32* %type_ptr  ; AST_LIST
    ; Field 1: atom_type = 0 (not used for lists)
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 1
    store i32 0, i32* %atom_type_ptr
    ; Field 2: value = null (not used for lists)
    %value_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 2
    store i8* null, i8** %value_ptr
    ; Field 3: value_len = 0 (not used for lists)
    %value_len_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 3
    store i64 0, i64* %value_len_ptr
    ; Field 4: car
    %car_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 4
    store %ASTNode* %car, %ASTNode** %car_ptr
    ; Field 5: cdr (will be set below)
    ; Field 6: line = 0
    %line_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 6
    store i32 0, i32* %line_ptr
    ; Field 7: column = 0
    %column_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 7
    store i32 0, i32* %column_ptr
    
    ; Create cdr list with single element
    %cdr_cons = call i8* @malloc(i64 48)
    %cdr_cons_ptr = bitcast i8* %cdr_cons to %ASTNode*
    ; Initialize all fields of cdr_cons
    %cdr_type_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 0
    store i32 1, i32* %cdr_type_ptr  ; AST_LIST
    %cdr_atom_type_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 1
    store i32 0, i32* %cdr_atom_type_ptr
    %cdr_value_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 2
    store i8* null, i8** %cdr_value_ptr
    %cdr_value_len_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 3
    store i64 0, i64* %cdr_value_len_ptr
    %cdr_car_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 4
    store %ASTNode* %cdr, %ASTNode** %cdr_car_ptr
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %cdr_cdr_ptr
    %cdr_line_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 6
    store i32 0, i32* %cdr_line_ptr
    %cdr_column_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cons_ptr, i32 0, i32 7
    store i32 0, i32* %cdr_column_ptr
    
    ; Set cdr of main cons cell
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 5
    store %ASTNode* %cdr_cons_ptr, %ASTNode** %cdr_ptr
    
    ret %ASTNode* %cons_ptr
}

; Create cons cell
; codegen_create_cons: Create a cons cell
; Parameters:
;   car: First element
;   cdr: Rest of list
; Returns: ASTNode* list
define %ASTNode* @codegen_create_cons(%ASTNode* %car, %ASTNode* %cdr) {
entry:
    %cons = call i8* @malloc(i64 48)
    %cons_ptr = bitcast i8* %cons to %ASTNode*
    
    %type_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 0
    store i32 1, i32* %type_ptr  ; AST_LIST
    
    %car_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 4
    store %ASTNode* %car, %ASTNode** %car_ptr
    
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %cons_ptr, i32 0, i32 5
    store %ASTNode* %cdr, %ASTNode** %cdr_ptr
    
    ret %ASTNode* %cons_ptr
}

; Create string AST node
; codegen_create_string_node: Create an AST node for a string
; Parameters:
;   str: String value (not null-terminated)
;   len: String length
; Returns: ASTNode* for string atom
define %ASTNode* @codegen_create_string_node(i8* %str, i64 %len) {
entry:
    ; Allocate string copy
    %str_buf = call i8* @malloc(i64 %len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %str_buf, i8* %str, i64 %len, i1 false)
    
    ; Create AST node
    %node = call i8* @malloc(i64 48)
    %node_ptr = bitcast i8* %node to %ASTNode*
    
    ; Initialize fields
    %type_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 0
    store i32 0, i32* %type_ptr  ; AST_ATOM
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 1
    store i32 3, i32* %atom_type_ptr  ; TOKEN_STRING
    %value_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 2
    store i8* %str_buf, i8** %value_ptr
    %len_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 3
    store i64 %len, i64* %len_ptr
    %car_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 4
    store %ASTNode* null, %ASTNode** %car_ptr
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %cdr_ptr
    %line_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 6
    store i32 0, i32* %line_ptr
    %column_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 7
    store i32 0, i32* %column_ptr
    
    ret %ASTNode* %node_ptr
}

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

; Evaluate DSL body (list of expressions)
; codegen_eval_dsl_body: Evaluate list of DSL expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   body: AST node list of DSL expressions
define void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %body) {
entry:
    %body_null = icmp eq %ASTNode* %body, null
    br i1 %body_null, label %done, label %check_body_type
    
check_body_type:
    ; Verify body is a list (AST_LIST = 1)
    %body_type_ptr = getelementptr %ASTNode, %ASTNode* %body, i32 0, i32 0
    %body_type = load i32, i32* %body_type_ptr
    %is_list = icmp eq i32 %body_type, 1  ; AST_LIST
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
    
    ; Evaluate expression (result is discarded for statements)
    ; Note: This should generate instructions including terminators like ret
    %expr_result = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %car)
    
    ; Move to next
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current
    br label %eval_iter
    
done:
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
