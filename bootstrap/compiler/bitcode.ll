; ModuleID = 'bootstrap_bitcode'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; LLVM types needed for JIT compilation
%LLVMOpaqueContext = type opaque
%LLVMOpaqueModule = type opaque
%LLVMOpaqueExecutionEngine = type opaque
%LLVMOpaqueMemoryBuffer = type opaque

; External types from types.ll
%value = type opaque
%list = type opaque
%function_t = type %value (%list*)*

; External functions from types.ll
declare %value @create_value(i32, i8*)
declare %value @create_symbol(i8*, i64)
declare %value @create_function(%function_t)

; External functions from runtime.ll
declare void @register_global(i8*, i64, %value)

; External types from parser.ll
%ast_node = type {
  i32,    ; node_type
  i8*,    ; value
  i64,    ; value_length
  %ast_node**,  ; children
  i64     ; num_children
}

; Process a define-bitcode form
define %value @process_define_bitcode(%ast_node* %form) {
  ; Get symbol and bitcode from form
  %children_ptr = getelementptr %ast_node, %ast_node* %form, i32 0, i32 3
  %children = load %ast_node**, %ast_node*** %children_ptr
  
  ; Get symbol (first child)
  %sym_ptr = getelementptr %ast_node*, %ast_node** %children, i64 0
  %sym_node = load %ast_node*, %ast_node** %sym_ptr
  %sym_val_ptr = getelementptr %ast_node, %ast_node* %sym_node, i32 0, i32 1
  %sym_name = load i8*, i8** %sym_val_ptr
  %sym_len_ptr = getelementptr %ast_node, %ast_node* %sym_node, i32 0, i32 2
  %sym_len = load i64, i64* %sym_len_ptr
  
  ; Get bitcode string (second child)
  %bitcode_ptr = getelementptr %ast_node*, %ast_node** %children, i64 1
  %bitcode_node = load %ast_node*, %ast_node** %bitcode_ptr
  %bitcode_val_ptr = getelementptr %ast_node, %ast_node* %bitcode_node, i32 0, i32 1
  %bitcode = load i8*, i8** %bitcode_val_ptr
  
  ; Create LLVM context
  %context = call %LLVMOpaqueContext* @LLVMContextCreate()
  
  ; Create memory buffer from bitcode string
  %buffer = call %LLVMOpaqueMemoryBuffer* @LLVMCreateMemoryBufferWithString(i8* %bitcode, i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.module, i64 0, i64 0))
  
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
  %nil = call %value @create_value(i32 0, i8* null)
  ret %value %nil

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
  %nil2 = call %value @create_value(i32 0, i8* null)
  ret %value %nil2

get_function:
  %engine = load %LLVMOpaqueExecutionEngine*, %LLVMOpaqueExecutionEngine** %engine_ptr
  %func_ptr = call i8* @LLVMGetFunctionAddress(%LLVMOpaqueExecutionEngine* %engine, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.func, i64 0, i64 0))
  %typed_func = bitcast i8* %func_ptr to %function_t
  
  ; Create function value
  %func_val = call %value @create_function(%function_t %typed_func)
  
  ; Register function with symbol
  call void @register_global(i8* %sym_name, i64 %sym_len, %value %func_val)
  
  ; Clean up
  call void @LLVMDisposeExecutionEngine(%LLVMOpaqueExecutionEngine* %engine)
  call void @LLVMDisposeMemoryBuffer(%LLVMOpaqueMemoryBuffer* %buffer)
  call void @LLVMContextDispose(%LLVMOpaqueContext* %context)
  
  ; Return the symbol
  %sym_val = call %value @create_symbol(i8* %sym_name, i64 %sym_len)
  ret %value %sym_val
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