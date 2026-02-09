; Bootstrap FFI System for Vibe - Dynamic library loading
; Provides platform abstraction for dlopen/dlsym via POSIX APIs
; Used by codegen for llvm:define-ffi-function support
; This is the bootstrap (.ll) equivalent of kernel/ffi.vibe

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%LibraryHandle = type opaque
%FunctionPtr = type i8*

; Load dynamic library
; ffi_load_library: Load a dynamic library
; Parameters:
;   path: Library path (null-terminated string)
; Returns: Library handle, or null on error
define %LibraryHandle* @ffi_load_library(i8* %path) {
entry:
    ; Platform-specific implementation
    ; On macOS: use dlopen
    ; On Linux: use dlopen
    ; On Windows: use LoadLibrary
    
    ; For now, declare as external - will be implemented in platform-specific code
    ; This is a placeholder that will call the actual platform function
    %handle = call %LibraryHandle* @ffi_dlopen(i8* %path)
    ret %LibraryHandle* %handle
}

; Get symbol from library
; ffi_get_symbol: Get a symbol (function pointer) from a library
; Parameters:
;   handle: Library handle
;   symbol: Symbol name (null-terminated string)
; Returns: Function pointer, or null on error
define %FunctionPtr @ffi_get_symbol(%LibraryHandle* %handle, i8* %symbol) {
entry:
    ; Platform-specific implementation
    ; On macOS/Linux: use dlsym
    ; On Windows: use GetProcAddress
    
    %func = call %FunctionPtr @ffi_dlsym(%LibraryHandle* %handle, i8* %symbol)
    ret %FunctionPtr %func
}

; Platform-specific function declarations
; These call the actual system functions

; dlopen wrapper (macOS/Linux) - calls actual dlopen from libdl
; dlopen flags: RTLD_LAZY = 1, RTLD_NOW = 2
define %LibraryHandle* @ffi_dlopen(i8* %path) {
entry:
    %handle = call i8* @dlopen(i8* %path, i32 1)  ; RTLD_LAZY
    %handle_ptr = bitcast i8* %handle to %LibraryHandle*
    ret %LibraryHandle* %handle_ptr
}

; dlsym wrapper (macOS/Linux) - calls actual dlsym from libdl
define %FunctionPtr @ffi_dlsym(%LibraryHandle* %handle, i8* %symbol) {
entry:
    %handle_ptr = bitcast %LibraryHandle* %handle to i8*
    %func = call i8* @dlsym(i8* %handle_ptr, i8* %symbol)
    ret %FunctionPtr %func
}

; External declarations for POSIX dynamic library functions
declare i8* @dlopen(i8*, i32)
declare i8* @dlsym(i8*, i8*)
