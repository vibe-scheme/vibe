; Bootstrap Compiler Driver for Vibe
; Main entry point that orchestrates lexer → parser → code generation
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%Lexer = type { i8*, i64, i64, i32, i32 }
%Parser = type { %Lexer*, %Token* }
%Token = type { i32, i8*, i64, i32, i32 }
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }
%Runtime = type { %SymbolTable*, %BitcodeBinding*, i64, i8*, i64 }
%CodeGen = type { i8*, i64, i64, i32, i32 }
%SymbolTable = type { %VibeSymbol**, i64, i64 }
%BitcodeBinding = type { i8*, i64, i8*, i64, %BitcodeBinding* }
%VibeSymbol = type { i64, i8*, i64, %VibeSymbol* }

declare %Lexer* @lex_init(i8*, i64)
declare %Token* @lex_next(%Lexer*)
declare %Parser* @parse_init(%Lexer*)
declare %ASTNode* @parse_expr(%Parser*)
declare %Runtime* @runtime_init(i64)
declare %CodeGen* @codegen_init()
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
    
    ; Initialize runtime
    %heap_size = add i64 1048576, 0  ; 1MB heap
    %runtime = call %Runtime* @runtime_init(i64 %heap_size)
    
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
    
    ; Initialize code generator
    %codegen = call %CodeGen* @codegen_init()
    
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
    
    ; Check for define-llvm-type
    %is_type = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.define_llvm_type, i32 0, i32 0), i64 16)
    %is_type_bool = icmp ne i32 %is_type, 0
    br i1 %is_type_bool, label %handle_type, label %check_constant
    
handle_type:
    call i32 @codegen_define_llvm_type(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_constant:
    ; Check for define-llvm-constant
    %is_constant = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_llvm_constant, i32 0, i32 0), i64 20)
    %is_constant_bool = icmp ne i32 %is_constant, 0
    br i1 %is_constant_bool, label %handle_constant, label %check_function
    
handle_constant:
    call i32 @codegen_define_llvm_constant(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_function:
    ; Check for define-llvm-function (new DSL-based form)
    %is_llvm_function = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.define_llvm_function, i32 0, i32 0), i64 20)
    %is_llvm_function_bool = icmp ne i32 %is_llvm_function, 0
    br i1 %is_llvm_function_bool, label %handle_llvm_function, label %check_ffi_function
    
handle_llvm_function:
    call i32 @codegen_define_llvm_function(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop
    
check_ffi_function:
    ; Check for define-llvm-ffi-function (FFI-based form)
    %is_ffi_function = call i32 @check_identifier(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.define_llvm_ffi_function, i32 0, i32 0), i64 24)
    %is_ffi_function_bool = icmp ne i32 %is_ffi_function, 0
    br i1 %is_ffi_function_bool, label %handle_ffi_function, label %check_bitcode_function
    
handle_ffi_function:
    call i32 @codegen_define_llvm_ffi_function(%CodeGen* %codegen, %ASTNode* %ast)
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
    call i32 @codegen_main(%CodeGen* %codegen, %ASTNode* %exprs)
    
    ; Emit debug files for inspection
    call i32 @codegen_emit_debug_files(%CodeGen* %codegen, i8* %input_file)
    
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
    ; Write bitcode or object file based on extension
    %output_file_phi = phi i8* [ %output_file_o, %get_output_file ], [ %output_file_arg, %use_arg2 ]
    
    ; Check if output file ends with .o (object file)
    %ext_check = call i32 @check_extension(i8* %output_file_phi, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.dot_o, i32 0, i32 0))
    %is_object_file = icmp ne i32 %ext_check, 0
    br i1 %is_object_file, label %write_object, label %write_bc
    
write_object:
    ; Write object file directly
    %write_obj_result = call i32 @codegen_write_object_file(%CodeGen* %codegen, i8* %output_file_phi)
    %write_obj_failed = icmp ne i32 %write_obj_result, 0
    br i1 %write_obj_failed, label %write_error, label %done
    
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

; Print usage information
; print_usage: Print usage message
define void @print_usage() {
entry:
    %usage_msg = getelementptr [47 x i8], [47 x i8]* @.str.usage, i32 0, i32 0
    call void @print_string(i8* %usage_msg)
    ret void
}

; Print error message
; print_error: Print error message
; Parameters:
;   message: Error message string
define void @print_error(i8* %message) {
entry:
    call void @print_string(i8* %message)
    ret void
}

; Print string to stdout
; print_string: Print a string to stdout
; Parameters:
;   str: String to print (null-terminated)
define void @print_string(i8* %str) {
entry:
    %len = call i64 @strlen(i8* %str)
    %len_int = trunc i64 %len to i32
    call i32 @write(i32 1, i8* %str, i32 %len_int)
    ret void
}

; Read file into memory
; read_file: Read a file into memory
; Parameters:
;   filename: File path (null-terminated)
; Returns: File contents (null-terminated), or null on error
define i8* @read_file(i8* %filename) {
entry:
    ; Open file
    %fd = call i32 @open(i8* %filename, i32 0)  ; O_RDONLY
    %fd_neg = icmp slt i32 %fd, 0
    br i1 %fd_neg, label %error, label %get_size

get_size:
    ; Get file size using stat or fstat
    ; For simplicity, use a fixed buffer size
    %buffer_size = add i64 65536, 0  ; 64KB buffer
    %buffer = call i8* @malloc(i64 %buffer_size)
    
    ; Read file
    %bytes_read = call i64 @read(i32 %fd, i8* %buffer, i64 %buffer_size)
    call i32 @close(i32 %fd)
    
    %read_error = icmp slt i64 %bytes_read, 0
    br i1 %read_error, label %read_fail, label %success

read_fail:
    call void @free(i8* %buffer)
    br label %error

success:
    ; Null-terminate
    %null_ptr = getelementptr i8, i8* %buffer, i64 %bytes_read
    store i8 0, i8* %null_ptr
    ret i8* %buffer

error:
    ret i8* null
}

; Write file
; write_file: Write content to file
; Parameters:
;   filename: Output file path
;   content: Content to write
;   len: Content length
; Returns: 0 on success, -1 on error
define i32 @write_file(i8* %filename, i8* %content, i64 %len) {
entry:
    %fd = call i32 @open(i8* %filename, i32 577, i32 420)  ; O_CREAT | O_WRONLY | O_TRUNC, 0644
    %fd_neg = icmp slt i32 %fd, 0
    br i1 %fd_neg, label %error, label %write_content

write_content:
    %len_int = trunc i64 %len to i32
    %bytes_written = call i64 @write(i32 %fd, i8* %content, i32 %len_int)
    call i32 @close(i32 %fd)
    %write_failed = icmp slt i64 %bytes_written, 0
    br i1 %write_failed, label %error, label %success

success:
    ret i32 0

error:
    ret i32 -1
}

; Check if identifier matches
; check_identifier: Check if an identifier matches a string
; Parameters:
;   id: Identifier string
;   id_len: Identifier length
;   target: Target string to match
;   target_len: Target length
; Returns: 1 if matches, 0 otherwise
define i32 @check_identifier(i8* %id, i64 %id_len, i8* %target, i64 %target_len) {
entry:
    ; Compare lengths first
    %len_match = icmp eq i64 %id_len, %target_len
    br i1 %len_match, label %compare_chars, label %no_match
    
compare_chars:
    ; Use strncmp to compare strings (with length limit)
    ; strncmp returns 0 if strings match
    %len_int = trunc i64 %id_len to i32
    %cmp_result = call i32 @strncmp(i8* %id, i8* %target, i32 %len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %match, label %no_match
    
match:
    ret i32 1
    
no_match:
    ret i32 0
}

; Check if filename ends with extension
; check_extension: Check if a filename ends with a given extension
; Parameters:
;   filename: Filename string (null-terminated)
;   extension: Extension string (null-terminated, e.g., ".o")
; Returns: 1 if filename ends with extension, 0 otherwise
define i32 @check_extension(i8* %filename, i8* %extension) {
entry:
    ; Get lengths
    %filename_len = call i64 @strlen(i8* %filename)
    %ext_len = call i64 @strlen(i8* %extension)
    
    ; Check if filename is long enough
    %len_ok = icmp uge i64 %filename_len, %ext_len
    br i1 %len_ok, label %check_suffix, label %no_match
    
check_suffix:
    ; Calculate offset to start of suffix
    %suffix_offset = sub i64 %filename_len, %ext_len
    %suffix_ptr = getelementptr i8, i8* %filename, i64 %suffix_offset
    
    ; Compare suffix with extension
    %ext_len_int = trunc i64 %ext_len to i32
    %cmp_result = call i32 @strncmp(i8* %suffix_ptr, i8* %extension, i32 %ext_len_int)
    %is_match = icmp eq i32 %cmp_result, 0
    br i1 %is_match, label %match, label %no_match
    
match:
    ret i32 1
    
no_match:
    ret i32 0
}

; String literals
@.str.usage = private unnamed_addr constant [47 x i8] c"Usage: bootstrap_compiler <input> [-o output]\0A\00"
@.str.file_error = private unnamed_addr constant [20 x i8] c"Error reading file\0A\00"
@.str.parse_error = private unnamed_addr constant [13 x i8] c"Parse error\0A\00"
@.str.write_error = private unnamed_addr constant [20 x i8] c"Error writing file\0A\00"
@.str.dash_o = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.define_llvm_type = private unnamed_addr constant [17 x i8] c"define-llvm-type\00"
@.str.define_llvm_constant = private unnamed_addr constant [21 x i8] c"define-llvm-constant\00"
@.str.define_llvm_function = private unnamed_addr constant [21 x i8] c"define-llvm-function\00"
@.str.define_llvm_ffi_function = private unnamed_addr constant [25 x i8] c"define-llvm-ffi-function\00"
@.str.define_bitcode_function = private unnamed_addr constant [24 x i8] c"define-bitcode-function\00"
@.str.define_bitcode = private unnamed_addr constant [15 x i8] c"define-bitcode\00"
@.str.dot_o = private unnamed_addr constant [3 x i8] c".o\00"

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
declare void @codegen_dispose(%CodeGen*)
declare i32 @codegen_write_bitcode(%CodeGen*, i8*)
declare i32 @codegen_write_object_file(%CodeGen*, i8*)
declare i32 @codegen_emit_debug_files(%CodeGen*, i8*)
