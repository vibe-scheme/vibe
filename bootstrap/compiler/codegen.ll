; Bootstrap Code Generator for Vibe
; Generates LLVM IR from AST nodes
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Forward declarations
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }

; Code generator state structure
; struct CodeGen {
;     i8* ir_buffer;        ; Buffer for generated IR text
;     i64 buffer_size;      ; Current buffer size
;     i64 buffer_pos;       ; Current position in buffer
;     i32 string_counter;   ; Counter for unique string constant names
;     i32 label_counter;   ; Counter for unique label names
; }

%CodeGen = type { i8*, i64, i64, i32, i32 }

; Initialize code generator
; codegen_init: Initialize code generator
; Returns: Pointer to CodeGen structure
define %CodeGen* @codegen_init() {
entry:
    %cg = call i8* @malloc(i64 32)
    %cg_ptr = bitcast i8* %cg to %CodeGen*
    
    ; Allocate initial buffer (64KB)
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
    
    ; Write target triple header (44 bytes without null terminator)
    call void @codegen_append(%CodeGen* %cg_ptr, i8* getelementptr inbounds ([45 x i8], [45 x i8]* @.str.target_triple, i32 0, i32 0), i64 44)
    
    ; Write printf declaration (31 bytes without null terminator)
    call void @codegen_append(%CodeGen* %cg_ptr, i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.printf_decl, i32 0, i32 0), i64 31)
    
    ret %CodeGen* %cg_ptr
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
    
    ; Calculate string length including null terminator
    %str_len = add i64 %len, 1
    
    ; Generate IR: @.str_N = private constant [L x i8] c"...\00"
    ; This is simplified - in real implementation, properly escape the string
    call void @codegen_append_string_constant(%CodeGen* %cg, i8* %name, i8* %str, i64 %len)
    
    ret i8* %name
}

; Helper to format string constant name
; codegen_format_string_name: Format a string constant name
; Parameters:
;   num: Number for unique name
; Returns: Formatted name string
define i8* @codegen_format_string_name(i32 %num) {
entry:
    ; Simplified - allocate buffer and format
    ; In real implementation, use sprintf or similar
    %buffer = call i8* @malloc(i64 32)
    ; For now, return a simple name
    ; This would be properly formatted in a full implementation
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
    ; This is a placeholder - full implementation would properly escape and format
    ; For now, just append a placeholder
    ret void
}

; Handle define-bitcode AST node
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
    call void @codegen_append(%CodeGen* %cg, i8* %name, i64 0)  ; Length 0 means use strlen
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
    
    ; Append: i8* %param_name
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.i8_ptr, i32 0, i32 0), i64 3)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.percent, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* %param_name, i64 0)
    
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
    call void @codegen_append(%CodeGen* %cg, i8* %func_name, i64 0)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i32 0, i32 0), i64 1)
    
    ; Generate arguments
    call void @codegen_append_call_args(%CodeGen* %cg, %ASTNode* %args)
    
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rparen, i32 0, i32 0), i64 1)
    
    ret i32 0
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
    ; Generate string constant and use it
    %str_val_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 2
    %str_val = load i8*, i8** %str_val_ptr
    %str_len_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 3
    %str_len = load i64, i64* %str_len_ptr
    
    ; Generate string constant name
    %const_name = call i8* @codegen_string_literal(%CodeGen* %cg, i8* %str_val, i64 %str_len)
    
    ; Generate: getelementptr to get pointer to string
    ; This is simplified - full implementation would generate proper getelementptr
    call void @codegen_append(%CodeGen* %cg, i8* %const_name, i64 0)
    
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

; Generate main function
; codegen_main: Generate main function with top-level expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   exprs: AST node list of top-level expressions
; Returns: 0 on success, -1 on error
define i32 @codegen_main(%CodeGen* %cg, %ASTNode* %exprs) {
entry:
    ; Generate: define i32 @main() {
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_main, i32 0, i32 0), i64 20)
    
    ; Generate code for each top-level expression
    call void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %exprs)
    
    ; Generate: ret i32 0
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.ret_zero, i32 0, i32 0), i64 11)
    
    ; Close function
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
    
    ; Generate function call
    call i32 @codegen_call(%CodeGen* %cg, i8* %func_name, %ASTNode* %args)
    
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

; String literals
@.str.target_triple = private unnamed_addr constant [45 x i8] c"target triple = x86_64-apple-macosx10.15.0\0A\0A\00"
@.str.printf_decl = private unnamed_addr constant [32 x i8] c"declare i32 @printf(i8*, ...)\0A\0A\00"
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

; Declare external functions
declare i8* @malloc(i64)
declare i8* @realloc(i8*, i64)
declare void @free(i8*)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias, i8* noalias, i64, i1)
