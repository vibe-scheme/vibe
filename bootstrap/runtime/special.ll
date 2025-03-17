; ModuleID = 'vibe_special'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Import types and functions
%value = type { i32, i8* }
%list = type { %value, %list* }

; LLVM types needed for JIT
%LLVMOpaqueContext = type opaque
%LLVMOpaqueModule = type opaque
%LLVMOpaqueMemoryBuffer = type opaque
%LLVMOpaqueExecutionEngine = type opaque
%LLVMContextRef = type %LLVMOpaqueContext*
%LLVMModuleRef = type %LLVMOpaqueModule*
%LLVMMemoryBufferRef = type %LLVMOpaqueMemoryBuffer*
%LLVMExecutionEngineRef = type %LLVMOpaqueExecutionEngine*

declare %value @create_value(i32, i8*)
declare i32 @get_type(%value)
declare i8* @get_value_ptr(%value)
declare %value @car(%list*)
declare %list* @cdr(%list*)
declare %value @lookup_symbol(i8*, i64)
declare void @define_symbol(i8*, i64, %value)
declare i8* @GC_malloc(i64)
declare %value @eval(%value, %list*)

; LLVM JIT functions
declare %LLVMContextRef @LLVMContextCreate()
declare void @LLVMContextDispose(%LLVMContextRef)
declare %LLVMMemoryBufferRef @LLVMCreateMemoryBufferWithString(i8*, i8*)
declare void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef)
declare i32 @LLVMParseIRInContext(%LLVMContextRef, %LLVMMemoryBufferRef, %LLVMModuleRef*, i8**)
declare i32 @LLVMCreateExecutionEngineForModule(%LLVMExecutionEngineRef*, %LLVMModuleRef, i8**)
declare i8* @LLVMGetFunctionAddress(%LLVMExecutionEngineRef, i8*)

; Value type tags (must match runtime.ll)
@TAG_NIL = external constant i32
@TAG_NUMBER = external constant i32
@TAG_SYMBOL = external constant i32
@TAG_FUNCTION = external constant i32
@TAG_LIST = external constant i32

; Special form names
@.str.define = private unnamed_addr constant [7 x i8] c"define\00"
@.str.bitcode_lambda = private unnamed_addr constant [15 x i8] c"bitcode-lambda\00"
@.str.anon_fn = private unnamed_addr constant [8 x i8] c"anon_fn\00"

; Handle define special form
define %value @handle_define(%list* %args, %list* %env) {
  ; Get symbol to define
  %sym_cell = call %value @car(%list* %args)
  %sym_type = call i32 @get_type(%value %sym_cell)
  %sym_tag = load i32, i32* @TAG_SYMBOL
  %is_sym = icmp eq i32 %sym_type, %sym_tag
  br i1 %is_sym, label %valid_symbol, label %type_error

valid_symbol:
  ; Get value to bind
  %rest = call %list* @cdr(%list* %args)
  %val_cell = call %value @car(%list* %rest)
  
  ; Evaluate value
  %val = call %value @eval(%value %val_cell, %list* %env)
  
  ; Get symbol name and length
  %sym_ptr = call i8* @get_value_ptr(%value %sym_cell)
  %sym_struct = bitcast i8* %sym_ptr to { i64, [0 x i8] }*
  %sym_len_ptr = getelementptr { i64, [0 x i8] }, { i64, [0 x i8] }* %sym_struct, i32 0, i32 0
  %sym_len = load i64, i64* %sym_len_ptr
  %sym_name = getelementptr { i64, [0 x i8] }, { i64, [0 x i8] }* %sym_struct, i32 0, i32 1, i64 0
  
  ; Define the symbol
  call void @define_symbol(i8* %sym_name, i64 %sym_len, %value %val)
  
  ; Return the value
  ret %value %val

type_error:
  %nil = load i32, i32* @TAG_NIL
  %nil_val = call %value @create_value(i32 %nil, i8* null)
  ret %value %nil_val
}

; Handle bitcode-lambda special form
define %value @handle_bitcode_lambda(%list* %args, %list* %env) {
  ; Get parameter list (not used yet, but validated)
  %params = call %value @car(%list* %args)
  %params_type = call i32 @get_type(%value %params)
  %list_tag = load i32, i32* @TAG_LIST
  %is_list = icmp eq i32 %params_type, %list_tag
  br i1 %is_list, label %valid_params, label %type_error

valid_params:
  ; Get bitcode body
  %rest = call %list* @cdr(%list* %args)
  %body_cell = call %value @car(%list* %rest)
  %body_type = call i32 @get_type(%value %body_cell)
  %is_string = icmp eq i32 %body_type, 0  ; TODO: proper string type
  br i1 %is_string, label %compile_bitcode, label %type_error

compile_bitcode:
  ; Get bitcode string
  %body_ptr = call i8* @get_value_ptr(%value %body_cell)
  %body_struct = bitcast i8* %body_ptr to { i64, [0 x i8] }*
  %body_len_ptr = getelementptr { i64, [0 x i8] }, { i64, [0 x i8] }* %body_struct, i32 0, i32 0
  %body_len = load i64, i64* %body_len_ptr
  %body_str = getelementptr { i64, [0 x i8] }, { i64, [0 x i8] }* %body_struct, i32 0, i32 1, i64 0
  
  ; Create LLVM context
  %context = call %LLVMContextRef @LLVMContextCreate()
  
  ; Create memory buffer with bitcode
  %membuf = call %LLVMMemoryBufferRef @LLVMCreateMemoryBufferWithString(i8* %body_str, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.anon_fn, i64 0, i64 0))
  
  ; Parse bitcode into module
  %module_ptr = alloca %LLVMModuleRef
  %error_ptr = alloca i8*
  %parse_result = call i32 @LLVMParseIRInContext(%LLVMContextRef %context, %LLVMMemoryBufferRef %membuf, %LLVMModuleRef* %module_ptr, i8** %error_ptr)
  
  ; Check for parse errors
  %parse_ok = icmp eq i32 %parse_result, 0
  br i1 %parse_ok, label %create_engine, label %cleanup_parse_error
  
create_engine:
  ; Create execution engine
  %engine_ptr = alloca %LLVMExecutionEngineRef
  %engine_error = alloca i8*
  %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
  %engine_result = call i32 @LLVMCreateExecutionEngineForModule(%LLVMExecutionEngineRef* %engine_ptr, %LLVMModuleRef %module, i8** %engine_error)
  
  ; Check for engine creation errors
  %engine_ok = icmp eq i32 %engine_result, 0
  br i1 %engine_ok, label %get_function, label %cleanup_engine_error
  
get_function:
  ; Get function address
  %engine = load %LLVMExecutionEngineRef, %LLVMExecutionEngineRef* %engine_ptr
  %fn_addr = call i8* @LLVMGetFunctionAddress(%LLVMExecutionEngineRef %engine, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.anon_fn, i64 0, i64 0))
  
  ; Create function value
  %fn_tag = load i32, i32* @TAG_FUNCTION
  %fn_val = call %value @create_value(i32 %fn_tag, i8* %fn_addr)
  ret %value %fn_val
  
cleanup_parse_error:
  call void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef %membuf)
  call void @LLVMContextDispose(%LLVMContextRef %context)
  br label %type_error
  
cleanup_engine_error:
  call void @LLVMDisposeMemoryBuffer(%LLVMMemoryBufferRef %membuf)
  call void @LLVMContextDispose(%LLVMContextRef %context)
  br label %type_error

type_error:
  %nil = load i32, i32* @TAG_NIL
  %nil_val = call %value @create_value(i32 %nil, i8* null)
  ret %value %nil_val
}

; Register special forms in the environment
define void @register_special_forms() {
  ; Register define
  call void @define_symbol(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.define, i64 0, i64 0), i64 6, 
    %value { i32 ptrtoint (i32* @TAG_FUNCTION to i32), i8* bitcast (%value (%list*, %list*)* @handle_define to i8*) })
  
  ; Register bitcode-lambda
  call void @define_symbol(i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.bitcode_lambda, i64 0, i64 0), i64 14,
    %value { i32 ptrtoint (i32* @TAG_FUNCTION to i32), i8* bitcast (%value (%list*, %list*)* @handle_bitcode_lambda to i8*) })
  
  ret void
} 