; ModuleID = 'vibe_runtime'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Basic value type that can hold any Vibe value
%value = type {
  i32,  ; type tag
  i8*   ; value pointer
}

; Value type tags
@TAG_NIL = constant i32 0
@TAG_NUMBER = constant i32 1
@TAG_SYMBOL = constant i32 2
@TAG_FUNCTION = constant i32 3
@TAG_LIST = constant i32 4

; List node type for representing Vibe lists
%list = type {
  %value,    ; head (car)
  %list*     ; tail (cdr)
}

; Symbol table entry type
%symbol_entry = type {
  i8*,            ; symbol name
  i64,            ; name length
  %value,         ; bound value
  %symbol_entry*  ; next in chain
}

; Global symbol table (256 buckets)
@symbol_table = global [256 x %symbol_entry*] zeroinitializer

; Create a new value
define %value @create_value(i32 %tag, i8* %ptr) {
  %val = insertvalue %value undef, i32 %tag, 0
  %val2 = insertvalue %value %val, i8* %ptr, 1
  ret %value %val2
}

; Get value type tag
define i32 @get_type(%value %val) {
  %tag = extractvalue %value %val, 0
  ret i32 %tag
}

; Get value pointer
define i8* @get_value_ptr(%value %val) {
  %ptr = extractvalue %value %val, 1
  ret i8* %ptr
}

; Create a new list node
define %list* @create_list_node(%value %head, %list* %tail) {
  %size = call i8* @GC_malloc(i64 ptrtoint (%list* getelementptr (%list, %list* null, i32 1) to i64))
  %node = bitcast i8* %size to %list*
  
  ; Store head
  %head_ptr = getelementptr %list, %list* %node, i32 0, i32 0
  store %value %head, %value* %head_ptr
  
  ; Store tail
  %tail_ptr = getelementptr %list, %list* %node, i32 0, i32 1
  store %list* %tail, %list** %tail_ptr
  
  ret %list* %node
}

; Get list head (car)
define %value @car(%list* %lst) {
  %head_ptr = getelementptr %list, %list* %lst, i32 0, i32 0
  %head = load %value, %value* %head_ptr
  ret %value %head
}

; Get list tail (cdr)
define %list* @cdr(%list* %lst) {
  %tail_ptr = getelementptr %list, %list* %lst, i32 0, i32 1
  %tail = load %list*, %list** %tail_ptr
  ret %list* %tail
}

; Copy a string
define private void @string_copy(i8* %dst, i8* %src, i64 %len) {
  %i = alloca i64
  store i64 0, i64* %i
  br label %loop

loop:
  %idx = load i64, i64* %i
  %continue = icmp ult i64 %idx, %len
  br i1 %continue, label %copy_char, label %done

copy_char:
  %src_ptr = getelementptr i8, i8* %src, i64 %idx
  %char = load i8, i8* %src_ptr
  %dst_ptr = getelementptr i8, i8* %dst, i64 %idx
  store i8 %char, i8* %dst_ptr
  %next_i = add i64 %idx, 1
  store i64 %next_i, i64* %i
  br label %loop

done:
  ret void
}

; Hash function for symbol table
define private i64 @hash_symbol(i8* %name, i64 %len) {
  %hash = alloca i64
  store i64 5381, i64* %hash
  %i = alloca i64
  store i64 0, i64* %i
  br label %loop

loop:
  %idx = load i64, i64* %i
  %continue = icmp ult i64 %idx, %len
  br i1 %continue, label %hash_char, label %done

hash_char:
  %cur_hash = load i64, i64* %hash
  %shifted = shl i64 %cur_hash, 5
  %added = add i64 %shifted, %cur_hash
  %char_ptr = getelementptr i8, i8* %name, i64 %idx
  %char = load i8, i8* %char_ptr
  %char_ext = zext i8 %char to i64
  %new_hash = add i64 %added, %char_ext
  store i64 %new_hash, i64* %hash
  %next_i = add i64 %idx, 1
  store i64 %next_i, i64* %i
  br label %loop

done:
  %final_hash = load i64, i64* %hash
  %bucket = urem i64 %final_hash, 256
  ret i64 %bucket
}

; Look up a symbol in the symbol table
define %value @lookup_symbol(i8* %name, i64 %len) {
  ; Get hash bucket
  %hash = call i64 @hash_symbol(i8* %name, i64 %len)
  %bucket_ptr = getelementptr [256 x %symbol_entry*], [256 x %symbol_entry*]* @symbol_table, i64 0, i64 %hash
  %entry = load %symbol_entry*, %symbol_entry** %bucket_ptr
  
  ; Search chain
  br label %search

search:
  %cur = phi %symbol_entry* [ %entry, %0 ], [ %next, %continue ]
  %is_null = icmp eq %symbol_entry* %cur, null
  br i1 %is_null, label %not_found, label %check_name

check_name:
  %cur_name = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 0
  %cur_name_ptr = load i8*, i8** %cur_name
  %cur_len = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 1
  %cur_len_val = load i64, i64* %cur_len
  
  ; Compare lengths
  %lens_match = icmp eq i64 %cur_len_val, %len
  br i1 %lens_match, label %compare_names, label %continue

compare_names:
  %names_match = call i1 @string_equal(i8* %cur_name_ptr, i8* %name, i64 %len)
  br i1 %names_match, label %found, label %continue

continue:
  %chain_next_ptr = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 3
  %next = load %symbol_entry*, %symbol_entry** %chain_next_ptr
  br label %search

found:
  %val_ptr = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 2
  %val = load %value, %value* %val_ptr
  ret %value %val

not_found:
  %nil = call %value @create_value(i32 0, i8* null)
  ret %value %nil
}

; Define or update a symbol binding
define void @define_symbol(i8* %name, i64 %len, %value %val) {
  ; Get hash bucket
  %hash = call i64 @hash_symbol(i8* %name, i64 %len)
  %bucket_ptr = getelementptr [256 x %symbol_entry*], [256 x %symbol_entry*]* @symbol_table, i64 0, i64 %hash
  %first = load %symbol_entry*, %symbol_entry** %bucket_ptr
  
  ; Check if symbol already exists
  br label %search

search:
  %cur = phi %symbol_entry* [ %first, %0 ], [ %next, %continue ]
  %is_null = icmp eq %symbol_entry* %cur, null
  br i1 %is_null, label %create_new, label %check_name

check_name:
  %cur_name = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 0
  %cur_name_ptr = load i8*, i8** %cur_name
  %cur_len = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 1
  %cur_len_val = load i64, i64* %cur_len
  
  ; Compare lengths
  %lens_match = icmp eq i64 %cur_len_val, %len
  br i1 %lens_match, label %compare_names, label %continue

compare_names:
  %names_match = call i1 @string_equal(i8* %cur_name_ptr, i8* %name, i64 %len)
  br i1 %names_match, label %update, label %continue

continue:
  %chain_next_ptr = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 3
  %next = load %symbol_entry*, %symbol_entry** %chain_next_ptr
  br label %search

update:
  ; Update existing entry
  %update_val_ptr = getelementptr %symbol_entry, %symbol_entry* %cur, i32 0, i32 2
  store %value %val, %value* %update_val_ptr
  ret void

create_new:
  ; Create new entry
  %entry_size = call i8* @GC_malloc(i64 32)  ; Approximate size
  %entry = bitcast i8* %entry_size to %symbol_entry*
  
  ; Copy symbol name
  %name_copy = call i8* @GC_malloc(i64 %len)
  call void @string_copy(i8* %name_copy, i8* %name, i64 %len)
  
  ; Initialize entry
  %name_ptr = getelementptr %symbol_entry, %symbol_entry* %entry, i32 0, i32 0
  store i8* %name_copy, i8** %name_ptr
  %len_ptr = getelementptr %symbol_entry, %symbol_entry* %entry, i32 0, i32 1
  store i64 %len, i64* %len_ptr
  %new_val_ptr = getelementptr %symbol_entry, %symbol_entry* %entry, i32 0, i32 2
  store %value %val, %value* %new_val_ptr
  %new_next_ptr = getelementptr %symbol_entry, %symbol_entry* %entry, i32 0, i32 3
  store %symbol_entry* %first, %symbol_entry** %new_next_ptr
  
  ; Insert at head of chain
  store %symbol_entry* %entry, %symbol_entry** %bucket_ptr
  ret void
}

; Compare two strings for equality
define private i1 @string_equal(i8* %s1, i8* %s2, i64 %len) {
  %result = call i32 @memcmp(i8* %s1, i8* %s2, i64 %len)
  %match = icmp eq i32 %result, 0
  ret i1 %match
}

; Initialize the runtime
define void @init_runtime() {
  ; Initialize GC
  call void @GC_init()
  ret void
}

; Print a string to stdout
define void @print_string(i8* %str) {
  %len = call i64 @strlen(i8* %str)
  %written = call i64 @write(i32 1, i8* %str, i64 %len)
  ret void
}

; Evaluate a string as Vibe code
define %value @eval_string(%value %str, %list* %env) {
  ; For now, just return nil
  %nil = call %value @create_value(i32 0, i8* null)
  ret %value %nil
}

; External functions
declare void @GC_init()
declare i8* @GC_malloc(i64)
declare i32 @memcmp(i8*, i8*, i64)
declare i64 @strlen(i8*)
declare i64 @write(i32, i8*, i64)
declare i8* @create_lexer(i8*)
declare i8* @create_parser(i8*)
declare %value @parse(i8*)
declare %value @eval(%value, %list*) 