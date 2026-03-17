; Bootstrap Compiler Driver for Vibe
; Main entry point that orchestrates lexer → parser → code generation
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%Lexer = type { i8*, i64, i64, i32, i32 }
%Parser = type { %Lexer*, %Token* }
%Token = type { i32, i8*, i64, i32, i32 }
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }
%CodeGen = type { i8*, i64, i64, i32, i32 }

declare %Lexer* @lex_init(i8*, i64)
declare %Token* @lex_next(%Lexer*)
declare %Parser* @parse_init(%Lexer*)
declare %ASTNode* @parse_expr(%Parser*)
declare %CodeGen* @codegen_init(i8*)
declare i32 @codegen_define_bitcode(%CodeGen*, %ASTNode*)
declare i32 @codegen_main(%CodeGen*, %ASTNode*)
declare i8* @codegen_get_ir(%CodeGen*)

; Main function
; main: Main entry point for bootstrap compiler
; Parameters:
;   argc: Argument count
;   argv: Argument vector
; Returns: Exit code (0 on success, non-zero on error)
define i32 @main(i32 %argc, i8** %argv) {
entry:
    ; Check for minimum arguments (program name + input file)
    %min_args = icmp ult i32 %argc, 2
    br i1 %min_args, label %usage, label %parse_args

usage:
    call void @print_usage()
    ret i32 1

parse_args:
    ; Get input filename (first argument)
    %input_file_ptr = getelementptr i8*, i8** %argv, i64 1
    %input_file = load i8*, i8** %input_file_ptr
    
    ; Read input file
    %file_data = call i8* @read_file(i8* %input_file)
    %is_null = icmp eq i8* %file_data, null
    br i1 %is_null, label %file_error, label %compile

file_error:
    %file_error_msg = getelementptr [20 x i8], [20 x i8]* @.str.file_error, i32 0, i32 0
    call void @print_error(i8* %file_error_msg)
    ret i32 1

compile:
    ; Get file length (simplified - in real implementation, track this)
    %file_len = call i64 @strlen(i8* %file_data)
    
    ; Initialize lexer
    %lexer = call %Lexer* @lex_init(i8* %file_data, i64 %file_len)
    
    ; Initialize parser
    %parser = call %Parser* @parse_init(%Lexer* %lexer)
    
    ; Extract module name from input file path
    %module_name = call i8* @extract_module_name(i8* %input_file)
    %module_name_null = icmp eq i8* %module_name, null
    br i1 %module_name_null, label %module_name_error, label %init_codegen

module_name_error:
    ; If module name extraction fails, use null (will default to "vibe")
    br label %init_codegen

init_codegen:
    ; Initialize code generator with module name
    %module_name_to_use = phi i8* [ null, %module_name_error ], [ %module_name, %compile ]
    %codegen = call %CodeGen* @codegen_init(i8* %module_name_to_use)
    
    ; Free module name if it was allocated (LLVM copies it internally)
    %should_free = icmp ne i8* %module_name_to_use, null
    br i1 %should_free, label %free_module_name, label %after_free

free_module_name:
    call void @free(i8* %module_name_to_use)
    br label %after_free

after_free:
    ; Parse expressions until EOF, collecting AST nodes
    %exprs_list = alloca %ASTNode*
    store %ASTNode* null, %ASTNode** %exprs_list
    br label %parse_loop

parse_loop:
    ; Get current token from parser
    %current_token = call %Token* @parse_current(%Parser* %parser)
    %type_ptr = getelementptr %Token, %Token* %current_token, i32 0, i32 0
    %token_type = load i32, i32* %type_ptr
    %is_eof = icmp eq i32 %token_type, 0  ; TOKEN_EOF
    br i1 %is_eof, label %generate_code, label %parse_expr

parse_expr:
    ; Parse next expression
    %ast = call %ASTNode* @parse_expr(%Parser* %parser)
    %ast_null = icmp eq %ASTNode* %ast, null
    br i1 %ast_null, label %parse_error, label %process_ast

process_ast:
    ; Check if this is a define-bitcode form
    %ast_type_ptr = getelementptr %ASTNode, %ASTNode* %ast, i32 0, i32 0
    %ast_type = load i32, i32* %ast_type_ptr
    %is_list = icmp eq i32 %ast_type, 1  ; AST_LIST
    br i1 %is_list, label %check_define_bitcode, label %add_to_list

check_define_bitcode:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %ast, i32 0, i32 4
    %car = load %ASTNode*, %ASTNode** %car_ptr
    %car_type_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 0
    %car_type = load i32, i32* %car_type_ptr
    %car_is_atom = icmp eq i32 %car_type, 0  ; AST_ATOM
    br i1 %car_is_atom, label %check_name, label %add_to_list

check_name:
    ; Check which form this is by comparing the first element
    %car_val_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 2
    %car_val = load i8*, i8** %car_val_ptr
    %car_len_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 3
    %car_len = load i64, i64* %car_len_ptr
    
    ; Check for llvm:define-type
    %is_type = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.define_llvm_type, i32 0, i32 0), i64 16)
    %is_type_bool = icmp ne i32 %is_type, 0
    br i1 %is_type_bool, label %handle_type, label %check_constant
    
handle_type:
    call i32 @codegen_define_llvm_type(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_constant:
    ; Check for llvm:define-constant
    %is_constant = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_llvm_constant, i32 0, i32 0), i64 20)
    %is_constant_bool = icmp ne i32 %is_constant, 0
    br i1 %is_constant_bool, label %handle_constant, label %check_function
    
handle_constant:
    call i32 @codegen_define_llvm_constant(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_function:
    ; Check for llvm:define-function (new DSL-based form)
    %is_llvm_function = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_llvm_function, i32 0, i32 0), i64 20)
    %is_llvm_function_bool = icmp ne i32 %is_llvm_function, 0
    br i1 %is_llvm_function_bool, label %handle_llvm_function, label %check_ffi_function
    
handle_llvm_function:
    call i32 @codegen_define_llvm_function(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_ffi_function:
    ; Check for llvm:define-ffi-function (FFI-based form)
    %is_ffi_function = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.define_llvm_ffi_function, i32 0, i32 0), i64 24)
    %is_ffi_function_bool = icmp ne i32 %is_ffi_function, 0
    br i1 %is_ffi_function_bool, label %handle_ffi_function, label %check_declare_function
    
handle_ffi_function:
    call i32 @codegen_define_llvm_ffi_function(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop

check_declare_function:
    ; Check for llvm:declare-function (forward declaration form)
    %is_declare_function = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.declare_llvm_function, i32 0, i32 0), i64 21)
    %is_declare_function_bool = icmp ne i32 %is_declare_function, 0
    br i1 %is_declare_function_bool, label %handle_declare_function, label %check_bitcode_function

handle_declare_function:
    call i32 @codegen_declare_llvm_function(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_bitcode_function:
    ; Check for define-bitcode-function (old IR string form)
    %is_function = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.define_bitcode_function, i32 0, i32 0), i64 23)
    %is_function_bool = icmp ne i32 %is_function, 0
    br i1 %is_function_bool, label %handle_function, label %check_legacy
    
handle_function:
    call i32 @codegen_define_bitcode_function(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_legacy:
    ; Check for legacy define-bitcode (for backward compatibility)
    %is_legacy = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.define_bitcode, i32 0, i32 0), i64 14)
    %is_legacy_bool = icmp ne i32 %is_legacy, 0
    br i1 %is_legacy_bool, label %handle_legacy, label %add_to_list
    
handle_legacy:
    call i32 @codegen_define_bitcode(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop

add_to_list:
    ; Debug: log form added to exprs
    %debug_add_msg = getelementptr [41 x i8], [41 x i8]* @.str.debug_add_to_list, i32 0, i32 0
    call i32 (i8*, ...) @printf(i8* %debug_add_msg)
    ; Extract and print form identifier when possible
    %add_to_list_ast_null = icmp eq %ASTNode* %ast, null
    br i1 %add_to_list_ast_null, label %add_to_list_cons, label %add_to_list_debug_form
add_to_list_debug_form:
    %atl_ast_type_ptr = getelementptr %ASTNode, %ASTNode* %ast, i32 0, i32 0
    %atl_ast_type_val = load i32, i32* %atl_ast_type_ptr
    %atl_ast_is_list = icmp eq i32 %atl_ast_type_val, 1
    br i1 %atl_ast_is_list, label %add_to_list_get_car, label %add_to_list_atom_value
add_to_list_get_car:
    %atl_ast_car_ptr = getelementptr %ASTNode, %ASTNode* %ast, i32 0, i32 4
    %atl_ast_car = load %ASTNode*, %ASTNode** %atl_ast_car_ptr
    %atl_car_null = icmp eq %ASTNode* %atl_ast_car, null
    br i1 %atl_car_null, label %add_to_list_cons, label %add_to_list_car_type
add_to_list_car_type:
    %atl_car_type_ptr = getelementptr %ASTNode, %ASTNode* %atl_ast_car, i32 0, i32 0
    %atl_car_type = load i32, i32* %atl_car_type_ptr
    %atl_car_is_atom = icmp eq i32 %atl_car_type, 0
    br i1 %atl_car_is_atom, label %add_to_list_print_car, label %add_to_list_cons
add_to_list_print_car:
    %atl_car_value_ptr = getelementptr %ASTNode, %ASTNode* %atl_ast_car, i32 0, i32 2
    %atl_car_value = load i8*, i8** %atl_car_value_ptr
    %atl_car_len_ptr = getelementptr %ASTNode, %ASTNode* %atl_ast_car, i32 0, i32 3
    %atl_car_len = load i64, i64* %atl_car_len_ptr
    %atl_car_len_capped = icmp ugt i64 %atl_car_len, 256
    %atl_car_len_safe = select i1 %atl_car_len_capped, i64 256, i64 %atl_car_len
    %atl_car_len_i32 = trunc i64 %atl_car_len_safe to i32
    %atl_debug_car_fmt = getelementptr [25 x i8], [25 x i8]* @.str.debug_add_to_list_car, i32 0, i32 0
    call i32 (i8*, ...) @printf(i8* %atl_debug_car_fmt, i32 %atl_car_len_i32, i8* %atl_car_value)
    br label %add_to_list_cons
add_to_list_atom_value:
    %atl_ast_value_ptr = getelementptr %ASTNode, %ASTNode* %ast, i32 0, i32 2
    %atl_ast_value = load i8*, i8** %atl_ast_value_ptr
    %atl_ast_len_ptr = getelementptr %ASTNode, %ASTNode* %ast, i32 0, i32 3
    %atl_ast_len = load i64, i64* %atl_ast_len_ptr
    %atl_ast_len_capped = icmp ugt i64 %atl_ast_len, 256
    %atl_ast_len_safe = select i1 %atl_ast_len_capped, i64 256, i64 %atl_ast_len
    %atl_ast_len_i32 = trunc i64 %atl_ast_len_safe to i32
    %atl_debug_atom_fmt = getelementptr [25 x i8], [25 x i8]* @.str.debug_add_to_list_car, i32 0, i32 0
    call i32 (i8*, ...) @printf(i8* %atl_debug_atom_fmt, i32 %atl_ast_len_i32, i8* %atl_ast_value)
    br label %add_to_list_cons
add_to_list_cons:
    ; Add AST node to expressions list by creating a cons cell
    ; Allocate new cons cell
    %new_cons = call i8* @malloc(i64 48)
    %new_cons_ptr = bitcast i8* %new_cons to %ASTNode*
    
    ; Set node type to LIST
    %cons_type_ptr = getelementptr %ASTNode, %ASTNode* %new_cons_ptr, i32 0, i32 0
    store i32 1, i32* %cons_type_ptr  ; AST_LIST
    
    ; Set car to the current AST node
    %cons_car_ptr = getelementptr %ASTNode, %ASTNode* %new_cons_ptr, i32 0, i32 4
    store %ASTNode* %ast, %ASTNode** %cons_car_ptr
    
    ; Get current list head
    %current_list = load %ASTNode*, %ASTNode** %exprs_list
    
    ; Set cdr to current list (prepend)
    %cons_cdr_ptr = getelementptr %ASTNode, %ASTNode* %new_cons_ptr, i32 0, i32 5
    store %ASTNode* %current_list, %ASTNode** %cons_cdr_ptr
    
    ; Update list head
    store %ASTNode* %new_cons_ptr, %ASTNode** %exprs_list
    
    br label %parse_loop

parse_error:
    %parse_error_msg = getelementptr [13 x i8], [13 x i8]* @.str.parse_error, i32 0, i32 0
    call void @print_error(i8* %parse_error_msg)
    ret i32 1

generate_code:
    ; Generate main function with all top-level expressions
    %exprs = load %ASTNode*, %ASTNode** %exprs_list
    ; Debug: log exprs state before codegen_main
    %exprs_is_null = icmp eq %ASTNode* %exprs, null
    br i1 %exprs_is_null, label %generate_code_exprs_null, label %generate_code_exprs_nonnull
generate_code_exprs_null:
    %debug_null_msg = getelementptr [62 x i8], [62 x i8]* @.str.debug_generate_exprs_null, i32 0, i32 0
    call i32 (i8*, ...) @printf(i8* %debug_null_msg)
    br label %generate_code_do_main
generate_code_exprs_nonnull:
    %debug_nonnull_msg = getelementptr [63 x i8], [63 x i8]* @.str.debug_generate_exprs_nonnull, i32 0, i32 0
    call i32 (i8*, ...) @printf(i8* %debug_nonnull_msg)
    br label %generate_code_do_main
generate_code_do_main:
    call i32 @codegen_main(%CodeGen* %codegen, %ASTNode* %exprs)
    
    ; Emit debug files for inspection
    
    ; Check for output file argument
    %has_output = icmp ugt i32 %argc, 2
    br i1 %has_output, label %write_output, label %done

write_output:
    ; Get output filename (check for -o flag)
    %arg2_ptr = getelementptr i8*, i8** %argv, i64 2
    %arg2 = load i8*, i8** %arg2_ptr
    %dash_o_ptr = getelementptr [3 x i8], [3 x i8]* @.str.dash_o, i32 0, i32 0
    %is_o_flag = call i32 @strcmp(i8* %arg2, i8* %dash_o_ptr)
    %has_o = icmp eq i32 %is_o_flag, 0
    br i1 %has_o, label %get_output_file, label %use_arg2

get_output_file:
    ; Get output filename after -o
    %output_file_ptr = getelementptr i8*, i8** %argv, i64 3
    %output_file_o = load i8*, i8** %output_file_ptr
    br label %write_bitcode

use_arg2:
    %output_file_arg = load i8*, i8** %arg2_ptr
    br label %write_bitcode

write_bitcode:
    ; Write bitcode, IR text, or object file based on extension
    %output_file_phi = phi i8* [ %output_file_o, %get_output_file ], [ %output_file_arg, %use_arg2 ]
    
    ; Check if output file ends with .o (object file)
    %ext_o_check = call i32 @check_extension(i8* %output_file_phi, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.dot_o, i32 0, i32 0))
    %is_object_file = icmp ne i32 %ext_o_check, 0
    br i1 %is_object_file, label %write_object, label %check_ll
    
check_ll:
    ; Check if output file ends with .ll (IR text)
    %ext_ll_check = call i32 @check_extension(i8* %output_file_phi, i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.dot_ll, i32 0, i32 0))
    %is_ir_text = icmp ne i32 %ext_ll_check, 0
    br i1 %is_ir_text, label %write_ir_text, label %write_bc
    
write_object:
    ; Write object file directly
    %write_obj_result = call i32 @codegen_write_object_file(%CodeGen* %codegen, i8* %output_file_phi)
    %write_obj_failed = icmp ne i32 %write_obj_result, 0
    br i1 %write_obj_failed, label %write_error, label %done
    
write_ir_text:
    ; Write IR text to file (for conversion with llvm-as)
    %write_ir_result = call i32 @codegen_write_ir_text(%CodeGen* %codegen, i8* %output_file_phi)
    %write_ir_failed = icmp ne i32 %write_ir_result, 0
    br i1 %write_ir_failed, label %write_error, label %done
    
write_bc:
    ; Write bitcode to file using LLVM API
    %write_result = call i32 @codegen_write_bitcode(%CodeGen* %codegen, i8* %output_file_phi)
    %write_failed = icmp ne i32 %write_result, 0
    br i1 %write_failed, label %write_error, label %done

write_error:
    %write_error_msg = getelementptr [20 x i8], [20 x i8]* @.str.write_error, i32 0, i32 0
    call void @print_error(i8* %write_error_msg)
    ret i32 1

done:
    ; Cleanup
    call void @codegen_dispose(%CodeGen* %codegen)
    call void @free(i8* %file_data)
    ret i32 0
}

; print_usage: Print usage message (defined in main.vibe)
declare void @print_usage()

; print_error: Print error message (defined in main.vibe)
declare void @print_error(i8*)

; print_string: Print a string to stdout (defined in main.vibe)
declare void @print_string(i8*)

; read_file: Read a file into memory (defined in main.vibe)
declare i8* @read_file(i8*)

; write_file: Write content to file (defined in main.vibe)
declare i32 @write_file(i8*, i8*, i64)

; check_identifier: Check if identifier matches (defined in main.vibe)
declare i32 @check_identifier(i8*, i64, i8*, i64)

; check_extension: Check if filename ends with extension (defined in main.vibe)
declare i32 @check_extension(i8*, i8*)

; extract_module_name: Extract module name from file path (defined in main.vibe)
declare i8* @extract_module_name(i8*)

; String literals (.str.usage moved to main.vibe)
@.str.file_error = private unnamed_addr constant [20 x i8] c"Error reading file\0A\00"
@.str.parse_error = private unnamed_addr constant [13 x i8] c"Parse error\0A\00"
@.str.write_error = private unnamed_addr constant [20 x i8] c"Error writing file\0A\00"
@.str.dash_o = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.define_llvm_type = private unnamed_addr constant [17 x i8] c"llvm:define-type\00"
@.str.define_llvm_constant = private unnamed_addr constant [21 x i8] c"llvm:define-constant\00"
@.str.define_llvm_function = private unnamed_addr constant [21 x i8] c"llvm:define-function\00"
@.str.define_llvm_ffi_function = private unnamed_addr constant [25 x i8] c"llvm:define-ffi-function\00"
@.str.declare_llvm_function = private unnamed_addr constant [22 x i8] c"llvm:declare-function\00"
@.str.define_bitcode_function = private unnamed_addr constant [24 x i8] c"define-bitcode-function\00"
@.str.define_bitcode = private unnamed_addr constant [15 x i8] c"define-bitcode\00"
@.str.dot_o = private unnamed_addr constant [3 x i8] c".o\00"
@.str.dot_ll = private unnamed_addr constant [4 x i8] c".ll\00"
@.str.debug_add_to_list = private unnamed_addr constant [41 x i8] c"[MAIN] add_to_list: form added to exprs\0A\00"
@.str.debug_add_to_list_car = private unnamed_addr constant [25 x i8] c"[MAIN]   form car: %.*s\0A\00"
@.str.debug_generate_exprs_null = private unnamed_addr constant [62 x i8] c"[MAIN] generate_code: exprs=null (no main will be generated)\0A\00"
@.str.debug_generate_exprs_nonnull = private unnamed_addr constant [63 x i8] c"[MAIN] generate_code: exprs=non-null (main will be generated)\0A\00"

; Declare external functions
declare i8* @malloc(i64)
declare void @free(i8*)
declare i64 @strlen(i8*)
declare i64 @write(i32, i8*, i32)
declare i32 @open(i8*, i32, ...)
declare i64 @read(i32, i8*, i64)
declare i32 @close(i32)
declare %Token* @parse_current(%Parser*)
declare i32 @strcmp(i8*, i8*)
declare i32 @strncmp(i8*, i8*, i32)
declare i32 @codegen_define_llvm_type(%CodeGen*, %ASTNode*)
declare i32 @codegen_define_llvm_constant(%CodeGen*, %ASTNode*)
declare i32 @codegen_define_bitcode_function(%CodeGen*, %ASTNode*)
declare i32 @codegen_define_llvm_function(%CodeGen*, %ASTNode*)
declare i32 @codegen_define_llvm_ffi_function(%CodeGen*, %ASTNode*)
declare i32 @codegen_declare_llvm_function(%CodeGen*, %ASTNode*)
declare void @codegen_dispose(%CodeGen*)
declare i32 @codegen_write_bitcode(%CodeGen*, i8*)
declare i32 @codegen_write_ir_text(%CodeGen*, i8*)
declare i32 @codegen_write_object_file(%CodeGen*, i8*)
declare i32 @printf(i8*, ...)
