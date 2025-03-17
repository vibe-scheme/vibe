; ModuleID = 'scheme_runtime'
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Function pointer type for scheme functions
%scheme_function_t = type i8* (i8*)*

; LLVM types needed for JIT compilation
%LLVMOpaqueContext = type opaque
%LLVMOpaqueModule = type opaque
%LLVMOpaqueBuilder = type opaque
%LLVMOpaqueExecutionEngine = type opaque
%LLVMOpaqueMemoryBuffer = type opaque
%LLVMOpaqueMessage = type opaque

; Symbol table entry structure
%symbol_entry = type {
  i8*,              ; symbol name
  i64,              ; symbol length
  %scheme_function_t, ; function pointer
  %symbol_entry*    ; next entry in chain (for hash collisions)
}

; Hash table size (prime number for better distribution)
@HASH_TABLE_SIZE = private unnamed_addr constant i64 997

; Global hash table
@symbol_table = global [997 x %symbol_entry*] zeroinitializer

; Function to compute hash of a symbol
define private i64 @hash_symbol(i8* %symbol, i64 %length) {
entry:
  %hash = alloca i64
  store i64 5381, i64* %hash  ; djb2 hash initial value
  %i = alloca i64
  store i64 0, i64* %i
  br label %hash_loop

hash_loop:
  %current_i = load i64, i64* %i
  %done = icmp eq i64 %current_i, %length
  br i1 %done, label %finalize, label %continue_hash

continue_hash:
  %current_hash = load i64, i64* %hash
  %char_ptr = getelementptr i8, i8* %symbol, i64 %current_i
  %char = load i8, i8* %char_ptr
  %char_ext = zext i8 %char to i64
  %hash_step1 = shl i64 %current_hash, 5
  %hash_step2 = add i64 %hash_step1, %current_hash
  %hash_step3 = add i64 %hash_step2, %char_ext
  store i64 %hash_step3, i64* %hash
  %next_i = add i64 %current_i, 1
  store i64 %next_i, i64* %i
  br label %hash_loop

finalize:
  %final_hash = load i64, i64* %hash
  %index = urem i64 %final_hash, 997
  ret i64 %index
}

; Function to create a new symbol entry
define private %symbol_entry* @create_symbol_entry(i8* %symbol, i64 %length, %scheme_function_t %func) {
entry:
  %entry_size = add i64 24, %length  ; sizeof(symbol_entry) + symbol length
  %entry_ptr = call i8* @malloc(i64 %entry_size)
  %typed_entry = bitcast i8* %entry_ptr to %symbol_entry*
  
  ; Copy symbol name
  %name_ptr = getelementptr %symbol_entry, %symbol_entry* %typed_entry, i32 0, i32 0
  %symbol_storage = call i8* @malloc(i64 %length)
  call void @memcpy(i8* %symbol_storage, i8* %symbol, i64 %length)
  store i8* %symbol_storage, i8** %name_ptr
  
  ; Store length
  %len_ptr = getelementptr %symbol_entry, %symbol_entry* %typed_entry, i32 0, i32 1
  store i64 %length, i64* %len_ptr
  
  ; Store function pointer
  %func_ptr = getelementptr %symbol_entry, %symbol_entry* %typed_entry, i32 0, i32 2
  store %scheme_function_t %func, %scheme_function_t* %func_ptr
  
  ; Initialize next pointer to null
  %next_ptr = getelementptr %symbol_entry, %symbol_entry* %typed_entry, i32 0, i32 3
  store %symbol_entry* null, %symbol_entry** %next_ptr
  
  ret %symbol_entry* %typed_entry
}

; Function to register a function with a symbol
define void @register_function(i8* %symbol, i64 %length, %scheme_function_t %func) {
entry:
  %hash = call i64 @hash_symbol(i8* %symbol, i64 %length)
  %table_ptr = getelementptr [997 x %symbol_entry*], [997 x %symbol_entry*]* @symbol_table, i64 0, i64 %hash
  %current = load %symbol_entry*, %symbol_entry** %table_ptr
  
  ; Create new entry
  %new_entry = call %symbol_entry* @create_symbol_entry(i8* %symbol, i64 %length, %scheme_function_t %func)
  
  ; If slot is empty, insert directly
  %is_empty = icmp eq %symbol_entry* %current, null
  br i1 %is_empty, label %insert, label %find_end

insert:
  store %symbol_entry* %new_entry, %symbol_entry** %table_ptr
  ret void

find_end:
  ; Find end of chain
  br label %traverse

traverse:
  %current_entry = phi %symbol_entry* [ %current, %find_end ], [ %next_entry, %continue ]
  %next_ptr = getelementptr %symbol_entry, %symbol_entry* %current_entry, i32 0, i32 3
  %next_entry = load %symbol_entry*, %symbol_entry** %next_ptr
  %is_last = icmp eq %symbol_entry* %next_entry, null
  br i1 %is_last, label %append, label %continue

continue:
  br label %traverse

append:
  store %symbol_entry* %new_entry, %symbol_entry** %next_ptr
  ret void
}

; Function to look up a function by symbol
define %scheme_function_t @lookup_function(i8* %symbol, i64 %length) {
entry:
  %hash = call i64 @hash_symbol(i8* %symbol, i64 %length)
  %table_ptr = getelementptr [997 x %symbol_entry*], [997 x %symbol_entry*]* @symbol_table, i64 0, i64 %hash
  %first_entry = load %symbol_entry*, %symbol_entry** %table_ptr
  br label %search

search:
  %current = phi %symbol_entry* [ %first_entry, %entry ], [ %next, %continue ]
  %is_null = icmp eq %symbol_entry* %current, null
  br i1 %is_null, label %not_found, label %check_symbol

check_symbol:
  %name_ptr = getelementptr %symbol_entry, %symbol_entry* %current, i32 0, i32 0
  %name = load i8*, i8** %name_ptr
  %len_ptr = getelementptr %symbol_entry, %symbol_entry* %current, i32 0, i32 1
  %len = load i64, i64* %len_ptr
  
  ; Compare lengths first
  %lengths_match = icmp eq i64 %len, %length
  br i1 %lengths_match, label %compare_strings, label %next_entry

compare_strings:
  %cmp = call i32 @memcmp(i8* %name, i8* %symbol, i64 %length)
  %strings_match = icmp eq i32 %cmp, 0
  br i1 %strings_match, label %found, label %next_entry

next_entry:
  %next_ptr = getelementptr %symbol_entry, %symbol_entry* %current, i32 0, i32 3
  %next = load %symbol_entry*, %symbol_entry** %next_ptr
  br label %continue

continue:
  br label %search

found:
  %func_ptr = getelementptr %symbol_entry, %symbol_entry* %current, i32 0, i32 2
  %func = load %scheme_function_t, %scheme_function_t* %func_ptr
  ret %scheme_function_t %func

not_found:
  ret %scheme_function_t null
}

; External functions
declare i8* @malloc(i64)
declare void @free(i8*)
declare void @memcpy(i8*, i8*, i64)
declare i32 @memcmp(i8*, i8*, i64)

; External LLVM functions for JIT compilation
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

; Structure for scheme list
%scheme_list = type {
  i8*,           ; value
  %scheme_list*  ; next
}

; Function to get next item from list
define private { i8*, %scheme_list* } @list_next(%scheme_list* %list) {
entry:
  %is_null = icmp eq %scheme_list* %list, null
  br i1 %is_null, label %return_null, label %get_values

get_values:
  %value_ptr = getelementptr %scheme_list, %scheme_list* %list, i32 0, i32 0
  %next_ptr = getelementptr %scheme_list, %scheme_list* %list, i32 0, i32 1
  %value = load i8*, i8** %value_ptr
  %next = load %scheme_list*, %scheme_list** %next_ptr
  %result = insertvalue { i8*, %scheme_list* } undef, i8* %value, 0
  %result2 = insertvalue { i8*, %scheme_list* } %result, %scheme_list* %next, 1
  ret { i8*, %scheme_list* } %result2

return_null:
  %null_result = insertvalue { i8*, %scheme_list* } undef, i8* null, 0
  %null_result2 = insertvalue { i8*, %scheme_list* } %null_result, %scheme_list* null, 1
  ret { i8*, %scheme_list* } %null_result2
}

; Function to compile LLVM bitcode and get function pointer
define private %scheme_function_t @compile_bitcode(i8* %bitcode) {
entry:
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
  ret %scheme_function_t null

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
  ret %scheme_function_t null

get_function:
  %engine = load %LLVMOpaqueExecutionEngine*, %LLVMOpaqueExecutionEngine** %engine_ptr
  %func_ptr = call i8* @LLVMGetFunctionAddress(%LLVMOpaqueExecutionEngine* %engine, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.func, i64 0, i64 0))
  %typed_func = bitcast i8* %func_ptr to %scheme_function_t
  
  ; Clean up
  call void @LLVMDisposeExecutionEngine(%LLVMOpaqueExecutionEngine* %engine)
  call void @LLVMDisposeMemoryBuffer(%LLVMOpaqueMemoryBuffer* %buffer)
  call void @LLVMContextDispose(%LLVMOpaqueContext* %context)
  
  ret %scheme_function_t %typed_func
}

; String constants
@.str.module = private unnamed_addr constant [7 x i8] c"module\00"
@.str.func = private unnamed_addr constant [5 x i8] c"func\00"
@.str.define_bitcode = private unnamed_addr constant [15 x i8] c"define-bitcode\00"

; Example primitive functions
@.str.plus = private unnamed_addr constant [2 x i8] c"+\00"
@.str.minus = private unnamed_addr constant [2 x i8] c"-\00"

; Function to register primitive functions
define void @register_primitives() {
  call void @register_function(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.plus, i64 0, i64 0), i64 1, %scheme_function_t @scheme_plus)
  call void @register_function(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.minus, i64 0, i64 0), i64 1, %scheme_function_t @scheme_minus)
  call void @register_function(i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.define_bitcode, i64 0, i64 0), i64 14, %scheme_function_t @scheme_define_bitcode)
  ret void
}

; Example primitive function implementations
define i8* @scheme_plus(i8* %args) {
  ret i8* null
}

define i8* @scheme_minus(i8* %args) {
  ret i8* null
}

define i8* @scheme_define_bitcode(i8* %args) {
  ret i8* null
}

; Function to initialize runtime with primitive functions
define void @init_runtime() {
entry:
  ; Register primitive functions
  call void @register_primitives()
  ret void
} 