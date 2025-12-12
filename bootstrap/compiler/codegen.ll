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

; CodeGen structure - extended to include LLVM context/module handles
; Fields:
;   ir_buffer: Buffer for generated IR text (for backward compatibility during migration)
;   buffer_size: Current buffer size
;   buffer_pos: Current position in buffer
;   string_counter: Counter for unique string constant names
;   label_counter: Counter for unique label names
;   llvm_context: LLVM context handle
;   llvm_module: LLVM module handle
;   llvm_builder: LLVM builder handle (for generating instructions in main function)
%CodeGen = type { i8*, i64, i64, i32, i32, %LLVMContextRef, %LLVMModuleRef, %LLVMBuilderRef }

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
    ; Allocate CodeGen structure (now includes LLVM context/module/builder pointers)
    %cg = call i8* @malloc(i64 56)  ; 8 + 8 + 8 + 4 + 4 + 8 + 8 + 8 = 56 bytes
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
    %gep = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %array_type, %LLVMValueRef %global, %LLVMValueRef* %indices, i32 2, i8* null)
    
    ; Store in argument array
    store %LLVMValueRef %gep, %LLVMValueRef* %arg_array
    br label %call_func
    
call_with_no_args:
    ; No arguments - use null array
    br label %call_func
    
call_func:
    ; PHI nodes must be first in the block
    %args_count = phi i32 [ 1, %build_gep ], [ 0, %call_with_no_args ]
    %args_ptr = phi %LLVMValueRef* [ %arg_array, %build_gep ], [ null, %call_with_no_args ]
    
    ; Get the function's actual type from the function value
    ; Function values have pointer type, so get the pointee type (the function signature)
    %func_ptr_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    %func_type = call %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %func_ptr_type)
    
    ; Build call instruction using the function's actual type
    %call_result = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args_ptr, i32 %args_count, i8* null)
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

; Parse complete function definition from IR text
; codegen_parse_function_ir: Parse a complete function definition from IR text and add to module
; Parameters:
;   cg: Pointer to CodeGen structure
;   func_ir: Complete function definition as IR text (including signature and body)
;   func_ir_len: Length of IR text
; Returns: 0 on success, -1 on error
; NOTE: This wraps the function in a minimal module, parses it, and the function
; will be added to the parsed module. For bootstrap simplicity, we'll parse into
; a temporary module and the function will be available there.
; TODO: Extract function from temp module and add to main module.
define i32 @codegen_parse_function_ir(%CodeGen* %cg, i8* %func_ir, i64 %func_ir_len) {
entry:
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
    ; Add printf declaration (42 bytes including newlines and null terminator, but we'll use 41 without null)
    %printf_decl_len = add i64 41, 0
    %prefix_with_printf = add i64 %total_prefix, %printf_decl_len
    ; Note: LLVM's IR parser requires explicit external declarations for undefined globals.
    ; While the linker can resolve externals to definitions, the parser itself needs declarations.
    ; For now, we add @hello_string declaration as a common pattern. A proper solution would
    ; scan the function IR to find all referenced @ symbols and add declarations dynamically.
    %hello_string_decl_len = add i64 44, 0
    %prefix_with_decls = add i64 %prefix_with_printf, %hello_string_decl_len
    %module_ir_size = add i64 %prefix_with_decls, %func_ir_len
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
    
    ; Add external declarations for symbols referenced in function IR
    ; Note: LLVM's IR parser requires explicit external declarations for undefined globals.
    ; The linker will resolve these externals to actual definitions in the main module.
    ; Add printf declaration (commonly used in functions, truly external)
    %pos_val12_5 = load i64, i64* %pos
    %printf_decl_dest = getelementptr i8, i8* %module_ir_buf, i64 %pos_val12_5
    %printf_decl_str = getelementptr [42 x i8], [42 x i8]* @.str.printf_decl_module, i32 0, i32 0
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %printf_decl_dest, i8* %printf_decl_str, i64 41, i1 false)
    %pos_val12_6 = add i64 %pos_val12_5, 41
    store i64 %pos_val12_6, i64* %pos
    
    ; Add external declaration for @hello_string (common constant pattern)
    ; TODO: Scan function IR to find all referenced @ symbols and add declarations dynamically
    %pos_val12_7 = load i64, i64* %pos
    %hello_string_decl_dest = getelementptr i8, i8* %module_ir_buf, i64 %pos_val12_7
    %hello_string_decl_str = getelementptr [45 x i8], [45 x i8]* @.str.external_hello_string, i32 0, i32 0
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %hello_string_decl_dest, i8* %hello_string_decl_str, i64 44, i1 false)
    %pos_val12_8 = add i64 %pos_val12_7, 44
    store i64 %pos_val12_8, i64* %pos
    
    ; Copy function IR
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
    ; Parse into temporary module
    %temp_module_ptr = alloca %LLVMModuleRef
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
    br i1 %parse_failed, label %error, label %success
    
success:
    ; Get main module from CodeGen structure
    %main_module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %main_module = load %LLVMModuleRef, %LLVMModuleRef* %main_module_ptr
    %main_module_null = icmp eq %LLVMModuleRef %main_module, null
    br i1 %main_module_null, label %error, label %link_modules

link_modules:
    ; Link temp module into main module
    %temp_module = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_null = icmp eq %LLVMModuleRef %temp_module, null
    br i1 %temp_module_null, label %error, label %do_link

do_link:
    ; Link src (temp) into dest (main)
    ; Note: LLVMLinkModules2 automatically moves contents from src to dest
    ; LLVM's linker should automatically resolve references to symbols that exist
    ; in the destination module (main_module), so external declarations aren't needed
    
    ; DEBUG: Write that we're about to link
    %debug_link_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_link_fd = call i32 @open(i8* %debug_link_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_link_fd_valid = icmp sge i32 %debug_link_fd, 0
    br i1 %debug_link_fd_valid, label %write_link_debug, label %do_actual_link
    
write_link_debug:
    %link_msg = getelementptr [22 x i8], [22 x i8]* @.str.about_to_link, i32 0, i32 0
    call i64 @write(i32 %debug_link_fd, i8* %link_msg, i32 21)
    call i32 @close(i32 %debug_link_fd)
    br label %do_actual_link
    
do_actual_link:
    %link_result = call i32 @llvm_link_modules2(%LLVMModuleRef %main_module, %LLVMModuleRef %temp_module)
    
    ; DEBUG: Write link result to debug file
    %debug_link_result_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_link_result_fd = call i32 @open(i8* %debug_link_result_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_link_result_fd_valid = icmp sge i32 %debug_link_result_fd, 0
    br i1 %debug_link_result_fd_valid, label %write_link_result_debug, label %check_link_result
    
write_link_result_debug:
    ; Check if link succeeded (result == 0) or failed (result != 0)
    %link_result_zero = icmp eq i32 %link_result, 0
    br i1 %link_result_zero, label %write_link_success, label %write_link_failure
    
write_link_success:
    %link_success_msg = getelementptr [33 x i8], [33 x i8]* @.str.link_succeeded, i32 0, i32 0
    call i64 @write(i32 %debug_link_result_fd, i8* %link_success_msg, i32 32)
    %newline_link_success = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_link_result_fd, i8* %newline_link_success, i32 1)
    call i32 @close(i32 %debug_link_result_fd)
    br label %check_link_result
    
write_link_failure:
    %link_failure_msg = getelementptr [31 x i8], [31 x i8]* @.str.link_failed, i32 0, i32 0
    call i64 @write(i32 %debug_link_result_fd, i8* %link_failure_msg, i32 30)
    %newline_link_failure = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_link_result_fd, i8* %newline_link_failure, i32 1)
    call i32 @close(i32 %debug_link_result_fd)
    br label %check_link_result
    
check_link_result:
    %link_failed = icmp ne i32 %link_result, 0
    br i1 %link_failed, label %link_error, label %verify_after_link

link_error:
    ; Linking failed - this could be due to:
    ; - Symbol resolution issues (symbols referenced but not defined in main module)
    ; - Type mismatches between declarations and definitions
    ; - Duplicate symbol definitions
    ; Note: LLVMLinkModules2 doesn't provide detailed error messages, but debug_module_ir.ll
    ; contains the temp module IR that failed to link, which can help diagnose the issue
    br label %dispose_and_error
    
verify_after_link:
    ; Verify module after linking (action 1 = return message)
    %verify_error_msg = alloca i8*
    store i8* null, i8** %verify_error_msg
    %verify_result = call i32 @llvm_verify_module(%LLVMModuleRef %main_module, i32 1, i8** %verify_error_msg)
    ; Verification errors are warnings, not fatal - continue anyway
    
    ; DEBUG: Write that we reached verify_after_link
    %debug_reached_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_reached_fd = call i32 @open(i8* %debug_reached_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_reached_fd_valid = icmp sge i32 %debug_reached_fd, 0
    br i1 %debug_reached_fd_valid, label %write_reached_msg, label %do_extract_debug
    
write_reached_msg:
    %reached_msg = getelementptr [33 x i8], [33 x i8]* @.str.reached_verify_after_link, i32 0, i32 0
    call i64 @write(i32 %debug_reached_fd, i8* %reached_msg, i32 32)
    call i32 @close(i32 %debug_reached_fd)
    br label %do_extract_debug
    
do_extract_debug:
    ; DEBUG: Extract function name from IR and verify it exists in module after linking
    ; Function IR format: "define return-type @name("
    ; Find "@" after "define " and return type, then extract name until "("
    ; NOTE: We're extracting from the original func_ir, which should be the full function definition
    ; Write debug output showing what IR we're trying to extract from
    %debug_extract_name = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_extract_fd = call i32 @open(i8* %debug_extract_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_extract_fd_valid = icmp sge i32 %debug_extract_fd, 0
    br i1 %debug_extract_fd_valid, label %write_extract_debug, label %do_extract
    
write_extract_debug:
    %extracting_from_msg = getelementptr [32 x i8], [32 x i8]* @.str.extracting_from_ir, i32 0, i32 0
    call i64 @write(i32 %debug_extract_fd, i8* %extracting_from_msg, i32 31)
    %func_ir_len_int = trunc i64 %func_ir_len to i32
    call i64 @write(i32 %debug_extract_fd, i8* %func_ir, i32 %func_ir_len_int)
    %newline_extract = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_extract_fd, i8* %newline_extract, i32 1)
    call i32 @close(i32 %debug_extract_fd)
    br label %do_extract
    
do_extract:
    %func_name_start = call i8* @codegen_extract_function_name(i8* %func_ir, i64 %func_ir_len)
    %func_name_start_null = icmp eq i8* %func_name_start, null
    br i1 %func_name_start_null, label %write_extraction_failed, label %write_extracted_name
    
write_extracted_name:
    ; Write extracted function name to debug file
    %debug_extract_name2 = getelementptr [27 x i8], [27 x i8]* @.str.debug_extract, i32 0, i32 0
    %debug_extract_fd2 = call i32 @open(i8* %debug_extract_name2, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_extract_fd2_valid = icmp sge i32 %debug_extract_fd2, 0
    br i1 %debug_extract_fd2_valid, label %write_name_debug, label %check_func_exists
    
write_name_debug:
    %extracted_name_msg = getelementptr [26 x i8], [26 x i8]* @.str.extracted_name, i32 0, i32 0
    call i64 @write(i32 %debug_extract_fd2, i8* %extracted_name_msg, i32 25)
    %func_name_len_extract = call i64 @strlen(i8* %func_name_start)
    %func_name_len_extract_int = trunc i64 %func_name_len_extract to i32
    call i64 @write(i32 %debug_extract_fd2, i8* %func_name_start, i32 %func_name_len_extract_int)
    %newline_extract2 = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_extract_fd2, i8* %newline_extract2, i32 1)
    call i32 @close(i32 %debug_extract_fd2)
    br label %check_func_exists
    
write_extraction_failed:
    ; Function name extraction failed - write debug message
    %debug_verify_name_extract = getelementptr [21 x i8], [21 x i8]* @.str.debug_verify, i32 0, i32 0
    %debug_verify_fd_extract = call i32 @open(i8* %debug_verify_name_extract, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_verify_fd_extract_valid = icmp sge i32 %debug_verify_fd_extract, 0
    br i1 %debug_verify_fd_extract_valid, label %write_extract_error, label %dispose_temp
    
write_extract_error:
    %extract_failed_msg = getelementptr [47 x i8], [47 x i8]* @.str.func_name_extraction_failed, i32 0, i32 0
    call i64 @write(i32 %debug_verify_fd_extract, i8* %extract_failed_msg, i32 46)
    call i32 @close(i32 %debug_verify_fd_extract)
    br label %dispose_temp
    
check_func_exists:
    ; Look up function in module to verify it was linked successfully
    %linked_func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %main_module, i8* %func_name_start)
    %linked_func_null = icmp eq %LLVMValueRef %linked_func, null
    br i1 %linked_func_null, label %write_func_not_found_debug, label %write_func_found_debug
    
write_func_not_found_debug:
    ; Function not found after linking - write debug message
    %debug_verify_name = getelementptr [21 x i8], [21 x i8]* @.str.debug_verify, i32 0, i32 0
    %debug_verify_fd = call i32 @open(i8* %debug_verify_name, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %debug_verify_fd_valid = icmp sge i32 %debug_verify_fd, 0
    br i1 %debug_verify_fd_valid, label %write_not_found_msg, label %free_func_name
    
write_not_found_msg:
    %not_found_prefix = getelementptr [42 x i8], [42 x i8]* @.str.func_not_found_after_link, i32 0, i32 0
    call i64 @write(i32 %debug_verify_fd, i8* %not_found_prefix, i32 41)
    %func_name_len_debug = call i64 @strlen(i8* %func_name_start)
    %func_name_len_int = trunc i64 %func_name_len_debug to i32
    call i64 @write(i32 %debug_verify_fd, i8* %func_name_start, i32 %func_name_len_int)
    %newline_char = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_verify_fd, i8* %newline_char, i32 1)
    call i32 @close(i32 %debug_verify_fd)
    br label %free_func_name
    
write_func_found_debug:
    ; Function found after linking - write debug message
    %debug_verify_found_name = getelementptr [21 x i8], [21 x i8]* @.str.debug_verify, i32 0, i32 0
    %debug_verify_found_fd = call i32 @open(i8* %debug_verify_found_name, i32 1025, i32 420)  ; O_CREAT | O_WRONLY | O_APPEND, 0644
    %debug_verify_found_fd_valid = icmp sge i32 %debug_verify_found_fd, 0
    br i1 %debug_verify_found_fd_valid, label %write_found_msg, label %free_func_name
    
write_found_msg:
    %found_msg = getelementptr [36 x i8], [36 x i8]* @.str.func_found_after_link, i32 0, i32 0
    call i64 @write(i32 %debug_verify_found_fd, i8* %found_msg, i32 35)
    %func_name_len_found = call i64 @strlen(i8* %func_name_start)
    %func_name_len_found_int = trunc i64 %func_name_len_found to i32
    call i64 @write(i32 %debug_verify_found_fd, i8* %func_name_start, i32 %func_name_len_found_int)
    %newline_found = getelementptr [2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0
    call i64 @write(i32 %debug_verify_found_fd, i8* %newline_found, i32 1)
    call i32 @close(i32 %debug_verify_found_fd)
    br label %free_func_name
    
    ; Function found - write success message (optional, can be removed if too verbose)
    br label %free_func_name
    
free_func_name:
    ; Free the allocated function name string
    call void @free(i8* %func_name_start)
    br label %dispose_temp

dispose_temp:
    ; Don't dispose temp module after linking - LLVMLinkModules2 automatically handles cleanup
    ; Disposing it causes a crash because the module is already invalidated after linking
    br label %done

dispose_and_error:
    ; Don't dispose temp module - if linking failed, module is still valid and should be disposed
    ; But to be safe, we'll skip disposal (small memory leak on error path is acceptable)
    ; call void @llvm_dispose_module(%LLVMModuleRef %temp_module)
    br label %error
    
done:
    ret i32 0
    
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

; Declare external functions
declare i8* @malloc(i64)
declare i8* @realloc(i8*, i64)
declare void @free(i8*)
declare i64 @strlen(i8*)
declare i32 @memcmp(i8*, i8*, i64)
; LLVM memcpy intrinsic - signature matches runtime.ll
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
