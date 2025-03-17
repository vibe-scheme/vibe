; ModuleID = 'scheme_lexer'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Token type enumeration
%token_type = type {
  i32,    ; token_kind
  i8*,    ; token_value
  i64     ; token_length
}

; Token kinds
@TOK_EOF        = constant i32 0
@TOK_LPAREN    = constant i32 1
@TOK_RPAREN    = constant i32 2
@TOK_IDENT     = constant i32 3
@TOK_NUMBER    = constant i32 4
@TOK_STRING    = constant i32 5
@TOK_QUOTE     = constant i32 6
@TOK_BACKQUOTE = constant i32 7
@TOK_COMMA     = constant i32 8
@TOK_ERROR     = constant i32 9

; Global state
@current_char = global i8 0
@input_buffer = global [4096 x i8] zeroinitializer
@buffer_pos = global i64 0
@buffer_size = global i64 0

; Function to read a character from input
define private i8 @read_char() {
entry:
  %pos = load i64, i64* @buffer_pos
  %size = load i64, i64* @buffer_size
  %cmp = icmp uge i64 %pos, %size
  br i1 %cmp, label %refill, label %read

refill:
  ; Read from stdin into buffer
  %buf_ptr = getelementptr [4096 x i8], [4096 x i8]* @input_buffer, i64 0, i64 0
  %read_size = call i64 @read(i32 0, i8* %buf_ptr, i64 4096)
  store i64 %read_size, i64* @buffer_size
  store i64 0, i64* @buffer_pos
  %eof = icmp eq i64 %read_size, 0
  br i1 %eof, label %return_eof, label %read

read:
  %cur_pos = load i64, i64* @buffer_pos
  %ptr = getelementptr [4096 x i8], [4096 x i8]* @input_buffer, i64 0, i64 %cur_pos
  %char = load i8, i8* %ptr
  %next_pos = add i64 %cur_pos, 1
  store i64 %next_pos, i64* @buffer_pos
  ret i8 %char

return_eof:
  ret i8 0
}

; Function to create a new token
define private %token_type* @create_token(i32 %kind, i8* %value, i64 %length) {
entry:
  %token = alloca %token_type
  %kind_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 0
  store i32 %kind, i32* %kind_ptr
  %value_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 1
  store i8* %value, i8** %value_ptr
  %length_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 2
  store i64 %length, i64* %length_ptr
  ret %token_type* %token
}

; Function to get next token
define %token_type* @get_next_token() {
entry:
  %char = call i8 @read_char()
  store i8 %char, i8* @current_char

  ; Skip whitespace
  br label %skip_whitespace

skip_whitespace:
  %cur_char = load i8, i8* @current_char
  %is_space = call i1 @is_whitespace(i8 %cur_char)
  br i1 %is_space, label %next_char, label %check_token

next_char:
  %next = call i8 @read_char()
  store i8 %next, i8* @current_char
  br label %skip_whitespace

check_token:
  %token_char = load i8, i8* @current_char
  switch i8 %token_char, label %check_identifier [
    i8 0, label %return_eof
    i8 40, label %return_lparen    ; (
    i8 41, label %return_rparen    ; )
    i8 39, label %return_quote     ; '
    i8 96, label %return_backquote ; `
    i8 44, label %return_comma     ; ,
    i8 34, label %read_string      ; "
  ]

return_eof:
  %eof_token = call %token_type* @create_token(i32 0, i8* null, i64 0)
  ret %token_type* %eof_token

return_lparen:
  %lparen_token = call %token_type* @create_token(i32 1, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i64 0, i64 0), i64 1)
  ret %token_type* %lparen_token

return_rparen:
  %rparen_token = call %token_type* @create_token(i32 2, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rparen, i64 0, i64 0), i64 1)
  ret %token_type* %rparen_token

return_quote:
  %quote_token = call %token_type* @create_token(i32 6, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.quote, i64 0, i64 0), i64 1)
  ret %token_type* %quote_token

return_backquote:
  %backquote_token = call %token_type* @create_token(i32 7, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.backquote, i64 0, i64 0), i64 1)
  ret %token_type* %backquote_token

return_comma:
  %comma_token = call %token_type* @create_token(i32 8, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.comma, i64 0, i64 0), i64 1)
  ret %token_type* %comma_token

check_identifier:
  ; TODO: Implement identifier lexing
  ret %token_type* null

read_string:
  ; TODO: Implement string lexing
  ret %token_type* null
}

; Helper function to check if character is whitespace
define private i1 @is_whitespace(i8 %char) {
entry:
  %is_space = icmp eq i8 %char, 32    ; space
  %is_tab = icmp eq i8 %char, 9       ; tab
  %is_newline = icmp eq i8 %char, 10  ; newline
  %is_return = icmp eq i8 %char, 13   ; carriage return
  
  %or1 = or i1 %is_space, %is_tab
  %or2 = or i1 %or1, %is_newline
  %or3 = or i1 %or2, %is_return
  
  ret i1 %or3
}

; External functions
declare i64 @read(i32, i8*, i64)

; String constants
@.str.lparen = private unnamed_addr constant [2 x i8] c"(\00"
@.str.rparen = private unnamed_addr constant [2 x i8] c")\00"
@.str.quote = private unnamed_addr constant [2 x i8] c"'\00"
@.str.backquote = private unnamed_addr constant [2 x i8] c"`\00"
@.str.comma = private unnamed_addr constant [2 x i8] c",\00" 