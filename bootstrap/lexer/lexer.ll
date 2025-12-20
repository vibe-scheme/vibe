; Bootstrap Lexer for Vibe
; Implements tokenization for R7RS Scheme lexical syntax
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Token types enum
; TOKEN_EOF = 0
; TOKEN_IDENTIFIER = 1
; TOKEN_NUMBER = 2
; TOKEN_STRING = 3
; TOKEN_SYMBOL = 4
; TOKEN_LPAREN = 5
; TOKEN_RPAREN = 6
; TOKEN_QUOTE = 7
; TOKEN_QUASIQUOTE = 8
; TOKEN_UNQUOTE = 9
; TOKEN_UNQUOTE_SPLICING = 10
; TOKEN_DOT = 11
; TOKEN_ERROR = 12
; TOKEN_BYTEVECTOR = 13

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%Token = type { i32, i8*, i64, i32, i32 }
%Lexer = type { i8*, i64, i64, i32, i32 }

; Initialize lexer with source string
; lex_init: Initialize a lexer with source code
; Parameters:
;   source: Pointer to source code string
;   source_len: Length of source code string
; Returns: Pointer to initialized Lexer structure
; NOTE: This function is also defined in lexer.vibe for second bootstrap.
; For initial bootstrap, this definition is used. For second bootstrap,
; the lexer.vibe version will be used (and this can be removed).
define %Lexer* @lex_init(i8* %source, i64 %source_len) {
entry:
    ; Allocate memory for Lexer structure
    %lexer = call i8* @malloc(i64 40)
    %lexer_ptr = bitcast i8* %lexer to %Lexer*
    
    ; Initialize lexer fields
    %source_ptr = getelementptr %Lexer, %Lexer* %lexer_ptr, i32 0, i32 0
    store i8* %source, i8** %source_ptr
    
    %len_ptr = getelementptr %Lexer, %Lexer* %lexer_ptr, i32 0, i32 1
    store i64 %source_len, i64* %len_ptr
    
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer_ptr, i32 0, i32 2
    store i64 0, i64* %pos_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer_ptr, i32 0, i32 3
    store i32 1, i32* %line_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer_ptr, i32 0, i32 4
    store i32 1, i32* %col_ptr
    
    ret %Lexer* %lexer_ptr
}

; Check if we've reached end of input
; lex_is_eof: Check if lexer has reached end of source
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: 1 if EOF, 0 otherwise
define i32 @lex_is_eof(%Lexer* %lexer) {
entry:
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    
    %len_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 1
    %len = load i64, i64* %len_ptr
    
    %cmp = icmp uge i64 %pos, %len
    %result = zext i1 %cmp to i32
    ret i32 %result
}

; Get current character
; lex_current_char: Get character at current position
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Current character (i8), or 0 if EOF
define i8 @lex_current_char(%Lexer* %lexer) {
entry:
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %eof_bool = icmp ne i32 %is_eof, 0
    br i1 %eof_bool, label %eof, label %not_eof

eof:
    ret i8 0

not_eof:
    %source_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 0
    %source = load i8*, i8** %source_ptr
    
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    
    %char_ptr = getelementptr i8, i8* %source, i64 %pos
    %char = load i8, i8* %char_ptr
    ret i8 %char
}

; Advance to next character
; lex_advance: Move to next character, updating line/column
; Parameters:
;   lexer: Pointer to Lexer structure
define void @lex_advance(%Lexer* %lexer) {
entry:
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %eof_bool = icmp ne i32 %is_eof, 0
    br i1 %eof_bool, label %done, label %advance

advance:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    
    ; Check if newline
    %is_newline = icmp eq i32 %char_int, 10
    br i1 %is_newline, label %newline, label %normal

newline:
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %new_line = add i32 %line, 1
    store i32 %new_line, i32* %line_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    store i32 1, i32* %col_ptr
    br label %increment_pos

normal:
    %col_ptr_normal = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr_normal
    %new_col = add i32 %col, 1
    store i32 %new_col, i32* %col_ptr_normal
    br label %increment_pos

increment_pos:
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    %new_pos = add i64 %pos, 1
    store i64 %new_pos, i64* %pos_ptr
    br label %done

done:
    ret void
}

; Skip whitespace
; lex_skip_whitespace: Skip whitespace characters
; Parameters:
;   lexer: Pointer to Lexer structure
define void @lex_skip_whitespace(%Lexer* %lexer) {
entry:
    br label %loop

loop:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    
    ; Check if whitespace (space, tab, newline, carriage return)
    %is_space = icmp eq i32 %char_int, 32
    %is_tab = icmp eq i32 %char_int, 9
    %is_newline = icmp eq i32 %char_int, 10
    %is_cr = icmp eq i32 %char_int, 13
    
    %is_ws1 = or i1 %is_space, %is_tab
    %is_ws2 = or i1 %is_newline, %is_cr
    %is_ws = or i1 %is_ws1, %is_ws2
    
    br i1 %is_ws, label %skip, label %done

skip:
    call void @lex_advance(%Lexer* %lexer)
    br label %loop

done:
    ret void
}

; Check if character is a delimiter
; lex_is_delimiter: Check if character is a delimiter
; Parameters:
;   char: Character to check
; Returns: 1 if delimiter, 0 otherwise
define i32 @lex_is_delimiter(i8 %char) {
entry:
    %char_int = zext i8 %char to i32
    
    ; Delimiters: whitespace, parens, quote, semicolon
    %is_space = icmp eq i32 %char_int, 32
    %is_tab = icmp eq i32 %char_int, 9
    %is_newline = icmp eq i32 %char_int, 10
    %is_cr = icmp eq i32 %char_int, 13
    %is_lparen = icmp eq i32 %char_int, 40
    %is_rparen = icmp eq i32 %char_int, 41
    %is_quote = icmp eq i32 %char_int, 39
    %is_semicolon = icmp eq i32 %char_int, 59
    %is_eof = icmp eq i32 %char_int, 0
    
    %ws1 = or i1 %is_space, %is_tab
    %ws2 = or i1 %is_newline, %is_cr
    %ws = or i1 %ws1, %ws2
    
    %punct1 = or i1 %is_lparen, %is_rparen
    %punct2 = or i1 %is_quote, %is_semicolon
    %punct = or i1 %punct1, %punct2
    
    %delim = or i1 %ws, %punct
    %result = or i1 %delim, %is_eof
    
    %res = zext i1 %result to i32
    ret i32 %res
}

; Read identifier or symbol
; lex_read_identifier: Read an identifier or symbol token
; Parameters:
;   lexer: Pointer to Lexer structure
;   start: Starting position in source
;   start_len: Starting length
; Returns: Pointer to Token structure
define %Token* @lex_read_identifier(%Lexer* %lexer, i64 %start, i64 %start_len) {
entry:
    %len_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 1
    %source_len = load i64, i64* %len_ptr
    
    ; Calculate length
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    %len = sub i64 %pos, %start
    
    ; Allocate token
    %token = call i8* @malloc(i64 32)
    %token_ptr = bitcast i8* %token to %Token*
    
    ; Determine token type (check if it's a symbol starting with #, or a number)
    %source_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 0
    %source = load i8*, i8** %source_ptr
    %first_char_ptr = getelementptr i8, i8* %source, i64 %start
    %first_char = load i8, i8* %first_char_ptr
    %first_int = zext i8 %first_char to i32
    %is_hash = icmp eq i32 %first_int, 35
    
    ; Check if first character is a digit
    %is_digit_first = icmp uge i32 %first_int, 48  ; '0'
    %is_digit_first2 = icmp ule i32 %first_int, 57  ; '9'
    %is_digit_first_both = and i1 %is_digit_first, %is_digit_first2
    
    ; If starts with digit, check if all characters are digits
    br i1 %is_digit_first_both, label %check_all_digits, label %check_hash
    
check_all_digits:
    ; Check if all characters in the token are digits
    %i = alloca i64
    store i64 0, i64* %i
    br label %digit_check_loop
    
digit_check_loop:
    %i_val = load i64, i64* %i
    %done_check = icmp uge i64 %i_val, %len
    br i1 %done_check, label %all_digits, label %check_char
    
check_char:
    %char_idx_ptr = getelementptr i8, i8* %first_char_ptr, i64 %i_val
    %char_idx = load i8, i8* %char_idx_ptr
    %char_idx_int = zext i8 %char_idx to i32
    %is_digit_char = icmp uge i32 %char_idx_int, 48  ; '0'
    %is_digit_char2 = icmp ule i32 %char_idx_int, 57  ; '9'
    %is_digit_char_both = and i1 %is_digit_char, %is_digit_char2
    br i1 %is_digit_char_both, label %next_char, label %not_all_digits
    
next_char:
    %i_new = add i64 %i_val, 1
    store i64 %i_new, i64* %i
    br label %digit_check_loop
    
all_digits:
    ; All characters are digits, this is a number
    br label %set_token_type
    
not_all_digits:
    ; Not all digits, treat as identifier
    br label %check_hash
    
check_hash:
    %token_type = select i1 %is_hash, i32 4, i32 1  ; TOKEN_SYMBOL or TOKEN_IDENTIFIER
    br label %set_token_type
    
set_token_type:
    %token_type_phi = phi i32 [ %token_type, %check_hash ], [ 2, %all_digits ]  ; TOKEN_NUMBER = 2
    
    ; Copy value
    %value = call i8* @malloc(i64 %len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %value, i8* %first_char_ptr, i64 %len, i1 false)
    
    ; Set token fields
    %type_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 0
    store i32 %token_type_phi, i32* %type_ptr
    
    %val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 1
    store i8* %value, i8** %val_ptr
    
    %len_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 2
    store i64 %len, i64* %len_val_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %line_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 3
    store i32 %line, i32* %line_val_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %col_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 4
    store i32 %col, i32* %col_val_ptr
    
    ret %Token* %token_ptr
}

; Read string
; lex_read_string: Read a string token
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Pointer to Token structure, or null on error
define %Token* @lex_read_string(%Lexer* %lexer) {
entry:
    %start_pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %start_pos = load i64, i64* %start_pos_ptr
    %start = add i64 %start_pos, 1  ; Skip opening quote
    
    %buffer = call i8* @malloc(i64 1024)
    %buffer_pos = alloca i64
    store i64 0, i64* %buffer_pos
    
    call void @lex_advance(%Lexer* %lexer)  ; Skip opening quote
    
    br label %loop

loop:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    
    %eof_bool = icmp ne i32 %is_eof, 0
    br i1 %eof_bool, label %error, label %check_quote

check_quote:
    %is_quote = icmp eq i32 %char_int, 34  ; Double quote
    br i1 %is_quote, label %done, label %check_escape

check_escape:
    %is_backslash = icmp eq i32 %char_int, 92  ; Backslash
    br i1 %is_backslash, label %escape, label %normal_char

escape:
    call void @lex_advance(%Lexer* %lexer)
    %next_char = call i8 @lex_current_char(%Lexer* %lexer)
    %next_int = zext i8 %next_char to i32
    
    ; Handle escape sequences
    %pos_escape = load i64, i64* %buffer_pos
    %char_ptr_escape = getelementptr i8, i8* %buffer, i64 %pos_escape
    
    ; Simple escape handling (just copy the next char for now)
    store i8 %next_char, i8* %char_ptr_escape
    %new_pos_escape = add i64 %pos_escape, 1
    store i64 %new_pos_escape, i64* %buffer_pos
    
    call void @lex_advance(%Lexer* %lexer)
    br label %loop

normal_char:
    %pos_normal = load i64, i64* %buffer_pos
    %char_ptr_normal = getelementptr i8, i8* %buffer, i64 %pos_normal
    store i8 %char, i8* %char_ptr_normal
    %new_pos_normal = add i64 %pos_normal, 1
    store i64 %new_pos_normal, i64* %buffer_pos
    
    call void @lex_advance(%Lexer* %lexer)
    br label %loop

done:
    call void @lex_advance(%Lexer* %lexer)  ; Skip closing quote
    
    ; Create token
    %token = call i8* @malloc(i64 32)
    %token_ptr = bitcast i8* %token to %Token*
    
    %len = load i64, i64* %buffer_pos
    %value = call i8* @malloc(i64 %len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %value, i8* %buffer, i64 %len, i1 false)
    
    %type_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 0
    store i32 3, i32* %type_ptr  ; TOKEN_STRING
    
    %val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 1
    store i8* %value, i8** %val_ptr
    
    %len_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 2
    store i64 %len, i64* %len_val_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %line_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 3
    store i32 %line, i32* %line_val_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %col_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 4
    store i32 %col, i32* %col_val_ptr
    
    call void @free(i8* %buffer)
    ret %Token* %token_ptr

error:
    call void @free(i8* %buffer)
    ret %Token* null
}

; Peek at character at offset from current position
; lex_peek_char: Peek at character at given offset
; Parameters:
;   lexer: Pointer to Lexer structure
;   offset: Offset from current position
; Returns: Character at offset, or 0 if out of bounds
define i8 @lex_peek_char(%Lexer* %lexer, i64 %offset) {
entry:
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %pos = load i64, i64* %pos_ptr
    %peek_pos = add i64 %pos, %offset
    
    %len_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 1
    %len = load i64, i64* %len_ptr
    %is_oob = icmp uge i64 %peek_pos, %len
    br i1 %is_oob, label %out_of_bounds, label %in_bounds

out_of_bounds:
    ret i8 0

in_bounds:
    %source_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 0
    %source = load i8*, i8** %source_ptr
    %char_ptr = getelementptr i8, i8* %source, i64 %peek_pos
    %char = load i8, i8* %char_ptr
    ret i8 %char
}

; Read vertical bar delimited symbol
; lex_read_vertical_bar_symbol: Read a symbol delimited by vertical bars
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Pointer to Token structure (TOKEN_IDENTIFIER or TOKEN_SYMBOL)
define %Token* @lex_read_vertical_bar_symbol(%Lexer* %lexer) {
entry:
    call void @lex_advance(%Lexer* %lexer)  ; Skip opening |
    %start_pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %start_pos = load i64, i64* %start_pos_ptr
    
    %buffer = call i8* @malloc(i64 1024)
    %buffer_pos = alloca i64
    store i64 0, i64* %buffer_pos
    
    br label %loop

loop:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %is_vbar = icmp eq i32 %char_int, 124  ; Vertical bar |
    
    %eof_bool = icmp ne i32 %is_eof, 0
    %done = or i1 %eof_bool, %is_vbar
    br i1 %done, label %check_closing, label %append_char

append_char:
    %pos = load i64, i64* %buffer_pos
    %char_ptr = getelementptr i8, i8* %buffer, i64 %pos
    store i8 %char, i8* %char_ptr
    %new_pos = add i64 %pos, 1
    store i64 %new_pos, i64* %buffer_pos
    
    call void @lex_advance(%Lexer* %lexer)
    br label %loop

check_closing:
    %eof_bool_check = icmp ne i32 %is_eof, 0
    br i1 %eof_bool_check, label %error, label %done_ok

done_ok:
    call void @lex_advance(%Lexer* %lexer)  ; Skip closing |
    
    ; Create token
    %token = call i8* @malloc(i64 32)
    %token_ptr = bitcast i8* %token to %Token*
    
    %len = load i64, i64* %buffer_pos
    %value = call i8* @malloc(i64 %len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %value, i8* %buffer, i64 %len, i1 false)
    
    %type_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 0
    store i32 1, i32* %type_ptr  ; TOKEN_IDENTIFIER
    
    %val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 1
    store i8* %value, i8** %val_ptr
    
    %len_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 2
    store i64 %len, i64* %len_val_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %line_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 3
    store i32 %line, i32* %line_val_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %col_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 4
    store i32 %col, i32* %col_val_ptr
    
    call void @free(i8* %buffer)
    ret %Token* %token_ptr

error:
    call void @free(i8* %buffer)
    %error_msg = call %Token* @lex_error(%Lexer* %lexer, i8* getelementptr inbounds ([29 x i8], [29 x i8]* @.str.unclosed_vbar, i32 0, i32 0))
    ret %Token* %error_msg
}

; Read bytevector
; lex_read_bytevector: Read a R7RS bytevector #u8(...)
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Pointer to Token structure (TOKEN_BYTEVECTOR)
define %Token* @lex_read_bytevector(%Lexer* %lexer) {
entry:
    ; Skip #u8(
    call void @lex_advance(%Lexer* %lexer)  ; Skip #
    call void @lex_advance(%Lexer* %lexer)  ; Skip u
    call void @lex_advance(%Lexer* %lexer)  ; Skip 8
    call void @lex_advance(%Lexer* %lexer)  ; Skip (
    
    %buffer = call i8* @malloc(i64 1024)
    %buffer_pos = alloca i64
    store i64 0, i64* %buffer_pos
    
    br label %loop

loop:
    call void @lex_skip_whitespace(%Lexer* %lexer)
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %is_rparen = icmp eq i32 %char_int, 41  ; ')'
    
    %eof_bool = icmp ne i32 %is_eof, 0
    %done = or i1 %eof_bool, %is_rparen
    br i1 %done, label %check_closing, label %read_number

read_number:
    ; Simple number reading (0-255)
    %num_start = call i8 @lex_current_char(%Lexer* %lexer)
    %num_start_int = zext i8 %num_start to i32
    %is_digit = icmp uge i32 %num_start_int, 48
    %is_digit2 = icmp ule i32 %num_start_int, 57
    %is_digit_both = and i1 %is_digit, %is_digit2
    br i1 %is_digit_both, label %read_digits, label %error

read_digits:
    %num_val = alloca i32
    store i32 0, i32* %num_val
    
    br label %digit_loop

digit_loop:
    %digit_char = call i8 @lex_current_char(%Lexer* %lexer)
    %digit_int = zext i8 %digit_char to i32
    %is_digit_check = icmp uge i32 %digit_int, 48
    %is_digit_check2 = icmp ule i32 %digit_int, 57
    %is_digit_ok = and i1 %is_digit_check, %is_digit_check2
    br i1 %is_digit_ok, label %accumulate, label %store_byte

accumulate:
    %current_val = load i32, i32* %num_val
    %new_val = mul i32 %current_val, 10
    %digit_val = sub i32 %digit_int, 48
    %final_val = add i32 %new_val, %digit_val
    store i32 %final_val, i32* %num_val
    
    call void @lex_advance(%Lexer* %lexer)
    br label %digit_loop

store_byte:
    %byte_val = load i32, i32* %num_val
    %byte_val_trunc = trunc i32 %byte_val to i8
    %pos = load i64, i64* %buffer_pos
    %byte_ptr = getelementptr i8, i8* %buffer, i64 %pos
    store i8 %byte_val_trunc, i8* %byte_ptr
    %new_pos = add i64 %pos, 1
    store i64 %new_pos, i64* %buffer_pos
    
    br label %loop

check_closing:
    %eof_bool_check = icmp ne i32 %is_eof, 0
    br i1 %eof_bool_check, label %error, label %done_ok

done_ok:
    call void @lex_advance(%Lexer* %lexer)  ; Skip closing )
    
    ; Create token
    %token = call i8* @malloc(i64 32)
    %token_ptr = bitcast i8* %token to %Token*
    
    %len = load i64, i64* %buffer_pos
    %value = call i8* @malloc(i64 %len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %value, i8* %buffer, i64 %len, i1 false)
    
    %type_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 0
    store i32 13, i32* %type_ptr  ; TOKEN_BYTEVECTOR
    
    %val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 1
    store i8* %value, i8** %val_ptr
    
    %len_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 2
    store i64 %len, i64* %len_val_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %line_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 3
    store i32 %line, i32* %line_val_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %col_val_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 4
    store i32 %col, i32* %col_val_ptr
    
    call void @free(i8* %buffer)
    ret %Token* %token_ptr

error:
    call void @free(i8* %buffer)
    %error_msg = call %Token* @lex_error(%Lexer* %lexer, i8* getelementptr inbounds ([26 x i8], [26 x i8]* @.str.invalid_bytevector, i32 0, i32 0))
    ret %Token* %error_msg
}

; Skip comment
; lex_skip_comment: Skip a line comment (semicolon to newline)
; Parameters:
;   lexer: Pointer to Lexer structure
define void @lex_skip_comment(%Lexer* %lexer) {
entry:
    br label %loop

loop:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %is_newline = icmp eq i32 %char_int, 10
    
    %eof_bool = icmp ne i32 %is_eof, 0
    %done = or i1 %eof_bool, %is_newline
    
    br i1 %done, label %exit, label %continue

continue:
    call void @lex_advance(%Lexer* %lexer)
    br label %loop

exit:
    ret void
}

; Get next token
; lex_next: Get the next token from source
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Pointer to Token structure
define %Token* @lex_next(%Lexer* %lexer) {
entry:
    call void @lex_skip_whitespace(%Lexer* %lexer)
    
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %eof_bool = icmp ne i32 %is_eof, 0
    br i1 %eof_bool, label %eof, label %not_eof

eof:
    %eof_token = call i8* @malloc(i64 32)
    %eof_token_ptr = bitcast i8* %eof_token to %Token*
    %type_ptr_eof = getelementptr %Token, %Token* %eof_token_ptr, i32 0, i32 0
    store i32 0, i32* %type_ptr_eof  ; TOKEN_EOF
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.debug_prefix_lexer, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_eof_token, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %Token* %eof_token_ptr

not_eof:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    
    ; Check for comment
    %is_semicolon = icmp eq i32 %char_int, 59
    br i1 %is_semicolon, label %comment, label %check_string

comment:
    call void @lex_skip_comment(%Lexer* %lexer)
    ; Recursively call lex_next to get next token after comment
    %next_token = call %Token* @lex_next(%Lexer* %lexer)
    ret %Token* %next_token

check_string:
    %is_dquote = icmp eq i32 %char_int, 34
    br i1 %is_dquote, label %string, label %check_vertical_bar

string:
    %str_token = call %Token* @lex_read_string(%Lexer* %lexer)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %str_token)
    ret %Token* %str_token

check_vertical_bar:
    %is_vbar = icmp eq i32 %char_int, 124  ; Vertical bar |
    br i1 %is_vbar, label %vertical_bar_symbol, label %check_hash

vertical_bar_symbol:
    %vbar_token = call %Token* @lex_read_vertical_bar_symbol(%Lexer* %lexer)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %vbar_token)
    ret %Token* %vbar_token

check_hash:
    %is_hash = icmp eq i32 %char_int, 35  ; Hash #
    br i1 %is_hash, label %check_bytevector, label %check_lparen

check_bytevector:
    ; Check if next characters are "u8("
    %peek1 = call i8 @lex_peek_char(%Lexer* %lexer, i64 1)
    %peek1_int = zext i8 %peek1 to i32
    %is_u = icmp eq i32 %peek1_int, 117  ; 'u'
    br i1 %is_u, label %check_u8, label %identifier

check_u8:
    %peek2 = call i8 @lex_peek_char(%Lexer* %lexer, i64 2)
    %peek2_int = zext i8 %peek2 to i32
    %is_8 = icmp eq i32 %peek2_int, 56  ; '8'
    br i1 %is_8, label %check_u8_lparen, label %identifier

check_u8_lparen:
    %peek3 = call i8 @lex_peek_char(%Lexer* %lexer, i64 3)
    %peek3_int = zext i8 %peek3 to i32
    %is_lparen_u8 = icmp eq i32 %peek3_int, 40  ; '('
    br i1 %is_lparen_u8, label %bytevector, label %identifier

bytevector:
    %bytevec_token = call %Token* @lex_read_bytevector(%Lexer* %lexer)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %bytevec_token)
    ret %Token* %bytevec_token

check_lparen:
    %is_lparen = icmp eq i32 %char_int, 40
    br i1 %is_lparen, label %lparen, label %check_rparen

lparen:
    %lparen_token = call i8* @malloc(i64 32)
    %lparen_token_ptr = bitcast i8* %lparen_token to %Token*
    %type_ptr_lparen = getelementptr %Token, %Token* %lparen_token_ptr, i32 0, i32 0
    store i32 5, i32* %type_ptr_lparen  ; TOKEN_LPAREN
    call void @lex_advance(%Lexer* %lexer)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %lparen_token_ptr)
    ret %Token* %lparen_token_ptr

check_rparen:
    %is_rparen = icmp eq i32 %char_int, 41
    br i1 %is_rparen, label %rparen, label %check_quote_char

rparen:
    %rparen_token = call i8* @malloc(i64 32)
    %rparen_token_ptr = bitcast i8* %rparen_token to %Token*
    %type_ptr_rparen = getelementptr %Token, %Token* %rparen_token_ptr, i32 0, i32 0
    store i32 6, i32* %type_ptr_rparen  ; TOKEN_RPAREN
    call void @lex_advance(%Lexer* %lexer)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %rparen_token_ptr)
    ret %Token* %rparen_token_ptr

check_quote_char:
    %is_quote = icmp eq i32 %char_int, 39
    br i1 %is_quote, label %quote, label %identifier

quote:
    %quote_token = call i8* @malloc(i64 32)
    %quote_token_ptr = bitcast i8* %quote_token to %Token*
    %type_ptr_quote = getelementptr %Token, %Token* %quote_token_ptr, i32 0, i32 0
    store i32 7, i32* %type_ptr_quote  ; TOKEN_QUOTE
    call void @lex_advance(%Lexer* %lexer)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %quote_token_ptr)
    ret %Token* %quote_token_ptr

identifier:
    %start_pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %start_pos = load i64, i64* %start_pos_ptr
    
    br label %read_loop

read_loop:
    %char_loop = call i8 @lex_current_char(%Lexer* %lexer)
    %is_delim = call i32 @lex_is_delimiter(i8 %char_loop)
    %delim_bool = icmp ne i32 %is_delim, 0
    br i1 %delim_bool, label %done_id, label %continue_id

continue_id:
    call void @lex_advance(%Lexer* %lexer)
    br label %read_loop

done_id:
    %id_token = call %Token* @lex_read_identifier(%Lexer* %lexer, i64 %start_pos, i64 0)
    ; Debug logging
    call void @lex_debug_log_token(%Token* %id_token)
    ret %Token* %id_token
}

; Peek at next token without consuming
; lex_peek: Peek at next token without advancing lexer
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Pointer to Token structure
define %Token* @lex_peek(%Lexer* %lexer) {
entry:
    %pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %saved_pos = load i64, i64* %pos_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %saved_line = load i32, i32* %line_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %saved_col = load i32, i32* %col_ptr
    
    %token = call %Token* @lex_next(%Lexer* %lexer)
    
    ; Restore position
    store i64 %saved_pos, i64* %pos_ptr
    store i32 %saved_line, i32* %line_ptr
    store i32 %saved_col, i32* %col_ptr
    
    ret %Token* %token
}

; Report lexing error
; lex_error: Report a lexing error
; Parameters:
;   lexer: Pointer to Lexer structure
;   message: Error message string
; Returns: Pointer to error token
define %Token* @lex_error(%Lexer* %lexer, i8* %message) {
entry:
    %error_token = call i8* @malloc(i64 32)
    %error_token_ptr = bitcast i8* %error_token to %Token*
    %type_ptr = getelementptr %Token, %Token* %error_token_ptr, i32 0, i32 0
    store i32 12, i32* %type_ptr  ; TOKEN_ERROR
    
    %val_ptr = getelementptr %Token, %Token* %error_token_ptr, i32 0, i32 1
    store i8* %message, i8** %val_ptr
    
    %line_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %line_val_ptr = getelementptr %Token, %Token* %error_token_ptr, i32 0, i32 3
    store i32 %line, i32* %line_val_ptr
    
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %col_val_ptr = getelementptr %Token, %Token* %error_token_ptr, i32 0, i32 4
    store i32 %col, i32* %col_val_ptr
    
    ret %Token* %error_token_ptr
}

; String literals
@.str.unclosed_vbar = private unnamed_addr constant [29 x i8] c"Unclosed vertical bar symbol\00"
@.str.invalid_bytevector = private unnamed_addr constant [26 x i8] c"Invalid bytevector syntax\00"

; Debug logging helper
; lex_debug_log_token: Print token information for debugging
; Parameters:
;   token: Pointer to Token structure
define void @lex_debug_log_token(%Token* %token) {
entry:
    %token_null = icmp eq %Token* %token, null
    br i1 %token_null, label %done, label %log_token
    
log_token:
    ; Get token type
    %type_ptr = getelementptr %Token, %Token* %token, i32 0, i32 0
    %type = load i32, i32* %type_ptr
    
    ; Get token value
    %value_ptr = getelementptr %Token, %Token* %token, i32 0, i32 1
    %value = load i8*, i8** %value_ptr
    %len_ptr = getelementptr %Token, %Token* %token, i32 0, i32 2
    %len = load i64, i64* %len_ptr
    
    ; Get position
    %line_ptr = getelementptr %Token, %Token* %token, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %col_ptr = getelementptr %Token, %Token* %token, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    
    ; Print prefix
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.debug_prefix_lexer, i32 0, i32 0))
    
    ; Print token info
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_token_fmt, i32 0, i32 0), i32 %type, i32 %line, i32 %col)
    
    ; Print value if present
    %has_value = icmp ne i8* %value, null
    %has_len = icmp ne i64 %len, 0
    %should_print = and i1 %has_value, %has_len
    br i1 %should_print, label %print_value, label %done
    
print_value:
    ; Create null-terminated string for printing
    %buf_size = add i64 %len, 1
    %buf = call i8* @malloc(i64 %buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %buf, i8* %value, i64 %len, i1 false)
    %null_ptr = getelementptr i8, i8* %buf, i64 %len
    store i8 0, i8* %null_ptr
    call i32 (i8*, ...) @printf(i8* %buf)
    call void @free(i8* %buf)
    br label %done
    
done:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret void
}

; String literals for debug logging
@.str.debug_prefix_lexer = private unnamed_addr constant [9 x i8] c"[LEXER] \00"
@.str.debug_token_fmt = private unnamed_addr constant [31 x i8] c"Token type=%d line=%d col=%d: \00"
@.str.debug_newline = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str.empty = private unnamed_addr constant [1 x i8] c"\00"
@.str.debug_eof_token = private unnamed_addr constant [11 x i8] c"EOF token\0A\00"

; Declare external functions
declare i8* @malloc(i64)
declare void @free(i8*)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare i32 @printf(i8*, ...)
