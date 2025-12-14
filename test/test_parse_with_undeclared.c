#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "llvm-c/Core.h"
#include "llvm-c/Support.h"

int main() {
    // Create LLVM context
    LLVMContextRef context = LLVMContextCreate();
    if (!context) {
        fprintf(stderr, "Failed to create LLVM context\n");
        return 1;
    }
    
    // Test IR with undeclared constant reference
    const char* ir_text = 
        "target datalayout = \"e-m:o-i64:64-f80:128-n8:16:32:64-S128\"\n"
        "target triple = \"x86_64-apple-macosx10.15.0\"\n\n"
        "define void @test_func(i8* %arg) {\n"
        "entry:\n"
        "  %ptr = getelementptr [14 x i8], [14 x i8]* @undeclared_constant, i32 0, i32 0\n"
        "  call i32 (i8*, ...) @printf(i8* %ptr, i8* %arg)\n"
        "  ret void\n"
        "}\n";
    
    size_t ir_len = strlen(ir_text);
    
    // Create memory buffer
    LLVMMemoryBufferRef buffer = LLVMCreateMemoryBufferWithMemoryRangeCopy(
        ir_text, ir_len, "test_module");
    
    if (!buffer) {
        fprintf(stderr, "Failed to create memory buffer\n");
        LLVMContextDispose(context);
        return 1;
    }
    
    // Try to parse IR
    LLVMModuleRef module = NULL;
    char* error_msg = NULL;
    int parse_result = LLVMParseIRInContext(context, buffer, &module, &error_msg);
    
    if (parse_result != 0) {
        fprintf(stderr, "Parse failed with error: %s\n", error_msg ? error_msg : "unknown");
        if (error_msg) {
            LLVMDisposeMessage(error_msg);
        }
        LLVMDisposeMemoryBuffer(buffer);
        LLVMContextDispose(context);
        return 1;
    }
    
    if (!module) {
        fprintf(stderr, "Parse succeeded but module is NULL\n");
        LLVMDisposeMemoryBuffer(buffer);
        LLVMContextDispose(context);
        return 1;
    }
    
    // Check if function was parsed successfully
    LLVMValueRef func = LLVMGetNamedFunction(module, "test_func");
    if (!func) {
        fprintf(stderr, "Function 'test_func' not found in parsed module\n");
        LLVMDisposeModule(module);
        LLVMDisposeMemoryBuffer(buffer);
        LLVMContextDispose(context);
        return 1;
    }
    
    // Check if function is actually a function
    if (!LLVMValueIsAFunction(func)) {
        fprintf(stderr, "Value 'test_func' is not a function\n");
        LLVMDisposeModule(module);
        LLVMDisposeMemoryBuffer(buffer);
        LLVMContextDispose(context);
        return 1;
    }
    
    printf("SUCCESS: Function parsed successfully even with undeclared constant reference\n");
    printf("Function structure was created, references can be resolved later\n");
    
    // Cleanup
    LLVMDisposeModule(module);
    LLVMDisposeMemoryBuffer(buffer);
    LLVMContextDispose(context);
    
    return 0;
}
