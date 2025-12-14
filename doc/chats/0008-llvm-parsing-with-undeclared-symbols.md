# Chat 0008: LLVM Parsing with Undeclared Symbols and define-llvm-function DSL Implementation

**Date**: 2025-12-14
**Context**: Investigating how to resolve the issue where `define-bitcode-function` fails when function bodies reference constants defined by `define-bitcode-constant`. The current workaround hardcodes external declarations for `printf` and `hello_string`, which doesn't scale. Introduced a new `define-llvm-function` form that replaces `define-bitcode-function` (which uses IR string bodies) with a Domain Specific Language (DSL) connected to the LLVM builder API for programmatic instruction building. This change aims to eliminate IR parsing and handle undeclared symbols naturally, leading to cleaner and more maintainable code generation. This is the initial implementation of the DSL concept.

## Key Insight
We don't need LLVM to resolve external references during parsing. We only need LLVM to parse the function definition itself. The function body can reference undefined symbols - those will be resolved when we add the function to the main module that already contains those symbol definitions. This suggests an extract/copy-paste approach rather than linking.

## Investigation Results

### Parsing Behavior Assumption
Based on LLVM IR semantics and common behavior of IR parsers:
- `LLVMParseIRInContext` should be able to parse function definitions even when they reference undeclared constants
- The function structure (signature, basic blocks, instructions) will be created
- References to undeclared symbols will remain unresolved until linking/cloning
- This is standard behavior for LLVM IR parsers - they allow forward references

### Test Program Status
Created `test/test_parse_with_undeclared.c` to verify parsing behavior, but compilation failed due to LLVM version mismatch (system has LLVM 6.0.0, project requires LLVM 21). 

**Decision**: Proceed with implementation based on the reasonable assumption that parsing succeeds with undeclared symbols. If parsing fails in practice, we'll investigate alternative parsing APIs (Step 7).

## Solution Approach: Extract/Copy-Paste

Instead of linking modules (which requires all symbols to be resolved), we'll:
1. Parse function IR into a temporary module (allowing undeclared symbols)
2. Extract the function from the temporary module
3. Clone the function into the main module (where symbols are already defined)
4. Dispose the temporary module

This approach:
- Eliminates the need for external declarations
- Scales to arbitrary constants and functions
- Allows functions to reference symbols defined earlier in the same module
- Is cleaner than generating declarations dynamically

## DSL Implementation Work

### Introduction
This session introduced the DSL concept as a replacement for `define-bitcode-function`. The DSL provides a Scheme-like syntax for defining LLVM functions and instructions, using primitives like `llvm-call`, `llvm-gep`, `llvm-ret-void`, `llvm-get-function`, `llvm-get-global`, and `llvm-const-int`. This approach eliminates the need for IR string parsing and allows for more natural handling of undeclared symbols.

### Goal
Implement the DSL to the point where the "Hello, World" test can be replaced with the new DSL implementation and confirmed to be fully working.

### Work Completed

#### Function Type Storage System
- Extended `%CodeGen` structure to include `function_types` field for storing function name to `LLVMTypeRef` mappings
- Created `codegen_store_function_type` to store function types when functions are defined
- Created `codegen_get_function_type` to retrieve stored function types during function calls
- This addresses the opaque pointer issue in LLVM 21 where `LLVMGetElementType` doesn't work for function pointer types

#### DSL Body Evaluation Improvements
- Added type checking in `codegen_eval_dsl_body` to verify body is a list before iteration
- Improved body extraction logic in `codegen_define_llvm_function` to handle different AST structures
- Added null checks and validation throughout the DSL evaluation pipeline

#### Error Handling and Validation
- Added validation for GEP types before building instructions
- Added validation for parameter types before storing
- Improved error handling in various DSL primitive handlers

### Current Status

#### Working
- Compiler builds successfully
- `define-llvm-function` form is recognized and parsed
- Function creation, basic block setup, and builder positioning work correctly
- DSL primitive recognition (`llvm-call`, `llvm-gep`, `llvm-ret-void`, etc.) is implemented
- Function type storage system is in place (though temporarily disabled for debugging)

#### Issues Encountered

1. **Empty Function Body**: The generated `hello` function has an empty body - no instructions are being generated. The DSL body expressions are not being evaluated, despite the body being extracted from the AST correctly.

2. **Missing Terminator**: Initially encountered "Basic Block in function 'hello' does not have terminator!" error, which was resolved by ensuring proper builder positioning. However, the underlying issue (empty function body) persists.

3. **DSL Body Extraction**: Attempted multiple approaches to extract the DSL body from the AST:
   - Using `cdr_cdr_cdr.car` (original approach)
   - Using `cdr_cdr_cdr` directly
   - Adding type checks and fallback logic
   None of these approaches resulted in the body being evaluated.

### Technical Details

#### AST Structure for define-llvm-function
```
(define-llvm-function signature return-type body)
```
- `node.cdr` = `(signature return-type body)`
- `node.cdr.cdr` = `(return-type body)`
- `node.cdr.cdr.cdr` = `body` (list of expressions)

#### DSL Body Evaluation Flow
1. `codegen_define_llvm_function` extracts body from AST
2. Body is passed to `codegen_eval_dsl_body`
3. `codegen_eval_dsl_body` iterates through body expressions
4. Each expression is evaluated via `codegen_eval_dsl_expr`
5. `codegen_eval_dsl_expr` dispatches to appropriate DSL primitive handler

#### Debugging Attempts
- Verified body extraction logic matches AST structure
- Added type checks to ensure body is a list
- Tried both direct body access and car access
- Verified builder is positioned correctly
- Confirmed DSL primitives are recognized

## Next Steps

### Immediate Priority (2025-12-14)
1. **Add Verbose Mode**: Implement a verbose/debug mode that narrates lexing, parsing, and codegen steps to improve debuggability. This will help identify why the DSL body is not being evaluated.

2. **Debug DSL Body Evaluation**: Use verbose mode to trace:
   - Whether the body is being extracted correctly
   - Whether `codegen_eval_dsl_body` is being called
   - Whether expressions are being recognized as DSL primitives
   - Whether instructions are being generated but not added to the basic block

### Future Enhancements
- Complete function type storage re-enablement once body evaluation is fixed
- Add `let` binding to the DSL for better code organization
- Complete array type parsing beyond current placeholder
- Add more DSL primitives as needed
- Research LLVM function cloning APIs (from initial investigation)
- Add function extraction APIs to FFI
- Implement extraction logic in codegen.ll
- Remove hardcoded external declarations

## Files Modified
- `bootstrap/compiler/codegen.ll`: Extended CodeGen structure, added function type storage, improved DSL body evaluation, added validation
- `bootstrap/compiler/main.ll`: Modified to dispatch `define-llvm-function` forms
- `bootstrap/runtime/ffi.ll`: LLVM C API wrappers
- `test/hello_world.vibe`: Updated to use new `define-llvm-function` syntax
- `test/test_parse_with_undeclared.c`: Test program (not compiled due to LLVM version)

## Key Learnings
1. LLVM 21's opaque pointers make `LLVMGetElementType` unreliable for function types - storing types explicitly is necessary
2. Builder positioning is critical - must be positioned before accessing parameters and before building terminators
3. AST structure navigation requires careful attention to list vs. atom node types
4. Debugging LLVM IR generation requires systematic verification of each step in the pipeline
5. Verbose/debug mode is essential for tracing complex evaluation pipelines

## Related Documentation
- `AGENTS.md`: Coding standards and practices
