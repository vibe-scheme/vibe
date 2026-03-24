# Chat 0020: Memory Leaks, Visitor Pattern, and Label Handling

**Date**: 2025-12-28  
**Model**: Cursor Composer 1  

## Session Overview

This session focused on fixing multiple critical issues in the bootstrap compiler:
1. Memory leak in `codegen_dsl_call` when error paths didn't free allocated memory
2. Local values leaking between function definitions
3. Visitor pattern implementation for `llvm:label` nodes with proper context restoration
4. Parser improvements for atom value isolation
5. Debug output safety improvements

## Issues Fixed

### 1. Memory Leak in `codegen_dsl_call`

**Problem**: The `args_array` was allocated with `malloc` in the `eval_args` block, but error paths at lines 5484 (`func_check`) and 5488 (`func_type_check`) branched directly to `error` without freeing the allocated memory.

**Solution**: Added an `error_with_free` block that frees `args_array` before branching to `error`. Updated the error branches to use `error_with_free` instead of `error`.

**Files Modified**:
- `bootstrap/compiler/codegen.ll` (lines ~5484-5524)

**Key Changes**:
```llvm
build_call:
    ; Additional safety checks before calling
    %func_check = icmp eq %LLVMValueRef %func, null
    br i1 %func_check, label %error_with_free, label %check_func_type_again
    
check_func_type_again:
    %func_type_check = icmp eq %LLVMTypeRef %func_type, null
    br i1 %func_type_check, label %error_with_free, label %do_call

error_with_free:
    ; Free args_array if it was allocated before returning error
    call void @free(i8* %args_array)
    br label %error
```

### 2. Local Values Leaking Between Functions

**Problem**: The `local_values` list in the `CodeGen` structure was not being cleared when starting a new function definition. This caused bindings from previous functions (like `char`, `char_int`, `is_space`, etc.) to leak into new functions, leading to "Referring to an instruction in another function!" errors.

**Solution**: Added code to clear `local_values` at both the start and end of `codegen_define_llvm_function`.

**Files Modified**:
- `bootstrap/compiler/codegen.ll` (lines ~7230-7430)

**Key Changes**:
```llvm
define i32 @codegen_define_llvm_function(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; Clear local_values list at start of function definition
    ; This ensures bindings from previous functions don't leak into the new function
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_ptr
    ; ... rest of function ...
    
cleanup_builder:
    ; Clear local_values list at end of function definition
    %local_values_cleanup_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_cleanup_ptr
    ; ... rest of cleanup ...
}
```

### 3. Visitor Pattern for `llvm:label` Nodes

**Problem**: The `codegen_dsl_label` function was not properly implementing the visitor pattern. After processing a label body that contained a terminator (like `llvm:br`), the builder position restoration logic was broken, leading to:
- "Terminator found in the middle of a basic block!" errors
- "Basic Block does not have terminator!" errors
- Segfaults when trying to restore to terminated blocks

**Root Cause Analysis**:
- When processing `(llvm:label 'loop ...)` with siblings `(llvm:br ...)` and `(llvm:label 'skip ...)`, the `llvm:br` terminates the `loop` block
- After processing `llvm:label 'skip`, we tried to restore to the saved block (the terminated `loop` block), which is invalid
- The parser correctly creates sibling nodes, but codegen needed to handle terminated blocks properly

**Solution**: Implemented proper termination detection and restoration logic:
1. After processing label body, check if current insert block equals the label block (indicating termination)
2. If terminated, don't restore builder position (leave it where it is for the next sibling label)
3. If not terminated, restore to saved position (maintaining visitor pattern)

**Assumption**: Labels are always correctly terminated. If a label body doesn't contain a terminator, that's a syntax error and we don't need to handle it gracefully.

**Files Modified**:
- `bootstrap/compiler/codegen.ll` (lines ~6696-6750)

**Key Changes**:
```llvm
position_builder:
    ; Save current builder position before positioning at label block
    %saved_block = call %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder)
    
    ; Position builder at end of label block
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %block)
    
    ; Evaluate body expressions
    call void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %body)
    
    ; Check if label block was terminated
    %current_block_after = call %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef %builder)
    %current_block_null = icmp eq %LLVMBasicBlockRef %current_block_after, null
    br i1 %current_block_null, label %no_restore, label %check_if_terminated
    
check_if_terminated:
    %label_block_was_terminated = icmp eq %LLVMBasicBlockRef %current_block_after, %block
    br i1 %label_block_was_terminated, label %no_restore, label %check_saved_null
    
no_restore:
    ; Label block was terminated - don't restore builder position
    ; The next sibling (likely another llvm:label) will create a new block and position builder there
    br label %return_block
    
check_saved_null:
    %saved_block_null = icmp eq %LLVMBasicBlockRef %saved_block, null
    br i1 %saved_block_null, label %return_block, label %restore_position
    
restore_position:
    ; Restore builder to the position it was at before we positioned it at the label block
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %saved_block)
    br label %return_block
```

### 4. Parser Atom Value Isolation

**Problem**: Atom values in AST nodes were storing direct pointers to (potentially non-null-terminated) token buffers from the lexer. This caused issues where debug prints and string comparisons would read beyond intended boundaries, leading to concatenated atom names like `lex_current_charlexer`.

**Solution**: Modified `parse_create_atom` to always allocate new memory, copy the normalized token value, and null-terminate it before storing it in the AST node. This ensures atom values are isolated and correctly bounded.

**Files Modified**:
- `bootstrap/parser/parser.ll` (lines ~157-188)

**Key Changes**:
```llvm
; Always copy the normalized value to ensure it's isolated and null-terminated
; This prevents reading past token boundaries when tokens are adjacent in source
%copied_value_size = add i64 %normalized_len, 1  ; +1 for null terminator
%copied_value = call i8* @malloc(i64 %copied_value_size)
call void @llvm.memcpy.p0i8.p0i8.i64(i8* %copied_value, i8* %normalized_value, i64 %normalized_len, i1 false)
%null_term_ptr = getelementptr i8, i8* %copied_value, i64 %normalized_len
store i8 0, i8* %null_term_ptr

; Free the normalized value if it was newly allocated
%value_changed = icmp ne i8* %normalized_value, %value
br i1 %value_changed, label %free_normalized, label %store_copied

free_normalized:
    call void @free(i8* %normalized_value)
    br label %store_copied

store_copied:
    %node_val_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 2
    store i8* %copied_value, i8** %node_val_ptr
    %node_len_ptr = getelementptr %ASTNode, %ASTNode* %node_ptr, i32 0, i32 3
    store i64 %normalized_len, i64* %node_len_ptr
```

### 5. Debug Output Safety Improvements

**Problem**: Debug output in `codegen_dsl_resolve_local` was using `printf` on potentially non-null-terminated strings, causing incorrect output.

**Solution**: Modified debug printing to safely print names by allocating a temporary null-terminated buffer, copying the name (with its length), printing it, and then freeing the buffer.

**Files Modified**:
- `bootstrap/compiler/codegen.ll` (lines ~4892-4911)

## Verification of Parser and Codegen Architecture

### Parser Structure (Verified)
- `parse_list_tail` correctly creates sibling nodes using cons cells
- `(llvm:label 'a ...) (llvm:label 'b ...)` creates:
  - Cons 1: car = `(llvm:label 'a ...)`, cdr = Cons 2
  - Cons 2: car = `(llvm:label 'b ...)`, cdr = null
- ✅ Parser correctly creates sibling nodes, not parent-child relationships

### Codegen Visitor Pattern (Fixed)
- `codegen_eval_dsl_body` iterates through list sequentially, calling `codegen_eval_dsl_expr` on each car
- When `llvm:label` is encountered, `codegen_dsl_label` is called
- `codegen_dsl_label` now:
  1. Saves current builder position (`saved_block`)
  2. Creates/gets label block and positions builder there
  3. Processes label body
  4. Checks if label block was terminated
  5. If terminated: doesn't restore (leaves builder for next sibling)
  6. If not terminated: restores to saved position
- ✅ Visitor pattern properly implemented with context save/restore

## Testing Results

### Before Fixes
- Segfaults when compiling `bootstrap/lexer/lexer.vibe`
- "Referring to an instruction in another function!" errors
- "Terminator found in the middle of a basic block!" errors
- "Basic Block does not have terminator!" errors
- Atom concatenation issues (`lex_current_charlexer`)

### After Fixes
- ✅ No segfaults - compilation completes successfully (exit code 0)
- ✅ No "Referring to an instruction in another function!" errors
- ✅ No "Terminator found in the middle of a basic block!" errors
- ✅ No "Basic Block does not have terminator!" errors
- ✅ Atom concatenation fixed - parser properly isolates atom values
- ⚠️ Remaining issue: "Invalid instruction with no BB" in bitcode (separate issue to investigate)

## Files Modified

1. **`bootstrap/compiler/codegen.ll`**:
   - Added `error_with_free` block in `codegen_dsl_call` to free `args_array` on error paths
   - Added `local_values` clearing at start and end of `codegen_define_llvm_function`
   - Fixed `codegen_dsl_label` to properly handle terminated blocks in visitor pattern
   - Improved debug output safety in `codegen_dsl_resolve_local`
   - Added debug output to `codegen_get_llvm_function`

2. **`bootstrap/parser/parser.ll`**:
   - Modified `parse_create_atom` to always copy and null-terminate atom values
   - Ensures atom values are isolated and don't read past token boundaries

3. **`AGENTS.md`**:
   - Added note about rebuilding bootstrap compiler before testing after `.ll` file changes

4. **`test.vibe`**:
   - Minor formatting change

## Key Technical Insights

1. **Memory Management**: Always free allocated memory on all code paths, including error paths
2. **Scope Management**: Clear scope-specific data structures (like `local_values`) when entering/exiting scopes (like function definitions)
3. **Visitor Pattern**: When processing AST nodes that modify context (like `llvm:label`), save context before processing and restore after, but only if safe to do so
4. **Terminated Blocks**: In LLVM, once a basic block has a terminator, no more instructions can be added. When restoring builder position, we must detect if the target block is terminated
5. **Parser Isolation**: AST nodes should own their data - copying and isolating values prevents issues with shared buffers

## Remaining Issues

1. **"Invalid instruction with no BB"**: The generated bitcode has an instruction that's not in any basic block. This is a separate issue from the visitor pattern and needs further investigation. It may be related to:
   - Phi nodes not being in the correct basic block
   - Instructions being created outside of any function
   - Builder position being incorrect when creating certain instructions

## Related Documentation

- `docs/design/bootstrap-plan.md` - Overall bootstrap compiler architecture
- `docs/chats/0019-lexer-parser-codegen-architecture-refactor.md` - Previous architectural work
- `AGENTS.md` - Updated with rebuild reminder

## Next Steps

1. Investigate "Invalid instruction with no BB" error in generated bitcode
2. Continue testing with more complex `lexer.vibe` functions
3. Consider adding validation to detect instructions created outside basic blocks earlier
