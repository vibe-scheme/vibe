; ModuleID = 'bootstrap_define_bitcode'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; LLVM opaque types
%LLVMOpaqueContext = type opaque
%LLVMOpaqueMemoryBuffer = type opaque
%LLVMOpaqueModule = type opaque
%LLVMOpaqueExecutionEngine = type opaque

; Implementation of define-bitcode function
define %value @define_bitcode(%list* %args) {
  ; Extract arguments (symbol, arg list, bitcode)
  %sym_val = call %value @car(%list* %args)
  %rest1 = call %list* @cdr(%list* %args)
  %args_val = call %value @car(%list* %rest1)
  %rest2 = call %list* @cdr(%list* %rest1)
  %bitcode_val = call %value @car(%list* %rest2)
  
  ; Validate symbol argument
  %is_sym = call i1 @is_symbol(%value %sym_val)
  br i1 %is_sym, label %check_args, label %type_error
  
check_args:
  ; Validate argument list
  %is_list = call i1 @is_list(%value %args_val)
  br i1 %is_list, label %check_bitcode, label %type_error
  
check_bitcode:
  ; Validate bitcode string
  %is_str = call i1 @is_string(%value %bitcode_val)
  br i1 %is_str, label %compile_bitcode, label %type_error
  
compile_bitcode:
  ; Get symbol name
  %sym_ptr = call i8* @get_value_ptr(%value %sym_val)
  %sym_len = call i64 @string_length(i8* %sym_ptr)
  
  ; Get bitcode string
  %bitcode_ptr = call i8* @get_value_ptr(%value %bitcode_val)
  
  ; Create LLVM context
  %context = call %LLVMOpaqueContext* @LLVMContextCreate()
  
  ; Create memory buffer from bitcode string
  %buffer = call %LLVMOpaqueMemoryBuffer* @LLVMCreateMemoryBufferWithString(i8* %bitcode_ptr, i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.module, i64 0, i64 0))
  
  ; Parse IR
  %error_ptr = alloca i8*
  %module = call %LLVMOpaqueModule* @LLVMParseIRInContext(%LLVMOpaqueContext* %context, %LLVMOpaqueMemoryBuffer* %buffer, i8** %error_ptr)
  
  ; Check for parsing errors
  %error_msg = load i8*, i8** %error_ptr
  %has_error = icmp ne i8* %error_msg, null
  br i1 %has_error, label %handle_error, label %create_engine
  
handle_error:
  call void @LLVMDisposeMessage(i8* %error_msg)
  call void @LLVMDisposeMemoryBuffer(%LLVMOpaqueMemoryBuffer* %buffer)
  call void @LLVMContextDispose(%LLVMOpaqueContext* %context)
  br label %type_error
  
create_engine:
  ; Create execution engine
  %engine_ptr = alloca %LLVMOpaqueExecutionEngine*
  %engine_error = alloca i8*
  %engine_result = call i32 @LLVMCreateExecutionEngineForModule(%LLVMOpaqueExecutionEngine** %engine_ptr, %LLVMOpaqueModule* %module, i8** %engine_error)
  
  ; Check for engine creation errors
  %engine_error_msg = load i8*, i8** %engine_error
  %engine_has_error = icmp ne i8* %engine_error_msg, null
  br i1 %engine_has_error, label %handle_engine_error, label %get_function
  
handle_engine_error:
  call void @LLVMDisposeMessage(i8* %engine_error_msg)
  call void @LLVMDisposeModule(%LLVMOpaqueModule* %module)
  call void @LLVMDisposeMemoryBuffer(%LLVMOpaqueMemoryBuffer* %buffer)
  call void @LLVMContextDispose(%LLVMOpaqueContext* %context)
  br label %type_error
  
get_function:
  %engine = load %LLVMOpaqueExecutionEngine*, %LLVMOpaqueExecutionEngine** %engine_ptr
  %func_ptr = call i8* @LLVMGetFunctionAddress(%LLVMOpaqueExecutionEngine* %engine, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.func, i64 0, i64 0))
  %typed_func = bitcast i8* %func_ptr to %value (%list*)*
  
  ; Get argument list
  %args_ptr = call i8* @get_value_ptr(%value %args_val)
  %args_list = bitcast i8* %args_ptr to %list*
  
  ; Count arguments
  %arg_count = call i64 @list_length(%list* %args_list)
  
  ; Create function value with argument info
  %func_val = call %value @create_function_with_args(%value (%list*)* %typed_func, %list* %args_list, i64 %arg_count)
  
  ; Register function with symbol
  call void @register_global(i8* %sym_ptr, i64 %sym_len, %value %func_val)
  
  ; Clean up
  call void @LLVMDisposeExecutionEngine(%LLVMOpaqueExecutionEngine* %engine)
  call void @LLVMDisposeMemoryBuffer(%LLVMOpaqueMemoryBuffer* %buffer)
  call void @LLVMContextDispose(%LLVMOpaqueContext* %context)
  
  ret %value %sym_val
  
type_error:
  %nil = call %value @create_value(i32 0, i8* null)
  ret %value %nil
}

; String constants
@.str.module = private unnamed_addr constant [7 x i8] c"module\00"
@.str.func = private unnamed_addr constant [5 x i8] c"func\00"

; External functions from LLVM
declare %LLVMOpaqueContext* @LLVMContextCreate()
declare void @LLVMContextDispose(%LLVMOpaqueContext*)
declare %LLVMOpaqueMemoryBuffer* @LLVMCreateMemoryBufferWithString(i8*, i8*)
declare %LLVMOpaqueModule* @LLVMParseIRInContext(%LLVMOpaqueContext*, %LLVMOpaqueMemoryBuffer*, i8**)
declare i32 @LLVMCreateExecutionEngineForModule(%LLVMOpaqueExecutionEngine**, %LLVMOpaqueModule*, i8**)
declare i8* @LLVMGetFunctionAddress(%LLVMOpaqueExecutionEngine*, i8*)
declare void @LLVMDisposeMessage(i8*)
declare void @LLVMDisposeMemoryBuffer(%LLVMOpaqueMemoryBuffer*)
declare void @LLVMDisposeModule(%LLVMOpaqueModule*)
declare void @LLVMDisposeExecutionEngine(%LLVMOpaqueExecutionEngine*)

; External types and functions from types.ll
%value = type { i32, i8* }
%function_t = type %value (%list*)*
%list = type { %value, %list* }
declare %value @create_value(i32, i8*)
declare %value @car(%list*)
declare %list* @cdr(%list*)
declare i1 @is_symbol(%value)
declare i1 @is_string(%value)
declare i1 @is_list(%value)
declare i8* @get_value_ptr(%value)
declare %value @create_function_with_args(%value (%list*)*, %list*, i64)

; External functions from runtime.ll
declare void @register_global(i8*, i64, %value)
declare i64 @string_length(i8*)
declare i64 @list_length(%list*) 