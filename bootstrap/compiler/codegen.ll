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
    ; Generate: @name = constant type c"..." (convert bytevector to LLVM string literal)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %name, i64 %name_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.constant_equals, i32 0, i32 0), i64 11)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %type, i64 %type_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.c_quote_open, i32 0, i32 0), i64 2)
    ; Append bytevector data with escaping (convert null bytes to \00, etc.)
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
    
    ; TODO: Write parameters (for now, skip - will be added if needed)
    ; For bootstrap, we'll parse functions without parameters first
    
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
    
    ; Parse function IR into module
    ; TODO: Re-enable once function merging is implemented
    ; For now, skip parsing to avoid segfault - functions are still generated as text IR
    ; %parse_result = call i32 @codegen_parse_function_ir(%CodeGen* %cg, i8* %func_def_buf, i64 %pos_val17)
    
    ; Free buffer
    call void @free(i8* %func_def_buf)
    
    ; Also generate text IR for backward compatibility
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.define, i32 0, i32 0), i64 7)
    call void @codegen_append(%CodeGen* %cg, i8* %return_type, i64 %return_type_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %func_name, i64 %func_name_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i32 0, i32 0), i64 1)
    call void @codegen_append_typed_params(%CodeGen* %cg, %ASTNode* %params_list)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.rparen_brace, i32 0, i32 0), i64 3)
    call void @codegen_append(%CodeGen* %cg, i8* %ir_body, i64 %ir_body_len)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.close_brace, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0), i64 1)
    
    ret i32 0
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
    br label %text_only
    
text_only:
    ; Also generate text IR for backward compatibility
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_main, i32 0, i32 0), i64 20)
    call void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %exprs)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.ret_zero, i32 0, i32 0), i64 11)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.close_brace, i32 0, i32 0), i64 1)
    
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
    
    ; Generate function call with proper indentation
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call i32 @codegen_call(%CodeGen* %cg, i8* %func_name, %ASTNode* %args)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0), i64 1)
    
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
    ; Format: "target triple = \"...\"\n\n[func_ir]\n"
    ; Use the target triple from the module instead of a constant
    %target_triple_array = bitcast [27 x i8]* @.str.target_triple_value to i8*
    %target_triple_len = add i64 26, 0  ; length without null (x86_64-apple-macosx10.15.0 = 26 chars)
    %target_triple_prefix_len = add i64 16, 0  ; "target triple = \"" (16 chars)
    %target_triple_suffix_len = add i64 2, 0   ; "\"\n\n"
    %prefix_and_triple = add i64 %target_triple_prefix_len, %target_triple_len
    %total_prefix = add i64 %prefix_and_triple, %target_triple_suffix_len
    %module_ir_size = add i64 %total_prefix, %func_ir_len
    %module_ir_size2 = add i64 %module_ir_size, 1  ; null terminator
    %module_ir_buf = call i8* @malloc(i64 %module_ir_size2)
    %buf_null = icmp eq i8* %module_ir_buf, null
    br i1 %buf_null, label %error, label %build_module_ir
    
build_module_ir:
    ; Build: "target triple = \"x86_64-apple-macosx10.15.0\"\n\n[func_ir]\n"
    %pos = alloca i64
    store i64 0, i64* %pos
    
    ; Write "target triple = \""
    %pos_val1 = load i64, i64* %pos
    %dest1 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val1
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest1, i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.target_triple_prefix, i32 0, i32 0), i64 16, i1 false)
    %pos_val2 = add i64 %pos_val1, 16
    store i64 %pos_val2, i64* %pos
    
    ; Write target triple value
    %pos_val3 = load i64, i64* %pos
    %dest2 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val3
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest2, i8* %target_triple_array, i64 %target_triple_len, i1 false)
    %pos_val4 = add i64 %pos_val3, %target_triple_len
    store i64 %pos_val4, i64* %pos
    
    ; Write "\"\n\n"
    %pos_val5 = load i64, i64* %pos
    %dest3 = getelementptr i8, i8* %module_ir_buf, i64 %pos_val5
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dest3, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.target_triple_suffix, i32 0, i32 0), i64 3, i1 false)
    %pos_val6 = add i64 %pos_val5, 3
    store i64 %pos_val6, i64* %pos
    
    ; Copy function IR
    %pos_val7 = load i64, i64* %pos
    %func_dest = getelementptr i8, i8* %module_ir_buf, i64 %pos_val7
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_dest, i8* %func_ir, i64 %func_ir_len, i1 false)
    %pos_val8 = add i64 %pos_val7, %func_ir_len
    store i64 %pos_val8, i64* %pos
    
    ; Add final newline and null terminate
    %pos_val9 = load i64, i64* %pos
    %newline_ptr = getelementptr i8, i8* %module_ir_buf, i64 %pos_val9
    store i8 10, i8* %newline_ptr  ; '\n'
    %pos_val10 = add i64 %pos_val9, 1
    %null_ptr = getelementptr i8, i8* %module_ir_buf, i64 %pos_val10
    store i8 0, i8* %null_ptr
    
    ; Use pos_val10 as total length (includes null terminator, but we pass length without it)
    %total_len = sub i64 %pos_val10, 1
    
    ; Parse into temporary module
    %temp_module_ptr = alloca %LLVMModuleRef
    %parse_result = call i32 @llvm_parse_ir_in_context(%LLVMContextRef %context, i8* %module_ir_buf, i64 %total_len, %LLVMModuleRef* %temp_module_ptr)
    
    ; Free buffer
    call void @free(i8* %module_ir_buf)
    
    ; Check parse result
    %parse_failed = icmp ne i32 %parse_result, 0
    br i1 %parse_failed, label %error, label %success
    
success:
    ; For bootstrap, we'll keep the parsed module separate for now
    ; TODO: Extract functions from temp module and add to main module
    ; For now, just dispose the temp module since we're keeping text IR
    %temp_module = load %LLVMModuleRef, %LLVMModuleRef* %temp_module_ptr
    %temp_module_null = icmp eq %LLVMModuleRef %temp_module, null
    br i1 %temp_module_null, label %done, label %dispose_temp
    
dispose_temp:
    call void @llvm_dispose_module(%LLVMModuleRef %temp_module)
    br label %done
    
done:
    ret i32 0
    
error:
    ret i32 -1
}

; Write bitcode to file
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

; String literals
@.str.target_triple = private unnamed_addr constant [47 x i8] c"target triple = \22x86_64-apple-macosx10.15.0\22\0A\0A\00"
@.str.printf_decl = private unnamed_addr constant [42 x i8] c"declare i32 @printf(i8* nocapture, ...)\0A\0A\00"
@.str.module_name = private unnamed_addr constant [5 x i8] c"vibe\00"
@.str.target_triple_value = private unnamed_addr constant [27 x i8] c"x86_64-apple-macosx10.15.0\00"
@.str.space_at = private unnamed_addr constant [3 x i8] c" @\00"
@.str.newline_close_brace = private unnamed_addr constant [4 x i8] c"\0A}\0A\00"
@.str.main_name = private unnamed_addr constant [5 x i8] c"main\00"
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
@.str.constant_decl = private unnamed_addr constant [22 x i8] c" = private constant [\00"
@.str.x_i8_c_quote = private unnamed_addr constant [10 x i8] c" x i8] c\22\00"
@.str.quote_newline = private unnamed_addr constant [3 x i8] c"\22\0A\00"
@.str.getelementptr_start = private unnamed_addr constant [16 x i8] c"getelementptr [\00"
@.str.getelementptr_open = private unnamed_addr constant [15 x i8] c"getelementptr(\00"
@.str.lbracket = private unnamed_addr constant [2 x i8] c"[\00"
@.str.x_i8_bracket_comma = private unnamed_addr constant [10 x i8] c" x i8], [\00"
@.str.x_i8_ptr_at = private unnamed_addr constant [10 x i8] c" x i8]* @\00"
@.str.getelementptr_indices = private unnamed_addr constant [15 x i8] c", i32 0, i32 0\00"

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

; Declare external functions
declare i8* @malloc(i64)
declare i8* @realloc(i8*, i64)
declare void @free(i8*)
declare i64 @strlen(i8*)
; LLVM memcpy intrinsic - signature matches runtime.ll
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
