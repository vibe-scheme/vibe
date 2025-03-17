; ModuleID = 'scheme_main'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; AST node type
%ast_node = type {
  i32,    ; node_type
  i8*,    ; value
  i64,    ; value_length
  %ast_node**,  ; children
  i64     ; num_children
}

; External declarations
declare %ast_node* @parse_expr()
declare i32 @printf(i8*, ...)

@.str.prompt = private unnamed_addr constant [3 x i8] c"> \00"
@.str.newline = private unnamed_addr constant [2 x i8] c"\0A\00"

; Main function implementing REPL
define i32 @main() {
entry:
  br label %repl_loop

repl_loop:
  ; Print prompt
  %prompt = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.prompt, i64 0, i64 0))
  
  ; Parse expression
  %ast = call %ast_node* @parse_expr()
  
  ; Check for EOF
  %is_nil = icmp eq %ast_node* %ast, null
  br i1 %is_nil, label %exit, label %print_result
  
print_result:
  ; Print the AST
  call void @print_ast(%ast_node* %ast)
  
  ; Print newline
  %nl = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i64 0, i64 0))
  
  br label %repl_loop
  
exit:
  ret i32 0
}

; Function to print AST nodes (implementation)
define private void @print_ast(%ast_node* %node) {
entry:
  %type_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 0
  %type = load i32, i32* %type_ptr
  
  switch i32 %type, label %print_error [
    i32 0, label %print_nil      ; NIL
    i32 1, label %print_symbol   ; SYMBOL
    i32 2, label %print_number   ; NUMBER
    i32 3, label %print_string   ; STRING
    i32 4, label %print_list     ; LIST
    i32 5, label %print_quote    ; QUOTE
    i32 6, label %print_quasiquote ; QUASIQUOTE
    i32 7, label %print_unquote  ; UNQUOTE
  ]

print_nil:
  %nil_str = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.str.nil, i64 0, i64 0))
  ret void

print_symbol:
  %sym_val = getelementptr %ast_node, %ast_node* %node, i32 0, i32 1
  %sym_ptr = load i8*, i8** %sym_val
  %sym_len = getelementptr %ast_node, %ast_node* %node, i32 0, i32 2
  %sym_len_val = load i64, i64* %sym_len
  call i32 (i8*, ...) @printf(i8* %sym_ptr)
  ret void

print_number:
  %num_val = getelementptr %ast_node, %ast_node* %node, i32 0, i32 1
  %num_ptr = load i8*, i8** %num_val
  call i32 (i8*, ...) @printf(i8* %num_ptr)
  ret void

print_string:
  %str_val = getelementptr %ast_node, %ast_node* %node, i32 0, i32 1
  %str_ptr = load i8*, i8** %str_val
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.quote_char, i64 0, i64 0))
  call i32 (i8*, ...) @printf(i8* %str_ptr)
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.quote_char, i64 0, i64 0))
  ret void

print_list:
  ; Print opening parenthesis
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i64 0, i64 0))
  
  ; Get children array
  %children_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 3
  %children = load %ast_node**, %ast_node*** %children_ptr
  %num_children_ptr = getelementptr %ast_node, %ast_node* %node, i32 0, i32 4
  %num_children = load i64, i64* %num_children_ptr
  
  ; Print each child
  br label %print_children

print_children:
  %i = phi i64 [ 0, %print_list ], [ %next_i, %skip_space ]
  %is_done = icmp eq i64 %i, %num_children
  br i1 %is_done, label %end_list, label %print_child

print_child:
  ; Print space if not first element
  %is_first = icmp eq i64 %i, 0
  br i1 %is_first, label %skip_space, label %print_space

print_space:
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i64 0, i64 0))
  br label %skip_space

skip_space:
  %child_ptr = getelementptr %ast_node*, %ast_node** %children, i64 %i
  %child = load %ast_node*, %ast_node** %child_ptr
  call void @print_ast(%ast_node* %child)
  %next_i = add i64 %i, 1
  br label %print_children

end_list:
  ; Print closing parenthesis
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rparen, i64 0, i64 0))
  ret void

print_quote:
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.quote_char, i64 0, i64 0))
  %quoted = getelementptr %ast_node, %ast_node* %node, i32 0, i32 3
  %quoted_children = load %ast_node**, %ast_node*** %quoted
  %quoted_expr = load %ast_node*, %ast_node** %quoted_children
  call void @print_ast(%ast_node* %quoted_expr)
  ret void

print_quasiquote:
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.backquote, i64 0, i64 0))
  %qq = getelementptr %ast_node, %ast_node* %node, i32 0, i32 3
  %qq_children = load %ast_node**, %ast_node*** %qq
  %qq_expr = load %ast_node*, %ast_node** %qq_children
  call void @print_ast(%ast_node* %qq_expr)
  ret void

print_unquote:
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.comma, i64 0, i64 0))
  %uq = getelementptr %ast_node, %ast_node* %node, i32 0, i32 3
  %uq_children = load %ast_node**, %ast_node*** %uq
  %uq_expr = load %ast_node*, %ast_node** %uq_children
  call void @print_ast(%ast_node* %uq_expr)
  ret void

print_error:
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.error, i64 0, i64 0))
  ret void
}

; String constants for printing
@.str.nil = private unnamed_addr constant [4 x i8] c"nil\00"
@.str.lparen = private unnamed_addr constant [2 x i8] c"(\00"
@.str.rparen = private unnamed_addr constant [2 x i8] c")\00"
@.str.quote_char = private unnamed_addr constant [2 x i8] c"\22\00"
@.str.backquote = private unnamed_addr constant [2 x i8] c"`\00"
@.str.comma = private unnamed_addr constant [2 x i8] c",\00"
@.str.space = private unnamed_addr constant [2 x i8] c" \00"
@.str.error = private unnamed_addr constant [15 x i8] c"<invalid-node>\00" 