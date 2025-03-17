; ModuleID = 'vibe_eval'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Import types and functions from runtime
%value = type { i32, i8* }
%list = type { %value, %list* }

declare %value @create_value(i32, i8*)
declare i32 @get_type(%value)
declare i8* @get_value_ptr(%value)
declare %value @car(%list*)
declare %list* @cdr(%list*)
declare %value @lookup_symbol(i8*, i64)
declare void @define_symbol(i8*, i64, %value)
declare i8* @GC_malloc(i64)

; Value type tags (must match runtime.ll)
@TAG_NIL = external constant i32
@TAG_NUMBER = external constant i32
@TAG_SYMBOL = external constant i32
@TAG_FUNCTION = external constant i32
@TAG_LIST = external constant i32

; Function type for native functions
%native_fn = type %value (%list*)*

; Closure type
%closure = type {
  %native_fn,  ; Function pointer
  %list*       ; Environment
}

; Evaluate a Vibe expression
define %value @eval(%value %expr, %list* %env) {
  ; Get expression type
  %type = call i32 @get_type(%value %expr)
  
  ; Handle different expression types
  %is_symbol = call i1 @is_symbol(i32 %type)
  br i1 %is_symbol, label %eval_symbol, label %check_list
  
check_list:
  %is_list = call i1 @is_list(i32 %type)
  br i1 %is_list, label %eval_list, label %return_as_is
  
eval_symbol:
  ; Look up symbol in environment
  %sym_ptr = call i8* @get_value_ptr(%value %expr)
  %sym_struct = bitcast i8* %sym_ptr to { i64, [0 x i8] }*
  %sym_len_ptr = getelementptr { i64, [0 x i8] }, { i64, [0 x i8] }* %sym_struct, i32 0, i32 0
  %sym_len = load i64, i64* %sym_len_ptr
  %sym_name = getelementptr { i64, [0 x i8] }, { i64, [0 x i8] }* %sym_struct, i32 0, i32 1, i64 0
  %val = call %value @lookup_symbol(i8* %sym_name, i64 %sym_len)
  ret %value %val
  
eval_list:
  ; Empty list evaluates to itself
  %list_ptr = call i8* @get_value_ptr(%value %expr)
  %list = bitcast i8* %list_ptr to %list*
  %is_null = icmp eq %list* %list, null
  br i1 %is_null, label %return_as_is, label %eval_application
  
eval_application:
  ; Evaluate operator
  %op = call %value @car(%list* %list)
  %evaled_op = call %value @eval(%value %op, %list* %env)
  
  ; Get arguments list
  %args = call %list* @cdr(%list* %list)
  
  ; Apply function to arguments
  %result = call %value @apply(%value %evaled_op, %list* %args, %list* %env)
  ret %value %result
  
return_as_is:
  ret %value %expr
}

; Apply a function to arguments
define %value @apply(%value %fn, %list* %args, %list* %env) {
  ; Check if function is native or closure
  %type = call i32 @get_type(%value %fn)
  %is_native = call i1 @is_native_function(i32 %type)
  br i1 %is_native, label %apply_native, label %apply_closure
  
apply_native:
  ; Call native function directly
  %native_ptr = call i8* @get_value_ptr(%value %fn)
  %native_fn = bitcast i8* %native_ptr to %native_fn
  %result = call %value %native_fn(%list* %args)
  ret %value %result
  
apply_closure:
  ; TODO: Implement closure application
  %nil = load i32, i32* @TAG_NIL
  %nil_val = call %value @create_value(i32 %nil, i8* null)
  ret %value %nil_val
}

; Type checking helpers
define private i1 @is_symbol(i32 %type) {
  %symbol_tag = load i32, i32* @TAG_SYMBOL
  %result = icmp eq i32 %type, %symbol_tag
  ret i1 %result
}

define private i1 @is_list(i32 %type) {
  %list_tag = load i32, i32* @TAG_LIST
  %result = icmp eq i32 %type, %list_tag
  ret i1 %result
}

define private i1 @is_native_function(i32 %type) {
  %fn_tag = load i32, i32* @TAG_FUNCTION
  %result = icmp eq i32 %type, %fn_tag
  ret i1 %result
} 