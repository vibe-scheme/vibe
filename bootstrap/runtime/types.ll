; ModuleID = 'bootstrap_types'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Basic value type for scheme values
%value = type {
  i32,  ; type tag
  i8*   ; value pointer
}

; Value type tags
@TAG_NIL = constant i32 0
@TAG_SYMBOL = constant i32 1
@TAG_STRING = constant i32 2
@TAG_LIST = constant i32 3
@TAG_FUNCTION = constant i32 4

; List node type
%list = type {
  %value,    ; head (car)
  %list*     ; tail (cdr)
}

; Function type for scheme functions
%function_t = type %value (%list*)*

; Function type for scheme functions with argument info
%function_info = type {
  %value (%list*)*,  ; function pointer
  %list*,           ; argument list
  i64               ; number of arguments
}

; Create a new value
define %value @create_value(i32 %tag, i8* %ptr) {
  %val = insertvalue %value undef, i32 %tag, 0
  %val2 = insertvalue %value %val, i8* %ptr, 1
  ret %value %val2
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

; Create a symbol
define %value @create_symbol(i8* %name, i64 %len) {
  ; Allocate space for name
  %str = call i8* @GC_malloc(i64 %len)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %str, i8* %name, i64 %len, i32 1, i1 false)
  
  ; Create value with symbol tag
  %val = call %value @create_value(i32 1, i8* %str)
  ret %value %val
}

; Create a string
define %value @create_string(i8* %str, i64 %len) {
  ; Allocate space for string
  %new_str = call i8* @GC_malloc(i64 %len)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %new_str, i8* %str, i64 %len, i32 1, i1 false)
  
  ; Create value with string tag
  %val = call %value @create_value(i32 2, i8* %new_str)
  ret %value %val
}

; Create a function value
define %value @create_function(%function_t %func) {
  %func_ptr = bitcast %function_t %func to i8*
  %val = call %value @create_value(i32 4, i8* %func_ptr)
  ret %value %val
}

; Create a new function value with argument info
define %value @create_function_with_args(%function_t %func, %list* %args, i64 %num_args) {
  ; Allocate function info
  %info = call i8* @GC_malloc(i64 ptrtoint (%function_info* getelementptr (%function_info, %function_info* null, i32 1) to i64))
  %typed_info = bitcast i8* %info to %function_info*
  
  ; Store function pointer
  %func_ptr = getelementptr %function_info, %function_info* %typed_info, i32 0, i32 0
  store %value (%list*)* %func, %value (%list*)** %func_ptr
  
  ; Store argument list
  %args_ptr = getelementptr %function_info, %function_info* %typed_info, i32 0, i32 1
  store %list* %args, %list** %args_ptr
  
  ; Store argument count
  %count_ptr = getelementptr %function_info, %function_info* %typed_info, i32 0, i32 2
  store i64 %num_args, i64* %count_ptr
  
  ; Create value with function tag
  %val = call %value @create_value(i32 4, i8* %info)
  ret %value %val
}

; Get function info from value
define %function_info* @get_function_info(%value %val) {
  %ptr = call i8* @get_value_ptr(%value %val)
  %info = bitcast i8* %ptr to %function_info*
  ret %function_info* %info
}

; Get function pointer from info
define %function_t @get_function_ptr(%function_info* %info) {
  %ptr = getelementptr %function_info, %function_info* %info, i32 0, i32 0
  %func = load %function_t, %function_t* %ptr
  ret %function_t %func
}

; Get argument list from info
define %list* @get_function_args(%function_info* %info) {
  %ptr = getelementptr %function_info, %function_info* %info, i32 0, i32 1
  %args = load %list*, %list** %ptr
  ret %list* %args
}

; Get argument count from info
define i64 @get_function_arg_count(%function_info* %info) {
  %ptr = getelementptr %function_info, %function_info* %info, i32 0, i32 2
  %count = load i64, i64* %ptr
  ret i64 %count
}

; Check if value is nil
define i1 @is_nil(%value %val) {
  %tag = call i32 @get_type(%value %val)
  %is_nil = icmp eq i32 %tag, 0
  ret i1 %is_nil
}

; Check if value is a symbol
define i1 @is_symbol(%value %val) {
  %tag = call i32 @get_type(%value %val)
  %is_sym = icmp eq i32 %tag, 1
  ret i1 %is_sym
}

; Check if value is a string
define i1 @is_string(%value %val) {
  %tag = call i32 @get_type(%value %val)
  %is_str = icmp eq i32 %tag, 2
  ret i1 %is_str
}

; Check if value is a list
define i1 @is_list(%value %val) {
  %tag = call i32 @get_type(%value %val)
  %is_lst = icmp eq i32 %tag, 3
  ret i1 %is_lst
}

; Check if value is a function
define i1 @is_function(%value %val) {
  %tag = call i32 @get_type(%value %val)
  %is_func = icmp eq i32 %tag, 4
  ret i1 %is_func
}

; Get length of a string
define i64 @string_length(%value %val) {
  %is_str = call i1 @is_string(%value %val)
  br i1 %is_str, label %get_len, label %error

get_len:
  %str = call i8* @get_value_ptr(%value %val)
  %len = call i64 @strlen(i8* %str)
  ret i64 %len

error:
  call void @error(i8* getelementptr inbounds ([19 x i8], [19 x i8]* @.str.not_string, i32 0, i32 0))
  ret i64 0
}

; Get length of a list
define i64 @list_length(%list* %lst) {
  %is_null = icmp eq %list* %lst, null
  br i1 %is_null, label %done, label %count

count:
  %tail = call %list* @cdr(%list* %lst)
  %sub_len = call i64 @list_length(%list* %tail)
  %len = add i64 1, %sub_len
  ret i64 %len

done:
  ret i64 0
}

; Error message string constant
@.str.not_string = private unnamed_addr constant [19 x i8] c"not a string value\00"

; External functions
declare i8* @GC_malloc(i64)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i32, i1)
declare i64 @strlen(i8*)
declare void @error(i8*) 