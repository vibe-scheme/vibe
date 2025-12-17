; Shared Type Definitions for Vibe Bootstrap Compiler
; All modules should use these type definitions to ensure consistency
; All functions use snake_case naming convention

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.15.0"

; LLVM opaque types (pointers to LLVM structures)
%LLVMContextRef = type i8*
%LLVMModuleRef = type i8*
%LLVMTypeRef = type i8*
%LLVMValueRef = type i8*
%LLVMBasicBlockRef = type i8*
%LLVMBuilderRef = type i8*

; Token structure
; struct Token {
;     i32 type;           // Token type
;     i8* value;          // Token value (for identifiers, strings, numbers)
;     i64 value_len;      // Length of value
;     i32 line;           // Line number
;     i32 column;         // Column number
; }
%Token = type { i32, i8*, i64, i32, i32 }

; Lexer state structure
; struct Lexer {
;     i8* source;         // Source code string
;     i64 source_len;     // Length of source
;     i64 pos;            // Current position
;     i32 line;           // Current line number
;     i32 column;         // Current column number
; }
%Lexer = type { i8*, i64, i64, i32, i32 }

; AST node structure
; struct ASTNode {
;     i32 type;           // Node type
;     i32 atom_type;      // Atom type (if AST_ATOM): TOKEN_IDENTIFIER, TOKEN_NUMBER, etc.
;     i8* value;          // Value (for atoms)
;     i64 value_len;      // Value length
;     %ASTNode* car;      // First element (for lists)
;     %ASTNode* cdr;      // Rest of list (for lists)
;     i32 line;           // Line number
;     i32 column;         // Column number
; }
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }

; Parser state structure
; struct Parser {
;     %Lexer* lexer;      // Lexer instance
;     %Token* current;    // Current token
; }
%Parser = type { %Lexer*, %Token* }

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

; Code generator state structure
; struct CodeGen {
;     i8* ir_buffer;        // Buffer for generated IR text
;     i64 buffer_size;      // Current buffer size
;     i64 buffer_pos;       // Current position in buffer
;     i32 string_counter;   // Counter for unique string constant names
;     i32 label_counter;    // Counter for unique label names
;     %LLVMContextRef context;  // LLVM context
;     %LLVMModuleRef module;    // LLVM module
;     %LLVMBuilderRef builder;  // LLVM builder
;     %LLVMValueRef current_function;  // Current function being generated (for DSL)
;     %ASTNode* param_names;    // List of (name . param_value) pairs for DSL parameter resolution
;     %ASTNode* local_values;   // List of (name . value) pairs for DSL local value tracking
;     %ASTNode* function_types; // List of (name . type) pairs for function type tracking
;     %ASTNode* constants;      // List of (name . LLVMValueRef) pairs for constant tracking
;     %ASTNode* types;          // List of (name . LLVMTypeRef) pairs for type tracking
;     %ASTNode* llvm_functions; // List of (name . (func_value . func_type)) pairs for function tracking
; }
%CodeGen = type { i8*, i64, i64, i32, i32, %LLVMContextRef, %LLVMModuleRef, %LLVMBuilderRef, %LLVMValueRef, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode* }

; FFI types (from ffi.ll)
; Library handle (opaque pointer)
%LibraryHandle = type opaque

; Function pointer type (generic)
%FunctionPtr = type i8*

; FFI call signature
; struct FFICallSignature {
;     i32 return_type;    // Return type
;     i32* arg_types;     // Array of argument types
;     i32 arg_count;      // Number of arguments
; }
%FFICallSignature = type { i32, i32*, i32 }
