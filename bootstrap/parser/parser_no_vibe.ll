; Bootstrap Parser - Un-migrated functions
; These functions require llvm:insertvalue/extractvalue/undef DSL methods
; which are not yet implemented. They will be migrated to parser.vibe
; once those DSL methods are added.

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

; Forward declarations from types.ll
%Token = type { i32, i8*, i64, i32, i32 }
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }

; External function declarations
declare i8* @malloc(i64)
declare void @free(i8*)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

; Normalize type atom value (strip % prefix for named types)
; parse_normalize_type_atom: Normalize type atom value
; Parameters:
;   value: Pointer to token value string
;   len: Length of token value
; Returns: Pointer to normalized value (newly allocated if changed, original if unchanged), normalized length
; Note: This function normalizes type syntax:
;   - Strips % prefix from named types: "%Token" -> "Token"
;   - Keeps pointer indicators (*) as-is
;   - Vertical bars are already stripped by lexer, so we don't handle them here
define { i8*, i64 } @parse_normalize_type_atom(i8* %value, i64 %len) {
entry:
    %value_null = icmp eq i8* %value, null
    %len_zero = icmp eq i64 %len, 0
    %invalid = or i1 %value_null, %len_zero
    br i1 %invalid, label %return_original, label %check_percent
    
check_percent:
    ; Check if value starts with '%' (named type)
    %first_char = load i8, i8* %value
    %is_percent = icmp eq i8 %first_char, 37  ; '%' = 37
    br i1 %is_percent, label %strip_percent, label %return_original
    
strip_percent:
    ; Strip '%' prefix: create new string without first character
    %new_len = sub i64 %len, 1
    %new_value = call i8* @malloc(i64 %new_len)
    %value_plus1 = getelementptr i8, i8* %value, i64 1
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %new_value, i8* %value_plus1, i64 %new_len, i1 false)
    %result = insertvalue { i8*, i64 } undef, i8* %new_value, 0
    %result_with_len = insertvalue { i8*, i64 } %result, i64 %new_len, 1
    ret { i8*, i64 } %result_with_len
    
return_original:
    ; Return original value (no normalization needed)
    %result_orig = insertvalue { i8*, i64 } undef, i8* %value, 0
    %result_orig_with_len = insertvalue { i8*, i64 } %result_orig, i64 %len, 1
    ret { i8*, i64 } %result_orig_with_len
}

; Create atom node
; parse_create_atom: Create an AST node for an atom
; Parameters:
;   token: Pointer to Token structure
; Returns: Pointer to ASTNode
; Note: Normalizes type syntax (strips % prefix from named types)
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
    %len_ptr = getelementptr %Token, %Token* %token, i32 0, i32 2
    %len = load i64, i64* %len_ptr
    
    ; Normalize type syntax (strip % prefix if present)
    %normalized = call { i8*, i64 } @parse_normalize_type_atom(i8* %value, i64 %len)
    %normalized_value = extractvalue { i8*, i64 } %normalized, 0
    %normalized_len = extractvalue { i8*, i64 } %normalized, 1
    
    ; Always copy the normalized value to ensure it's isolated and null-terminated
    ; This prevents reading past token boundaries when tokens are adjacent in source
    %copied_value_size = add i64 %normalized_len, 1  ; +1 for null terminator
    %copied_value = call i8* @malloc(i64 %copied_value_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %copied_value, i8* %normalized_value, i64 %normalized_len, i1 false)
    %null_term_ptr = getelementptr i8, i8* %copied_value, i64 %normalized_len
    store i8 0, i8* %null_term_ptr
    
    ; Free the normalized value if it was newly allocated (if it's different from original)
    %value_changed = icmp ne i8* %normalized_value, %value
    br i1 %value_changed, label %free_normalized, label %store_copied
    
free_normalized:
    call void @free(i8* %normalized_value)
    br label %store_copied
    
store_copied:
    %node_val_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 2
    store i8* %copied_value, i8** %node_val_ptr
    
    %node_len_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 3
    store i64 %normalized_len, i64* %node_len_ptr
    
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
