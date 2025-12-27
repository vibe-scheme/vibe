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

; extract_module_name: Extract module name from file path
; Extracts basename and optionally strips extension
; Parameters:
;   filepath: Full file path (null-terminated)
; Returns: Pointer to module name string (allocated with malloc), or null on error
; NOTE: The returned string must be freed by caller
; Algorithm:
;   1. Find last '/' character (or start of string if none)
;   2. Extract basename (everything after last '/')
;   3. Find last '.' character in basename
;   4. If found, strip extension (everything from '.' to end)
;   5. Return the result
define i8* @extract_module_name(i8* %filepath) {
entry:
    %filepath_null = icmp eq i8* %filepath, null
    br i1 %filepath_null, label %error, label %get_length

get_length:
    %path_len = call i64 @strlen(i8* %filepath)
    %path_len_zero = icmp eq i64 %path_len, 0
    br i1 %path_len_zero, label %error, label %find_last_slash

find_last_slash:
    ; Find last '/' character
    %last_slash_pos = alloca i64
    store i64 0, i64* %last_slash_pos  ; Default to start of string
    %i = alloca i64
    store i64 0, i64* %i
    br label %slash_loop

slash_loop:
    %i_val = load i64, i64* %i
    %done = icmp uge i64 %i_val, %path_len
    br i1 %done, label %extract_basename, label %check_slash

check_slash:
    %char_ptr = getelementptr i8, i8* %filepath, i64 %i_val
    %char = load i8, i8* %char_ptr
    %char_int = zext i8 %char to i32
    %is_slash = icmp eq i32 %char_int, 47  ; '/' = 47
    br i1 %is_slash, label %update_slash_pos, label %increment_slash

update_slash_pos:
    ; Update last slash position (position after the slash)
    %slash_pos_after = add i64 %i_val, 1
    store i64 %slash_pos_after, i64* %last_slash_pos
    br label %increment_slash

increment_slash:
    %i_next = add i64 %i_val, 1
    store i64 %i_next, i64* %i
    br label %slash_loop

extract_basename:
    ; Extract basename starting from last_slash_pos
    %basename_start = load i64, i64* %last_slash_pos
    %basename_len = sub i64 %path_len, %basename_start
    %basename_len_zero = icmp eq i64 %basename_len, 0
    br i1 %basename_len_zero, label %error, label %find_last_dot

find_last_dot:
    ; Find last '.' character in basename
    %last_dot_pos = alloca i64
    store i64 0, i64* %last_dot_pos  ; 0 means no dot found
    %j = alloca i64
    store i64 0, i64* %j
    br label %dot_loop

dot_loop:
    %j_val = load i64, i64* %j
    %dot_done = icmp uge i64 %j_val, %basename_len
    br i1 %dot_done, label %determine_length, label %check_dot

check_dot:
    %basename_char_ptr = getelementptr i8, i8* %filepath, i64 %basename_start
    %basename_char_offset = getelementptr i8, i8* %basename_char_ptr, i64 %j_val
    %basename_char = load i8, i8* %basename_char_offset
    %basename_char_int = zext i8 %basename_char to i32
    %is_dot = icmp eq i32 %basename_char_int, 46  ; '.' = 46
    br i1 %is_dot, label %update_dot_pos, label %increment_dot

update_dot_pos:
    ; Store position of dot (relative to basename start)
    store i64 %j_val, i64* %last_dot_pos
    br label %increment_dot

increment_dot:
    %j_next = add i64 %j_val, 1
    store i64 %j_next, i64* %j
    br label %dot_loop

determine_length:
    ; Determine final length (basename_len if no dot, or up to dot if dot found)
    %dot_pos = load i64, i64* %last_dot_pos
    %has_dot = icmp ne i64 %dot_pos, 0
    br i1 %has_dot, label %use_dot_length, label %use_full_length

use_dot_length:
    ; Use length up to (but not including) the dot
    br label %allocate_name

use_full_length:
    ; Use full basename length
    br label %allocate_name

allocate_name:
    %final_len = phi i64 [ %dot_pos, %use_dot_length ], [ %basename_len, %use_full_length ]
    %final_len_zero = icmp eq i64 %final_len, 0
    br i1 %final_len_zero, label %error, label %alloc_buf

alloc_buf:
    %buf_size = add i64 %final_len, 1  ; +1 for null terminator
    %buf = call i8* @malloc(i64 %buf_size)
    %buf_null = icmp eq i8* %buf, null
    br i1 %buf_null, label %error, label %copy_name

copy_name:
    ; Copy basename (up to dot if found) to buffer
    %basename_ptr = getelementptr i8, i8* %filepath, i64 %basename_start
    %i_copy = alloca i64
    store i64 0, i64* %i_copy
    br label %copy_loop

copy_loop:
    %i_copy_val = load i64, i64* %i_copy
    %copy_done = icmp uge i64 %i_copy_val, %final_len
    br i1 %copy_done, label %null_terminate, label %copy_char

copy_char:
    %src_char_ptr = getelementptr i8, i8* %basename_ptr, i64 %i_copy_val
    %src_char = load i8, i8* %src_char_ptr
    %dst_char_ptr = getelementptr i8, i8* %buf, i64 %i_copy_val
    store i8 %src_char, i8* %dst_char_ptr
    %i_copy_next = add i64 %i_copy_val, 1
    store i64 %i_copy_next, i64* %i_copy
    br label %copy_loop

null_terminate:
    %null_ptr = getelementptr i8, i8* %buf, i64 %final_len
    store i8 0, i8* %null_ptr
    ret i8* %buf

error:
    ret i8* null
}

; String literals
@.str.usage = private unnamed_addr constant [47 x i8] c"Usage: bootstrap_compiler <input> [-o output]\0A\00"
@.str.file_error = private unnamed_addr constant [20 x i8] c"Error reading file\0A\00"
@.str.parse_error = private unnamed_addr constant [13 x i8] c"Parse error\0A\00"
@.str.write_error = private unnamed_addr constant [20 x i8] c"Error writing file\0A\00"
@.str.dash_o = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.define_llvm_type = private unnamed_addr constant [17 x i8] c"llvm:define-type\00"
@.str.define_llvm_constant = private unnamed_addr constant [21 x i8] c"llvm:define-constant\00"
@.str.define_llvm_function = private unnamed_addr constant [21 x i8] c"llvm:define-function\00"
@.str.define_llvm_ffi_function = private unnamed_addr constant [25 x i8] c"llvm:define-ffi-function\00"
@.str.define_bitcode_function = private unnamed_addr constant [24 x i8] c"define-bitcode-function\00"
@.str.define_bitcode = private unnamed_addr constant [15 x i8] c"define-bitcode\00"
@.str.dot_o = private unnamed_addr constant [3 x i8] c".o\00"
@.str.dot_ll = private unnamed_addr constant [4 x i8] c".ll\00"

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
declare i32 @codegen_write_ir_text(%CodeGen*, i8*)
declare i32 @codegen_write_object_file(%CodeGen*, i8*)
