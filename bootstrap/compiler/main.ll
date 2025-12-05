; Bootstrap Compiler Driver for Vibe
; Main entry point that orchestrates lexer → parser → code generation
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Forward declarations
%Lexer = type { i8*, i64, i64, i32, i32 }
%Parser = type { %Lexer*, %Token* }
%Token = type { i32, i8*, i64, i32, i32 }
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }
%Runtime = type { %SymbolTable*, %BitcodeBinding*, i64, i8*, i64 }
%CodeGen = type { i8*, i64, i64, i32, i32 }

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
    call void @print_error(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.file_error, i32 0, i32 0))
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
    ; Check if first element is "define-bitcode"
    %car_val_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 2
    %car_val = load i8*, i8** %car_val_ptr
    ; Simplified check - in full implementation, compare strings
    ; For now, assume it's define-bitcode if we have a list starting with an atom
    call i32 @codegen_define_bitcode(%CodeGen* %codegen, %ASTNode* %ast)
    br label %parse_loop

add_to_list:
    ; Add AST node to expressions list (simplified - in full implementation, build proper list)
    ; For now, just continue parsing
    br label %parse_loop

parse_error:
    call void @print_error(i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.parse_error, i32 0, i32 0))
    ret i32 1

generate_code:
    ; Generate main function with all top-level expressions
    %exprs = load %ASTNode*, %ASTNode** %exprs_list
    call i32 @codegen_main(%CodeGen* %codegen, %ASTNode* %exprs)
    
    ; Get generated IR
    %ir = call i8* @codegen_get_ir(%CodeGen* %codegen)
    
    ; Check for output file argument
    %has_output = icmp ugt i32 %argc, 2
    br i1 %has_output, label %write_output, label %done

write_output:
    ; Get output filename (check for -o flag)
    %arg2_ptr = getelementptr i8*, i8** %argv, i64 2
    %arg2 = load i8*, i8** %arg2_ptr
    %is_o_flag = call i32 @strcmp(i8* %arg2, i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.dash_o, i32 0, i32 0))
    %has_o = icmp eq i32 %is_o_flag, 0
    br i1 %has_o, label %get_output_file, label %use_arg2

get_output_file:
    ; Get output filename after -o
    %output_file_ptr = getelementptr i8*, i8** %argv, i64 3
    %output_file = load i8*, i8** %output_file_ptr
    br label %write_ir

use_arg2:
    %output_file = load i8*, i8** %arg2_ptr
    br label %write_ir

write_ir:
    ; Write IR to file
    %ir_len = call i64 @strlen(i8* %ir)
    %write_result = call i32 @write_file(i8* %output_file, i8* %ir, i64 %ir_len)
    %write_failed = icmp ne i32 %write_result, 0
    br i1 %write_failed, label %write_error, label %done

write_error:
    call void @print_error(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.write_error, i32 0, i32 0))
    ret i32 1

done:
    ; Cleanup
    call void @free(i8* %file_data)
    ret i32 0
}

; Print usage information
; print_usage: Print usage message
define void @print_usage() {
entry:
    %usage_msg = getelementptr inbounds ([45 x i8], [45 x i8]* @.str.usage, i32 0, i32 0)
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

; String literals
@.str.usage = private unnamed_addr constant [45 x i8] c"Usage: bootstrap_compiler <input> [-o output]\0A\00"
@.str.file_error = private unnamed_addr constant [20 x i8] c"Error reading file\0A\00"
@.str.parse_error = private unnamed_addr constant [14 x i8] c"Parse error\0A\00"
@.str.write_error = private unnamed_addr constant [20 x i8] c"Error writing file\0A\00"
@.str.dash_o = private unnamed_addr constant [3 x i8] c"-o\00"

; Declare external functions
declare i8* @malloc(i64)
declare void @free(i8*)
declare i64 @strlen(i8*)
declare i32 @write(i32, i8*, i32)
declare i64 @write(i32, i8*, i32)
declare i32 @open(i8*, i32, ...)
declare i64 @read(i32, i8*, i64)
declare i32 @close(i32)
declare %Token* @parse_current(%Parser*)
declare i32 @strcmp(i8*, i8*)
