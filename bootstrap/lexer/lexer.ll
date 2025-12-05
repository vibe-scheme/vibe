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

; Token structure
; struct Token {
;     i32 type;           // Token type
;     i8* value;          // Token value (for identifiers, strings, numbers)
;     i64 value_len;      // Length of value
;     i32 line;           // Line number
;     i32 column;         // Column number
; }

%Token = type { i32, i8*, i64, i32, i32 }

; Lexer state structure
; struct Lexer {
;     i8* source;         // Source code string
;     i64 source_len;     // Length of source
;     i64 pos;            // Current position
;     i32 line;           // Current line number
;     i32 column;         // Current column number
; }

%Lexer = type { i8*, i64, i64, i32, i32 }

; Initialize lexer with source string
; lex_init: Initialize a lexer with source code
; Parameters:
;   source: Pointer to source code string
;   source_len: Length of source code string
; Returns: Pointer to initialized Lexer structure
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
    %col_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %new_col = add i32 %col, 1
    store i32 %new_col, i32* %col_ptr
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
    br label %entry

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
    
    ; Determine token type (check if it's a symbol starting with #)
    %source_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 0
    %source = load i8*, i8** %source_ptr
    %first_char_ptr = getelementptr i8, i8* %source, i64 %start
    %first_char = load i8, i8* %first_char_ptr
    %first_int = zext i8 %first_char to i32
    %is_hash = icmp eq i32 %first_int, 35
    
    %token_type = select i1 %is_hash, i32 4, i32 1  ; TOKEN_SYMBOL or TOKEN_IDENTIFIER
    
    ; Copy value
    %value = call i8* @malloc(i64 %len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %value, i8* %first_char_ptr, i64 %len, i1 false)
    
    ; Set token fields
    %type_ptr = getelementptr %Token, %Token* %token_ptr, i32 0, i32 0
    store i32 %token_type, i32* %type_ptr
    
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
    %pos = load i64, i64* %buffer_pos
    %char_ptr = getelementptr i8, i8* %buffer, i64 %pos
    
    ; Simple escape handling (just copy the next char for now)
    store i8 %next_char, i8* %char_ptr
    %new_pos = add i64 %pos, 1
    store i64 %new_pos, i64* %buffer_pos
    
    call void @lex_advance(%Lexer* %lexer)
    br label %loop

normal_char:
    %pos = load i64, i64* %buffer_pos
    %char_ptr = getelementptr i8, i8* %buffer, i64 %pos
    store i8 %char, i8* %char_ptr
    %new_pos = add i64 %pos, 1
    store i64 %new_pos, i64* %buffer_pos
    
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

; Skip comment
; lex_skip_comment: Skip a line comment (semicolon to newline)
; Parameters:
;   lexer: Pointer to Lexer structure
define void @lex_skip_comment(%Lexer* %lexer) {
entry:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %char_int = zext i8 %char to i32
    %is_eof = call i32 @lex_is_eof(%Lexer* %lexer)
    %is_newline = icmp eq i32 %char_int, 10
    
    %eof_bool = icmp ne i32 %is_eof, 0
    %done = or i1 %eof_bool, %is_newline
    
    br i1 %done, label %exit, label %continue

continue:
    call void @lex_advance(%Lexer* %lexer)
    br label %entry

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
    %type_ptr = getelementptr %Token, %Token* %eof_token_ptr, i32 0, i32 0
    store i32 0, i32* %type_ptr  ; TOKEN_EOF
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
    br i1 %is_dquote, label %string, label %check_lparen

string:
    %str_token = call %Token* @lex_read_string(%Lexer* %lexer)
    ret %Token* %str_token

check_lparen:
    %is_lparen = icmp eq i32 %char_int, 40
    br i1 %is_lparen, label %lparen, label %check_rparen

lparen:
    %lparen_token = call i8* @malloc(i64 32)
    %lparen_token_ptr = bitcast i8* %lparen_token to %Token*
    %type_ptr = getelementptr %Token, %Token* %lparen_token_ptr, i32 0, i32 0
    store i32 5, i32* %type_ptr  ; TOKEN_LPAREN
    call void @lex_advance(%Lexer* %lexer)
    ret %Token* %lparen_token_ptr

check_rparen:
    %is_rparen = icmp eq i32 %char_int, 41
    br i1 %is_rparen, label %rparen, label %check_quote_char

rparen:
    %rparen_token = call i8* @malloc(i64 32)
    %rparen_token_ptr = bitcast i8* %rparen_token to %Token*
    %type_ptr = getelementptr %Token, %Token* %rparen_token_ptr, i32 0, i32 0
    store i32 6, i32* %type_ptr  ; TOKEN_RPAREN
    call void @lex_advance(%Lexer* %lexer)
    ret %Token* %rparen_token_ptr

check_quote_char:
    %is_quote = icmp eq i32 %char_int, 39
    br i1 %is_quote, label %quote, label %identifier

quote:
    %quote_token = call i8* @malloc(i64 32)
    %quote_token_ptr = bitcast i8* %quote_token to %Token*
    %type_ptr = getelementptr %Token, %Token* %quote_token_ptr, i32 0, i32 0
    store i32 7, i32* %type_ptr  ; TOKEN_QUOTE
    call void @lex_advance(%Lexer* %lexer)
    ret %Token* %quote_token_ptr

identifier:
    %start_pos_ptr = getelementptr %Lexer, %Lexer* %lexer, i32 0, i32 2
    %start_pos = load i64, i64* %start_pos_ptr
    
    br label %read_loop

read_loop:
    %char = call i8 @lex_current_char(%Lexer* %lexer)
    %is_delim = call i32 @lex_is_delimiter(i8 %char)
    %delim_bool = icmp ne i32 %is_delim, 0
    br i1 %delim_bool, label %done_id, label %continue_id

continue_id:
    call void @lex_advance(%Lexer* %lexer)
    br label %read_loop

done_id:
    %id_token = call %Token* @lex_read_identifier(%Lexer* %lexer, i64 %start_pos, i64 0)
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

; Declare external functions
declare i8* @malloc(i64)
declare void @free(i8*)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
