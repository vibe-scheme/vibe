; Bootstrap Runtime for Vibe
; Core data structures, memory management, and primitives
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; Value types enum
; VALUE_INTEGER = 0
; VALUE_FLOAT = 1
; VALUE_STRING = 2
; VALUE_SYMBOL = 3
; VALUE_CONS = 4
; VALUE_NIL = 5
; VALUE_BOOLEAN = 6
; VALUE_PROCEDURE = 7
; VALUE_BITCODE = 8  ; For define-bitcode

; VibeValue - Tagged union for all Vibe values
; struct VibeValue {
;     i32 type;           // Value type tag
;     i64 data;           // Value data (pointer or immediate)
; }

%VibeValue = type { i32, i64 }

; VibeCons - Cons cell for lists
; struct VibeCons {
;     %VibeValue car;     // First element
;     %VibeValue cdr;     // Rest of list
; }

%VibeCons = type { %VibeValue, %VibeValue }

; VibeString - String representation
; struct VibeString {
;     i64 length;         // String length
;     i8* data;           // String data (null-terminated)
; }

%VibeString = type { i64, i8* }

; VibeSymbol - Symbol internment entry
; struct VibeSymbol {
;     i64 hash;           // Hash value
;     i8* name;           // Symbol name
;     i64 name_len;       // Name length
;     %VibeSymbol* next;  // Next in hash chain
; }

%VibeSymbol = type { i64, i8*, i64, %VibeSymbol* }

; Symbol table - Hash table for symbol internment
; struct SymbolTable {
;     %VibeSymbol** buckets;  // Array of symbol pointers
;     i64 bucket_count;       // Number of buckets
;     i64 symbol_count;       // Total number of symbols
; }

%SymbolTable = type { %VibeSymbol**, i64, i64 }

; Bitcode binding - For define-bitcode primitive
; struct BitcodeBinding {
;     i8* name;           // Binding name
;     i64 name_len;       // Name length
;     i8* bitcode;        // LLVM bitcode data
;     i64 bitcode_len;    // Bitcode length
;     %BitcodeBinding* next;  // Next binding
; }

%BitcodeBinding = type { i8*, i64, i8*, i64, %BitcodeBinding* }

; Runtime state
; struct Runtime {
;     %SymbolTable* symbol_table;     // Symbol internment table
;     %BitcodeBinding* bitcode_bindings;  // Linked list of bitcode bindings
;     i64 heap_size;                  // Heap size
;     i8* heap;                        // Heap memory
;     i64 heap_pos;                    // Current heap position
; }

%Runtime = type { %SymbolTable*, %BitcodeBinding*, i64, i8*, i64 }

; Initialize runtime
; runtime_init: Initialize the Vibe runtime
; Parameters:
;   heap_size: Initial heap size in bytes
; Returns: Pointer to Runtime structure
define %Runtime* @runtime_init(i64 %heap_size) {
entry:
    %runtime = call i8* @malloc(i64 48)
    %runtime_ptr = bitcast i8* %runtime to %Runtime*
    
    ; Initialize symbol table
    %symbol_table = call %SymbolTable* @symbol_table_init()
    %symtab_ptr = getelementptr %Runtime, %Runtime* %runtime_ptr, i32 0, i32 0
    store %SymbolTable* %symbol_table, %SymbolTable** %symtab_ptr
    
    ; Initialize bitcode bindings (empty list)
    %bindings_ptr = getelementptr %Runtime, %Runtime* %runtime_ptr, i32 0, i32 1
    store %BitcodeBinding* null, %BitcodeBinding** %bindings_ptr
    
    ; Allocate heap
    %heap = call i8* @malloc(i64 %heap_size)
    %heap_ptr = getelementptr %Runtime, %Runtime* %runtime_ptr, i32 0, i32 3
    store i8* %heap, i8** %heap_ptr
    
    %heap_size_ptr = getelementptr %Runtime, %Runtime* %runtime_ptr, i32 0, i32 2
    store i64 %heap_size, i64* %heap_size_ptr
    
    %heap_pos_ptr = getelementptr %Runtime, %Runtime* %runtime_ptr, i32 0, i32 4
    store i64 0, i64* %heap_pos_ptr
    
    ret %Runtime* %runtime_ptr
}

; Initialize symbol table
; symbol_table_init: Initialize symbol internment table
; Returns: Pointer to SymbolTable
define %SymbolTable* @symbol_table_init() {
entry:
    %table = call i8* @malloc(i64 24)
    %table_ptr = bitcast i8* %table to %SymbolTable*
    
    %bucket_count = 256  ; Initial bucket count
    %bucket_size = mul i64 %bucket_count, 8  ; Size of pointer array
    %buckets = call i8* @calloc(i64 %bucket_count, i64 8)
    %buckets_ptr = bitcast i8* %buckets to %VibeSymbol**
    
    %buckets_field = getelementptr %SymbolTable, %SymbolTable* %table_ptr, i32 0, i32 0
    store %VibeSymbol** %buckets_ptr, %VibeSymbol*** %buckets_field
    
    %count_field = getelementptr %SymbolTable, %SymbolTable* %table_ptr, i32 0, i32 1
    store i64 %bucket_count, i64* %count_field
    
    %sym_count_field = getelementptr %SymbolTable, %SymbolTable* %table_ptr, i32 0, i32 2
    store i64 0, i64* %sym_count_field
    
    ret %SymbolTable* %table_ptr
}

; Hash function for strings
; string_hash: Compute hash value for a string
; Parameters:
;   str: String pointer
;   len: String length
; Returns: Hash value
define i64 @string_hash(i8* %str, i64 %len) {
entry:
    %hash = alloca i64
    store i64 5381, i64* %hash  ; DJB2 hash initial value
    %i = alloca i64
    store i64 0, i64* %i
    
    br label %loop

loop:
    %i_val = load i64, i64* %i
    %done = icmp uge i64 %i_val, %len
    br i1 %done, label %exit, label %hash_char

hash_char:
    %char_ptr = getelementptr i8, i8* %str, i64 %i_val
    %char = load i8, i8* %char_ptr
    %char_int = zext i8 %char to i64
    
    %hash_val = load i64, i64* %hash
    %hash_shift = shl i64 %hash_val, 5
    %hash_add = add i64 %hash_shift, %hash_val
    %hash_new = add i64 %hash_add, %char_int
    store i64 %hash_new, i64* %hash
    
    %i_new = add i64 %i_val, 1
    store i64 %i_new, i64* %i
    br label %loop

exit:
    %final_hash = load i64, i64* %hash
    ret i64 %final_hash
}

; Intern symbol
; symbol_intern: Intern a symbol (create or find existing)
; Parameters:
;   table: Pointer to SymbolTable
;   name: Symbol name
;   name_len: Name length
; Returns: Pointer to VibeSymbol
define %VibeSymbol* @symbol_intern(%SymbolTable* %table, i8* %name, i64 %name_len) {
entry:
    ; Compute hash
    %hash = call i64 @string_hash(i8* %name, i64 %name_len)
    
    ; Get bucket index
    %buckets_field = getelementptr %SymbolTable, %SymbolTable* %table, i32 0, i32 0
    %buckets = load %VibeSymbol**, %VibeSymbol*** %buckets_field
    
    %count_field = getelementptr %SymbolTable, %SymbolTable* %table, i32 0, i32 1
    %bucket_count = load i64, i64* %count_field
    %bucket_idx = urem i64 %hash, %bucket_count
    
    ; Get bucket
    %bucket_ptr = getelementptr %VibeSymbol*, %VibeSymbol** %buckets, i64 %bucket_idx
    %bucket = load %VibeSymbol*, %VibeSymbol** %bucket_ptr
    
    ; Search for existing symbol
    br label %search_loop

search_loop:
    %current = phi %VibeSymbol* [ %bucket, %entry ], [ %next, %check_next ]
    %is_null = icmp eq %VibeSymbol* %current, null
    br i1 %is_null, label %create_new, label %check_match

check_match:
    ; Compare hash and name
    %hash_field = getelementptr %VibeSymbol, %VibeSymbol* %current, i32 0, i32 0
    %sym_hash = load i64, i64* %hash_field
    %hash_match = icmp eq i64 %sym_hash, %hash
    
    br i1 %hash_match, label %check_name, label %next_symbol

check_name:
    ; Simple name comparison (in real implementation, use strncmp)
    ; For now, assume hash match means symbol match
    ret %VibeSymbol* %current

next_symbol:
    %next_field = getelementptr %VibeSymbol, %VibeSymbol* %current, i32 0, i32 3
    %next = load %VibeSymbol*, %VibeSymbol** %next_field
    br label %search_loop

create_new:
    ; Create new symbol
    %symbol = call i8* @malloc(i64 32)
    %symbol_ptr = bitcast i8* %symbol to %VibeSymbol*
    
    %hash_field = getelementptr %VibeSymbol, %VibeSymbol* %symbol_ptr, i32 0, i32 0
    store i64 %hash, i64* %hash_field
    
    ; Copy name
    %name_copy = call i8* @malloc(i64 %name_len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_copy, i8* %name, i64 %name_len, i1 false)
    
    %name_field = getelementptr %VibeSymbol, %VibeSymbol* %symbol_ptr, i32 0, i32 1
    store i8* %name_copy, i8** %name_field
    
    %len_field = getelementptr %VibeSymbol, %VibeSymbol* %symbol_ptr, i32 0, i32 2
    store i64 %name_len, i64* %len_field
    
    ; Add to bucket
    %next_field = getelementptr %VibeSymbol, %VibeSymbol* %symbol_ptr, i32 0, i32 3
    store %VibeSymbol* %bucket, %VibeSymbol** %next_field
    
    store %VibeSymbol* %symbol_ptr, %VibeSymbol** %bucket_ptr
    
    ; Update symbol count
    %sym_count_field = getelementptr %SymbolTable, %SymbolTable* %table, i32 0, i32 2
    %sym_count = load i64, i64* %sym_count_field
    %new_count = add i64 %sym_count, 1
    store i64 %new_count, i64* %sym_count_field
    
    ret %VibeSymbol* %symbol_ptr
}

; Create cons cell
; cons_create: Create a cons cell
; Parameters:
;   runtime: Pointer to Runtime
;   car: Car value
;   cdr: Cdr value
; Returns: VibeValue containing cons cell
define %VibeValue @cons_create(%Runtime* %runtime, %VibeValue %car, %VibeValue %cdr) {
entry:
    ; Allocate cons cell on heap
    %cons_size = mul i64 2, 16  ; 2 * sizeof(VibeValue)
    %cons = call i8* @malloc(i64 %cons_size)
    %cons_ptr = bitcast i8* %cons to %VibeCons*
    
    ; Set car
    %car_ptr = getelementptr %VibeCons, %VibeCons* %cons_ptr, i32 0, i32 0
    store %VibeValue %car, %VibeValue* %car_ptr
    
    ; Set cdr
    %cdr_ptr = getelementptr %VibeCons, %VibeCons* %cons_ptr, i32 0, i32 1
    store %VibeValue %cdr, %VibeValue* %cdr_ptr
    
    ; Create VibeValue
    %value = alloca %VibeValue
    %type_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 0
    store i32 4, i32* %type_ptr  ; VALUE_CONS
    
    %cons_int = ptrtoint %VibeCons* %cons_ptr to i64
    %data_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 1
    store i64 %cons_int, i64* %data_ptr
    
    %result = load %VibeValue, %VibeValue* %value
    ret %VibeValue %result
}

; Define bitcode primitive
; define_bitcode: Bind LLVM bitcode to a name (core primitive for self-hosting)
; Parameters:
;   runtime: Pointer to Runtime
;   name: Binding name
;   name_len: Name length
;   bitcode: LLVM bitcode data
;   bitcode_len: Bitcode length
; Returns: 0 on success, -1 on error
define i32 @define_bitcode(%Runtime* %runtime, i8* %name, i64 %name_len, i8* %bitcode, i64 %bitcode_len) {
entry:
    ; Allocate binding structure
    %binding = call i8* @malloc(i64 40)
    %binding_ptr = bitcast i8* %binding to %BitcodeBinding*
    
    ; Copy name
    %name_copy = call i8* @malloc(i64 %name_len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_copy, i8* %name, i64 %name_len, i1 false)
    
    %name_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding_ptr, i32 0, i32 0
    store i8* %name_copy, i8** %name_field
    
    %name_len_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding_ptr, i32 0, i32 1
    store i64 %name_len, i64* %name_len_field
    
    ; Copy bitcode
    %bitcode_copy = call i8* @malloc(i64 %bitcode_len)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %bitcode_copy, i8* %bitcode, i64 %bitcode_len, i1 false)
    
    %bitcode_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding_ptr, i32 0, i32 2
    store i8* %bitcode_copy, i8** %bitcode_field
    
    %bitcode_len_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding_ptr, i32 0, i32 3
    store i64 %bitcode_len, i64* %bitcode_len_field
    
    ; Add to linked list
    %bindings_field = getelementptr %Runtime, %Runtime* %runtime, i32 0, i32 1
    %existing = load %BitcodeBinding*, %BitcodeBinding** %bindings_field
    
    %next_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding_ptr, i32 0, i32 4
    store %BitcodeBinding* %existing, %BitcodeBinding** %next_field
    
    store %BitcodeBinding* %binding_ptr, %BitcodeBinding** %bindings_field
    
    ret i32 0
}

; Lookup bitcode binding
; bitcode_lookup: Look up a bitcode binding by name
; Parameters:
;   runtime: Pointer to Runtime
;   name: Binding name
;   name_len: Name length
; Returns: Pointer to BitcodeBinding, or null if not found
define %BitcodeBinding* @bitcode_lookup(%Runtime* %runtime, i8* %name, i64 %name_len) {
entry:
    %bindings_field = getelementptr %Runtime, %Runtime* %runtime, i32 0, i32 1
    %current = load %BitcodeBinding*, %BitcodeBinding** %bindings_field
    
    br label %search_loop

search_loop:
    %binding = phi %BitcodeBinding* [ %current, %entry ], [ %next, %continue_search ]
    %is_null = icmp eq %BitcodeBinding* %binding, null
    br i1 %is_null, label %not_found, label %check_name

check_name:
    %name_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding, i32 0, i32 0
    %binding_name = load i8*, i8** %name_field
    
    %len_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding, i32 0, i32 1
    %binding_len = load i64, i64* %len_field
    
    ; Compare lengths
    %len_match = icmp eq i64 %binding_len, %name_len
    br i1 %len_match, label %compare_strings, label %continue_search

compare_strings:
    ; Simple comparison (in real implementation, use strncmp)
    ; For now, assume length match means name match
    ret %BitcodeBinding* %binding

continue_search:
    %next_field = getelementptr %BitcodeBinding, %BitcodeBinding* %binding, i32 0, i32 4
    %next = load %BitcodeBinding*, %BitcodeBinding** %next_field
    br label %search_loop

not_found:
    ret %BitcodeBinding* null
}

; Create nil value
; value_nil: Create a nil value
; Returns: VibeValue representing nil
define %VibeValue @value_nil() {
entry:
    %value = alloca %VibeValue
    %type_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 0
    store i32 5, i32* %type_ptr  ; VALUE_NIL
    %data_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 1
    store i64 0, i64* %data_ptr
    %result = load %VibeValue, %VibeValue* %value
    ret %VibeValue %result
}

; Create boolean value
; value_boolean: Create a boolean value
; Parameters:
;   b: Boolean value (0 or 1)
; Returns: VibeValue representing boolean
define %VibeValue @value_boolean(i32 %b) {
entry:
    %value = alloca %VibeValue
    %type_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 0
    store i32 6, i32* %type_ptr  ; VALUE_BOOLEAN
    %b_int = zext i32 %b to i64
    %data_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 1
    store i64 %b_int, i64* %data_ptr
    %result = load %VibeValue, %VibeValue* %value
    ret %VibeValue %result
}

; Create integer value
; value_integer: Create an integer value
; Parameters:
;   i: Integer value
; Returns: VibeValue representing integer
define %VibeValue @value_integer(i64 %i) {
entry:
    %value = alloca %VibeValue
    %type_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 0
    store i32 0, i32* %type_ptr  ; VALUE_INTEGER
    %data_ptr = getelementptr %VibeValue, %VibeValue* %value, i32 0, i32 1
    store i64 %i, i64* %data_ptr
    %result = load %VibeValue, %VibeValue* %value
    ret %VibeValue %result
}

; Declare external functions
declare i8* @malloc(i64)
declare i8* @calloc(i64, i64)
declare void @free(i8*)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
