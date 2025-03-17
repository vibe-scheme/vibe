; ModuleID = 'vibe_main'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Types
%value = type { i32, i8* }
%list = type { %value, %value }

; String constants
@.str.usage = constant [36 x i8] c"Usage: vibe <filename> - Evaluate a file\00"
@.str.file_error = constant [21 x i8] c"Error reading file: \00"
@.str.newline = constant [2 x i8] c"\0A\00"
@.str.read_mode = constant [2 x i8] c"r\00"

; External functions
declare i32 @printf(i8*, ...)
declare i8* @fopen(i8*, i8*)
declare i64 @fread(i8*, i64, i64, i8*)
declare i32 @fclose(i8*)
declare i8* @GC_malloc(i64)
declare void @init_runtime()
declare %value @eval_string(%value, %list*)
declare %value @create_value(i32, i8*)
declare void @print_string(i8*)

; Main function
define i32 @main(i32 %argc, i8** %argv) {
  ; Check args
  %has_file = icmp eq i32 %argc, 2
  br i1 %has_file, label %read_file, label %usage

usage:
  call void @print_string(i8* getelementptr inbounds ([36 x i8], [36 x i8]* @.str.usage, i32 0, i32 0))
  call void @print_string(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0))
  ret i32 1

read_file:
  ; Get filename
  %filename = load i8*, i8** %argv
  %file = call i8* @fopen(i8* %filename, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.read_mode, i32 0, i32 0))
  
  ; Check if file opened
  %file_null = icmp eq i8* %file, null
  br i1 %file_null, label %file_error, label %read_contents

file_error:
  call void @print_string(i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.file_error, i32 0, i32 0))
  call void @print_string(i8* %filename)
  call void @print_string(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.newline, i32 0, i32 0))
  ret i32 1

read_contents:
  ; Allocate buffer
  %buf = call i8* @GC_malloc(i64 4096)
  %read = call i64 @fread(i8* %buf, i64 1, i64 4096, i8* %file)
  call i32 @fclose(i8* %file)
  
  ; Initialize runtime
  call void @init_runtime()
  
  ; Create string value and evaluate
  %str = call %value @create_value(i32 2, i8* %buf)
  %nil = call %value @create_value(i32 0, i8* null)
  %env = call i8* @GC_malloc(i64 16)
  %result = call %value @eval_string(%value %str, %list* %env)
  
  ret i32 0
}

; External functions from C standard library
%FILE = type opaque
declare %FILE* @fopen(i8*, i8*)
declare i32 @fseek(%FILE*, i64, i32)
declare i64 @ftell(%FILE*)
declare i64 @fread(i8*, i64, i64, %FILE*)
declare void @print_string(i8*)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i32, i1)

; External functions from runtime.ll
declare void @init_runtime()
declare %value @create_value(i32, i8*)
declare %value @eval_string(%value, %list*)

; External functions from special.ll
declare void @register_special_forms()

; External functions from types.ll
declare i8* @GC_malloc(i64)

; Value type tags (must match runtime.ll)
@TAG_NIL = external constant i32
@TAG_STRING = external constant i32 