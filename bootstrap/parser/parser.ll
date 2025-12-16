; Bootstrap Parser for Vibe
; Parses S-expressions from token stream
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%Token = type { i32, i8*, i64, i32, i32 }
%Lexer = type { i8*, i64, i64, i32, i32 }

declare %Token* @lex_next(%Lexer*)
declare %Token* @lex_peek(%Lexer*)

; AST node types enum
; AST_ATOM = 0
; AST_LIST = 1
; AST_QUOTE = 2
; AST_QUASIQUOTE = 3
; AST_UNQUOTE = 4
; AST_UNQUOTE_SPLICING = 5
; AST_DEFINE_BITCODE_TYPE = 6
; AST_DEFINE_BITCODE_CONSTANT = 7
; AST_DEFINE_BITCODE_FUNCTION = 8

; Forward declarations from types.ll (continued)
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }
%Parser = type { %Lexer*, %Token* }

; Initialize parser with lexer
; parse_init: Initialize a parser with a lexer
; Parameters:
;   lexer: Pointer to Lexer structure
; Returns: Pointer to initialized Parser structure
define %Parser* @parse_init(%Lexer* %lexer) {
entry:
    %parser = call i8* @malloc(i64 16)
    %parser_ptr = bitcast i8* %parser to %Parser*
    
    ; Store lexer
    %lexer_ptr = getelementptr %Parser, %Parser* %parser_ptr, i32 0, i32 0
    store %Lexer* %lexer, %Lexer** %lexer_ptr
    
    ; Get first token
    %first_token = call %Token* @lex_next(%Lexer* %lexer)
    %token_ptr = getelementptr %Parser, %Parser* %parser_ptr, i32 0, i32 1
    store %Token* %first_token, %Token** %token_ptr
    
    ret %Parser* %parser_ptr
}

; Advance to next token
; parse_advance: Advance parser to next token
; Parameters:
;   parser: Pointer to Parser structure
define void @parse_advance(%Parser* %parser) {
entry:
    %lexer_ptr = getelementptr %Parser, %Parser* %parser, i32 0, i32 0
    %lexer = load %Lexer*, %Lexer** %lexer_ptr
    
    %next_token = call %Token* @lex_next(%Lexer* %lexer)
    %token_ptr = getelementptr %Parser, %Parser* %parser, i32 0, i32 1
    store %Token* %next_token, %Token** %token_ptr
    
    ret void
}

; Get current token
; parse_current: Get current token
; Parameters:
;   parser: Pointer to Parser structure
; Returns: Pointer to current Token
define %Token* @parse_current(%Parser* %parser) {
entry:
    %token_ptr = getelementptr %Parser, %Parser* %parser, i32 0, i32 1
    %token = load %Token*, %Token** %token_ptr
    ret %Token* %token
}

; Check if current token matches type
; parse_check: Check if current token matches given type
; Parameters:
;   parser: Pointer to Parser structure
;   token_type: Token type to check
; Returns: 1 if matches, 0 otherwise
define i32 @parse_check(%Parser* %parser, i32 %token_type) {
entry:
    %token = call %Token* @parse_current(%Parser* %parser)
    %type_ptr = getelementptr %Token, %Token* %token, i32 0, i32 0
    %type = load i32, i32* %type_ptr
    %matches = icmp eq i32 %type, %token_type
    %result = zext i1 %matches to i32
    ret i32 %result
}

; Create atom node
; parse_create_atom: Create an AST node for an atom
; Parameters:
;   token: Pointer to Token structure
; Returns: Pointer to ASTNode
define %ASTNode* @parse_create_atom(%Token* %token) {
entry:
    %node = call i8* @malloc(i64 48)
    %node_ptr = bitcast i8* %node to %ASTNode*
    
    %type_ptr = getelementptr %Token, %Token* %token, i32 0, i32 0
    %token_type = load i32, i32* %type_ptr
    
    %node_type_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 0
    store i32 0, i32* %node_type_ptr  ; AST_ATOM
    
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 1
    store i32 %token_type, i32* %atom_type_ptr
    
    %val_ptr = getelementptr %Token, %Token* %token, i32 0, i32 1
    %value = load i8*, i8** %val_ptr
    %node_val_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 2
    store i8* %value, i8** %node_val_ptr
    
    %len_ptr = getelementptr %Token, %Token* %token, i32 0, i32 2
    %len = load i64, i64* %len_ptr
    %node_len_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 3
    store i64 %len, i64* %node_len_ptr
    
    %car_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 4
    store %ASTNode* null, %ASTNode** %car_ptr
    
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %cdr_ptr
    
    %line_ptr = getelementptr %Token, %Token* %token, i32 0, i32 3
    %line = load i32, i32* %line_ptr
    %node_line_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 6
    store i32 %line, i32* %node_line_ptr
    
    %col_ptr = getelementptr %Token, %Token* %token, i32 0, i32 4
    %col = load i32, i32* %col_ptr
    %node_col_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 7
    store i32 %col, i32* %node_col_ptr
    
    ret %ASTNode* %node_ptr
}

; Parse atom
; parse_atom: Parse an atomic value
; Parameters:
;   parser: Pointer to Parser structure
; Returns: Pointer to ASTNode
define %ASTNode* @parse_atom(%Parser* %parser) {
entry:
    %token = call %Token* @parse_current(%Parser* %parser)
    %node = call %ASTNode* @parse_create_atom(%Token* %token)
    call void @parse_advance(%Parser* %parser)
    ; Debug logging
    call void @parse_debug_log_ast_node(%ASTNode* %node)
    ret %ASTNode* %node
}

; Parse list
; parse_list: Parse a list structure
; Parameters:
;   parser: Pointer to Parser structure
; Returns: Pointer to ASTNode (list)
define %ASTNode* @parse_list(%Parser* %parser) {
entry:
    ; Check for left parenthesis
    %is_lparen = call i32 @parse_check(%Parser* %parser, i32 5)  ; TOKEN_LPAREN
    %lparen_bool = icmp eq i32 %is_lparen, 0
    br i1 %lparen_bool, label %error, label %parse_start

parse_start:
    call void @parse_advance(%Parser* %parser)  ; Consume LPAREN
    
    ; Create list node
    %list_node = call i8* @malloc(i64 48)
    %list_node_ptr = bitcast i8* %list_node to %ASTNode*
    
    %node_type_ptr = getelementptr %ASTNode, %ASTNode* %list_node_ptr, i32 0, i32 0
    store i32 1, i32* %node_type_ptr  ; AST_LIST
    
    ; Check for empty list or dot notation
    %is_rparen = call i32 @parse_check(%Parser* %parser, i32 6)  ; TOKEN_RPAREN
    %rparen_bool = icmp ne i32 %is_rparen, 0
    br i1 %rparen_bool, label %empty_list, label %parse_elements

empty_list:
    call void @parse_advance(%Parser* %parser)  ; Consume RPAREN
    %car_ptr_empty = getelementptr %ASTNode, %ASTNode* %list_node_ptr, i32 0, i32 4
    store %ASTNode* null, %ASTNode** %car_ptr_empty
    %cdr_ptr_empty = getelementptr %ASTNode, %ASTNode* %list_node_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %cdr_ptr_empty
    ret %ASTNode* %list_node_ptr

parse_elements:
    ; Parse first element
    %first = call %ASTNode* @parse_expr(%Parser* %parser)
    %car_ptr_elements = getelementptr %ASTNode, %ASTNode* %list_node_ptr, i32 0, i32 4
    store %ASTNode* %first, %ASTNode** %car_ptr_elements
    
    ; Check for dot notation (improper list)
    %is_dot = call i32 @parse_check(%Parser* %parser, i32 11)  ; TOKEN_DOT
    %dot_bool = icmp ne i32 %is_dot, 0
    br i1 %dot_bool, label %dot_notation, label %parse_rest

dot_notation:
    call void @parse_advance(%Parser* %parser)  ; Consume DOT
    %cdr_expr = call %ASTNode* @parse_expr(%Parser* %parser)
    %cdr_ptr_dot = getelementptr %ASTNode, %ASTNode* %list_node_ptr, i32 0, i32 5
    store %ASTNode* %cdr_expr, %ASTNode** %cdr_ptr_dot
    
    ; Expect right parenthesis
    %is_rparen2 = call i32 @parse_check(%Parser* %parser, i32 6)  ; TOKEN_RPAREN
    %rparen_bool2 = icmp eq i32 %is_rparen2, 0
    br i1 %rparen_bool2, label %error, label %done_dot

done_dot:
    call void @parse_advance(%Parser* %parser)  ; Consume RPAREN
    ret %ASTNode* %list_node_ptr

parse_rest:
    ; Parse rest of list
    %rest = call %ASTNode* @parse_list_tail(%Parser* %parser)
    %cdr_ptr_rest = getelementptr %ASTNode, %ASTNode* %list_node_ptr, i32 0, i32 5
    store %ASTNode* %rest, %ASTNode** %cdr_ptr_rest
    ret %ASTNode* %list_node_ptr

error:
    ret %ASTNode* null
}

; Parse list tail (helper for parse_list)
; parse_list_tail: Parse the tail of a list
; Parameters:
;   parser: Pointer to Parser structure
; Returns: Pointer to ASTNode (rest of list)
define %ASTNode* @parse_list_tail(%Parser* %parser) {
entry:
    %is_rparen = call i32 @parse_check(%Parser* %parser, i32 6)  ; TOKEN_RPAREN
    %rparen_bool = icmp ne i32 %is_rparen, 0
    br i1 %rparen_bool, label %empty, label %has_elements

empty:
    call void @parse_advance(%Parser* %parser)  ; Consume RPAREN
    ret %ASTNode* null

has_elements:
    ; Create cons cell
    %cons_node = call i8* @malloc(i64 48)
    %cons_node_ptr = bitcast i8* %cons_node to %ASTNode*
    
    %node_type_ptr = getelementptr %ASTNode, %ASTNode* %cons_node_ptr, i32 0, i32 0
    store i32 1, i32* %node_type_ptr  ; AST_LIST
    
    ; Parse car
    %car = call %ASTNode* @parse_expr(%Parser* %parser)
    %car_ptr = getelementptr %ASTNode, %ASTNode* %cons_node_ptr, i32 0, i32 4
    store %ASTNode* %car, %ASTNode** %car_ptr
    
    ; Parse cdr recursively
    %cdr = call %ASTNode* @parse_list_tail(%Parser* %parser)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %cons_node_ptr, i32 0, i32 5
    store %ASTNode* %cdr, %ASTNode** %cdr_ptr
    
    ret %ASTNode* %cons_node_ptr
}

; Parse expression (atom or list)
; parse_expr: Parse a single expression (atom or list)
; Parameters:
;   parser: Pointer to Parser structure
; Returns: Pointer to ASTNode
define %ASTNode* @parse_expr(%Parser* %parser) {
entry:
    %token = call %Token* @parse_current(%Parser* %parser)
    %type_ptr = getelementptr %Token, %Token* %token, i32 0, i32 0
    %token_type = load i32, i32* %type_ptr
    
    ; Check for quote
    %is_quote = icmp eq i32 %token_type, 7  ; TOKEN_QUOTE
    br i1 %is_quote, label %quote, label %check_quasiquote

quote:
    call void @parse_advance(%Parser* %parser)  ; Consume quote
    %quoted = call %ASTNode* @parse_expr(%Parser* %parser)
    
    ; Create quote node
    %quote_node = call i8* @malloc(i64 48)
    %quote_node_ptr = bitcast i8* %quote_node to %ASTNode*
    
    %node_type_ptr = getelementptr %ASTNode, %ASTNode* %quote_node_ptr, i32 0, i32 0
    store i32 2, i32* %node_type_ptr  ; AST_QUOTE
    
    %car_ptr = getelementptr %ASTNode, %ASTNode* %quote_node_ptr, i32 0, i32 4
    store %ASTNode* %quoted, %ASTNode** %car_ptr
    
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %quote_node_ptr, i32 0, i32 5
    store %ASTNode* null, %ASTNode** %cdr_ptr
    
    ret %ASTNode* %quote_node_ptr

check_quasiquote:
    ; Check for left parenthesis (list)
    %is_lparen = icmp eq i32 %token_type, 5  ; TOKEN_LPAREN
    br i1 %is_lparen, label %list, label %atom

list:
    %list_node = call %ASTNode* @parse_list(%Parser* %parser)
    ; Debug logging - check if this is define-llvm-function
    call void @parse_debug_check_define_llvm_function(%ASTNode* %list_node)
    ret %ASTNode* %list_node

atom:
    %atom_node = call %ASTNode* @parse_atom(%Parser* %parser)
    ret %ASTNode* %atom_node
}

; Report parsing error
; parse_error: Report a parsing error
; Parameters:
;   parser: Pointer to Parser structure
;   message: Error message string
; Returns: Null pointer (error indicator)
define %ASTNode* @parse_error(%Parser* %parser, i8* %message) {
entry:
    ; In a real implementation, this would print the error message
    ; For now, just return null
    ret %ASTNode* null
}

; Debug logging helpers
; parse_debug_log_ast_node: Print AST node information
; Parameters:
;   node: Pointer to ASTNode
define void @parse_debug_log_ast_node(%ASTNode* %node) {
entry:
    %node_null = icmp eq %ASTNode* %node, null
    br i1 %node_null, label %done, label %log_node
    
log_node:
    %type_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 0
    %type = load i32, i32* %type_ptr
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.debug_prefix_parser, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_ast_node_fmt, i32 0, i32 0), i32 %type, i32 %atom_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %done
    
done:
    ret void
}

; parse_debug_check_define_llvm_function: Check if list is define-llvm-function and log
; Parameters:
;   node: Pointer to ASTNode (should be a list)
define void @parse_debug_check_define_llvm_function(%ASTNode* %node) {
entry:
    %node_null = icmp eq %ASTNode* %node, null
    br i1 %node_null, label %done, label %check_list
    
check_list:
    %type_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 0
    %type = load i32, i32* %type_ptr
    %is_list = icmp eq i32 %type, 1  ; AST_LIST
    br i1 %is_list, label %check_car, label %done
    
check_car:
    %car_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 4
    %car = load %ASTNode*, %ASTNode** %car_ptr
    %car_null = icmp eq %ASTNode* %car, null
    br i1 %car_null, label %done, label %check_atom
    
check_atom:
    %car_type_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 0
    %car_type = load i32, i32* %car_type_ptr
    %is_atom = icmp eq i32 %car_type, 0  ; AST_ATOM
    br i1 %is_atom, label %check_name, label %done
    
check_name:
    %car_val_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 2
    %car_val = load i8*, i8** %car_val_ptr
    %car_len_ptr = getelementptr %ASTNode, %ASTNode* %car, i32 0, i32 3
    %car_len = load i64, i64* %car_len_ptr
    
    ; Check if name matches "define-llvm-function" (length 22)
    %len_match = icmp eq i64 %car_len, 22
    br i1 %len_match, label %compare_name, label %done
    
compare_name:
    ; Simple check - just print if it might be define-llvm-function
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.debug_prefix_parser, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([33 x i8], [33 x i8]* @.str.debug_define_llvm_function, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %done
    
done:
    ret void
}

; String literals for debug logging
@.str.debug_prefix_parser = private unnamed_addr constant [10 x i8] c"[PARSER] \00"
@.str.debug_ast_node_fmt = private unnamed_addr constant [30 x i8] c"AST node type=%d atom_type=%d\00"
@.str.debug_newline = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str.debug_define_llvm_function = private unnamed_addr constant [34 x i8] c"Parsing define-llvm-function form\00"
@.str.empty = private unnamed_addr constant [1 x i8] c"\00"

; Declare external functions
declare i8* @malloc(i64)
declare void @free(i8*)
declare i32 @printf(i8*, ...)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
