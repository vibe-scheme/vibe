; ModuleID = 'scheme_parser'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Token type from lexer
%token_type = type {
  i32,    ; token_kind
  i8*,    ; token_value
  i64     ; token_length
}

; AST node types
%ast_node = type {
  i32,    ; node_type
  i8*,    ; value
  i64,    ; value_length
  %ast_node**,  ; children
  i64     ; num_children
}

; Node types
@NODE_NIL      = constant i32 0
@NODE_SYMBOL   = constant i32 1
@NODE_NUMBER   = constant i32 2
@NODE_STRING   = constant i32 3
@NODE_LIST     = constant i32 4
@NODE_QUOTE    = constant i32 5
@NODE_QUASIQUOTE = constant i32 6
@NODE_UNQUOTE  = constant i32 7

; Function to create a new AST node
define private %ast_node* @create_ast_node(i32 %type, i8* %value, i64 %value_len) {
entry:
  %node = alloca %ast_node
  %type_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 0
  store i32 %type, i32* %type_ptr
  %value_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 1
  store i8* %value, i8** %value_ptr
  %len_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 2
  store i64 %value_len, i64* %len_ptr
  %children_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 3
  store %ast_node** null, %ast_node*** %children_ptr
  %num_children_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 4
  store i64 0, i64* %num_children_ptr
  ret %ast_node* %node
}

; Function to add a child to an AST node
define private void @add_child(%ast_node* %parent, %ast_node* %child) {
entry:
  %num_children_ptr = getelementptr %ast_node, %ast_node* %parent, i32 0, i32 4
  %num_children = load i64, i64* %num_children_ptr
  %new_num_children = add i64 %num_children, 1
  
  ; Allocate or reallocate children array
  %children_ptr = getelementptr %ast_node, %ast_node* %parent, i32 0, i32 3
  %children = load %ast_node**, %ast_node*** %children_ptr
  %is_null = icmp eq %ast_node** %children, null
  br i1 %is_null, label %allocate, label %reallocate

allocate:
  %new_children = call i8* @malloc(i64 8)  ; sizeof(ast_node*)
  %typed_children = bitcast i8* %new_children to %ast_node**
  store %ast_node** %typed_children, %ast_node*** %children_ptr
  br label %store_child

reallocate:
  %new_size = mul i64 %new_num_children, 8  ; sizeof(ast_node*)
  %resized = call i8* @realloc(i8* %children, i64 %new_size)
  %typed_resized = bitcast i8* %resized to %ast_node**
  store %ast_node** %typed_resized, %ast_node*** %children_ptr
  br label %store_child

store_child:
  %final_children = load %ast_node**, %ast_node*** %children_ptr
  %child_slot = getelementptr %ast_node*, %ast_node** %final_children, i64 %num_children
  store %ast_node* %child, %ast_node** %child_slot
  store i64 %new_num_children, i64* %num_children_ptr
  ret void
}

; Function to parse an expression
define %ast_node* @parse_expr() {
entry:
  %token = call %token_type* @get_next_token()
  %token_kind = getelementptr %token_type, %token_type* %token, i32 0, i32 0
  %kind = load i32, i32* %token_kind
  
  switch i32 %kind, label %parse_error [
    i32 0, label %return_nil        ; EOF
    i32 1, label %parse_list        ; (
    i32 2, label %parse_error       ; ) unexpected
    i32 3, label %parse_symbol      ; identifier
    i32 4, label %parse_number      ; number
    i32 5, label %parse_string      ; string
    i32 6, label %parse_quote       ; quote
    i32 7, label %parse_quasiquote  ; backquote
    i32 8, label %parse_unquote     ; comma
  ]

return_nil:
  %nil = call %ast_node* @create_ast_node(i32 0, i8* null, i64 0)
  ret %ast_node* %nil

parse_list:
  %list = call %ast_node* @create_ast_node(i32 4, i8* null, i64 0)
  br label %list_loop

list_loop:
  %next = call %token_type* @get_next_token()
  %next_kind = getelementptr %token_type, %token_type* %next, i32 0, i32 0
  %kind_val = load i32, i32* %next_kind
  %is_rparen = icmp eq i32 %kind_val, 2  ; )
  br i1 %is_rparen, label %end_list, label %continue_list

continue_list:
  %element = call %ast_node* @parse_expr()
  call void @add_child(%ast_node* %list, %ast_node* %element)
  br label %list_loop

end_list:
  ret %ast_node* %list

parse_symbol:
  %sym_val_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 1
  %sym_val = load i8*, i8** %sym_val_ptr
  %sym_len_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 2
  %sym_len = load i64, i64* %sym_len_ptr
  %symbol = call %ast_node* @create_ast_node(i32 1, i8* %sym_val, i64 %sym_len)
  ret %ast_node* %symbol

parse_number:
  %num_val_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 1
  %num_val = load i8*, i8** %num_val_ptr
  %num_len_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 2
  %num_len = load i64, i64* %num_len_ptr
  %number = call %ast_node* @create_ast_node(i32 2, i8* %num_val, i64 %num_len)
  ret %ast_node* %number

parse_string:
  %str_val_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 1
  %str_val = load i8*, i8** %str_val_ptr
  %str_len_ptr = getelementptr %token_type, %token_type* %token, i32 0, i32 2
  %str_len = load i64, i64* %str_len_ptr
  %string = call %ast_node* @create_ast_node(i32 3, i8* %str_val, i64 %str_len)
  ret %ast_node* %string

parse_quote:
  %quoted_expr = call %ast_node* @parse_expr()
  %quote_node = call %ast_node* @create_ast_node(i32 5, i8* null, i64 0)
  call void @add_child(%ast_node* %quote_node, %ast_node* %quoted_expr)
  ret %ast_node* %quote_node

parse_quasiquote:
  %qq_expr = call %ast_node* @parse_expr()
  %qq_node = call %ast_node* @create_ast_node(i32 6, i8* null, i64 0)
  call void @add_child(%ast_node* %qq_node, %ast_node* %qq_expr)
  ret %ast_node* %qq_node

parse_unquote:
  %uq_expr = call %ast_node* @parse_expr()
  %uq_node = call %ast_node* @create_ast_node(i32 7, i8* null, i64 0)
  call void @add_child(%ast_node* %uq_node, %ast_node* %uq_expr)
  ret %ast_node* %uq_node

parse_error:
  ; TODO: Implement error handling
  ret %ast_node* null
}

; External functions
declare i8* @malloc(i64)
declare i8* @realloc(i8*, i64)
declare void @free(i8*)
declare %token_type* @get_next_token() 