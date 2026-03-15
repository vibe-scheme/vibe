; Bootstrap Code Generator for Vibe
; Generates LLVM IR from AST nodes
; All functions use snake_case naming convention
;
; MIGRATION NOTE: This code generator currently uses text IR generation.
; Future work will integrate LLVM C API via FFI for direct bitcode generation.
; The migration strategy is:
; 1. Keep text IR generation working (current state) ✓
; 2. Add LLVM API calls alongside (parallel implementation) - TODO
; 3. Switch to LLVM API by default (new default) - TODO
; 4. Keep text IR as fallback (for debugging) - TODO

target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-darwin"

; Forward declarations from types.ll
; Types are defined in bootstrap/types/types.ll and linked via llvm-link
%ASTNode = type { i32, i32, i8*, i64, %ASTNode*, %ASTNode*, i32, i32 }

; Forward declarations for LLVM types (from ffi.ll)
%LLVMContextRef = type i8*
%LLVMModuleRef = type i8*
%LLVMTypeRef = type i8*
%LLVMValueRef = type i8*
%LLVMBasicBlockRef = type i8*
%LLVMBuilderRef = type i8*
%LLVMTargetRef = type i8*
%LLVMTargetMachineRef = type i8*

; CodeGen structure - extended to include LLVM context/module handles and DSL evaluation
; Fields:
;   ir_buffer: Buffer for generated IR text (for backward compatibility during migration)
;   buffer_size: Current buffer size
;   buffer_pos: Current position in buffer
;   string_counter: Counter for unique string constant names
;   label_counter: Counter for unique label names
;   llvm_context: LLVM context handle
;   llvm_module: LLVM module handle
;   llvm_builder: LLVM builder handle (for generating instructions in main function)
;   current_function: LLVMValueRef for function currently being built (for DSL evaluation)
;   param_names: ASTNode* list of (name . param_value) pairs for parameter name mapping
;   local_values: ASTNode* list of (name . LLVMValueRef) pairs for local value binding
;   function_types: ASTNode* list of (name . LLVMTypeRef) pairs for function type mapping
;   constants: ASTNode* list of (name . LLVMValueRef) pairs for constant tracking
;   types: ASTNode* list of (name . LLVMTypeRef) pairs for type tracking
;   llvm_functions: ASTNode* list of (name . (func_value . func_type)) pairs for function tracking
%CodeGen = type { i8*, i64, i64, i32, i32, %LLVMContextRef, %LLVMModuleRef, %LLVMBuilderRef, %LLVMValueRef, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode*, %ASTNode* }

; Forward declarations for FFI types (from ffi.ll)
%LibraryHandle = type opaque
%FunctionPtr = type i8*

; Forward declarations for LLVM FFI functions (from ffi.ll)
declare i32 @llvm_ffi_init()
declare %LLVMContextRef @llvm_create_context()
declare void @llvm_dispose_context(%LLVMContextRef)
declare %LLVMModuleRef @llvm_create_module(%LLVMContextRef, i8*)
declare void @llvm_dispose_module(%LLVMModuleRef)
declare void @llvm_set_target(%LLVMModuleRef, i8*)
declare void @llvm_set_data_layout(%LLVMModuleRef, i8*)
declare %LLVMTypeRef @llvm_get_int1_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef)
declare %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef, i32)
declare %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef, i32)
declare %LLVMTypeRef @llvm_get_struct_type(%LLVMContextRef, %LLVMTypeRef*, i32, i32)
declare %LLVMTypeRef @llvm_create_named_struct_type(%LLVMContextRef, i8*)
declare void @llvm_set_struct_body(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)
declare %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef, %LLVMTypeRef*, i32, i32)
declare %LLVMValueRef @llvm_create_constant_string(%LLVMContextRef, i8*, i32, i32)
declare %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef, i64, i32)
declare %LLVMValueRef @llvm_create_constant_null(%LLVMTypeRef)
declare %LLVMValueRef @llvm_add_function(%LLVMModuleRef, i8*, %LLVMTypeRef)
declare i32 @llvm_count_params(%LLVMValueRef)
declare %LLVMValueRef @llvm_get_param(%LLVMValueRef, i32)
declare void @llvm_set_value_name(%LLVMValueRef, i8*)
declare %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef, i8*)
declare %LLVMBasicBlockRef @llvm_get_first_basic_block(%LLVMValueRef)
declare %LLVMBasicBlockRef @llvm_get_next_basic_block(%LLVMBasicBlockRef)
declare i8* @llvm_get_basic_block_name(%LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef)
declare %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef)
declare void @llvm_dispose_builder(%LLVMBuilderRef)
declare void @llvm_position_builder_at_end(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMBasicBlockRef @llvm_get_insert_block(%LLVMBuilderRef)
declare %LLVMValueRef @llvm_build_ret_void(%LLVMBuilderRef)
declare %LLVMValueRef @llvm_build_ret(%LLVMBuilderRef, %LLVMValueRef)
declare %LLVMValueRef @llvm_build_call(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, %LLVMValueRef*, i32, i8*)
declare %LLVMValueRef @llvm_build_bitcast(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare void @llvm_build_store(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef)
declare %LLVMValueRef @llvm_build_load(%LLVMBuilderRef, %LLVMTypeRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_icmp(%LLVMBuilderRef, i32, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_br(%LLVMBuilderRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_build_cond_br(%LLVMBuilderRef, %LLVMValueRef, %LLVMBasicBlockRef, %LLVMBasicBlockRef)
declare %LLVMValueRef @llvm_build_zext(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_build_add(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_sub(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_mul(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_and(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_or(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_alloca(%LLVMBuilderRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_build_trunc(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_build_select(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_phi(%LLVMBuilderRef, %LLVMTypeRef, i8*)
declare void @llvm_add_incoming(%LLVMValueRef, %LLVMValueRef*, %LLVMBasicBlockRef*, i32)
declare %LLVMValueRef @llvm_get_undef(%LLVMTypeRef)
declare %LLVMValueRef @llvm_build_insert_value(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i32, i8*)
declare %LLVMValueRef @llvm_build_extract_value(%LLVMBuilderRef, %LLVMValueRef, i32, i8*)
declare %LLVMValueRef @llvm_build_urem(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_udiv(%LLVMBuilderRef, %LLVMValueRef, %LLVMValueRef, i8*)
declare %LLVMValueRef @llvm_build_ptrtoint(%LLVMBuilderRef, %LLVMValueRef, %LLVMTypeRef, i8*)
declare %LLVMValueRef @llvm_add_global(%LLVMModuleRef, %LLVMTypeRef, i8*)
declare void @llvm_set_initializer(%LLVMValueRef, %LLVMValueRef)
declare void @llvm_set_global_constant(%LLVMValueRef, i32)
declare void @llvm_set_linkage(%LLVMValueRef, i32)
declare i32 @llvm_parse_ir_in_context(%LLVMContextRef, i8*, i64, %LLVMModuleRef*)
declare i32 @llvm_write_bitcode_to_file(%LLVMModuleRef, i8*)
declare i8* @llvm_get_default_target_triple()
declare i32 @llvm_get_target_from_triple(i8*, %LLVMTargetRef*, i8**)
declare %LLVMTargetMachineRef @llvm_create_target_machine(%LLVMTargetRef, i8*, i8*, i8*, i32, i32, i32)
declare i32 @llvm_target_machine_emit_to_file(%LLVMTargetMachineRef, %LLVMModuleRef, i8*, i32, i8**)
declare void @llvm_dispose_target_machine(%LLVMTargetMachineRef)
declare %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef, i8*)
declare %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef, i8*)
declare i32 @llvm_link_modules2(%LLVMModuleRef, %LLVMModuleRef)
declare i32 @llvm_verify_module(%LLVMModuleRef, i32, i8**)
declare i32 @llvm_print_module_to_file(%LLVMModuleRef, i8*, i8**)
declare %LLVMTypeRef @llvm_type_of(%LLVMValueRef)
declare %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef)
declare %LibraryHandle* @ffi_load_library(i8*)
declare %FunctionPtr @ffi_get_symbol(%LibraryHandle*, i8*)
declare i32 @open(i8*, i32, ...)
declare i64 @write(i32, i8*, i32)
declare i32 @close(i32)

; codegen_init: defined in codegen.vibe
declare %CodeGen* @codegen_init(i8*)

; codegen_dispose: defined in codegen.vibe
declare void @codegen_dispose(%CodeGen*)

; Append string to IR buffer
; codegen_append: Append a string to the IR buffer
; Parameters:
;   cg: Pointer to CodeGen structure
;   str: String to append
;   len: Length of string
; codegen_append: defined in codegen.vibe
declare void @codegen_append(%CodeGen*, i8*, i64)

; codegen_string_literal: defined in codegen.vibe
declare i8* @codegen_string_literal(%CodeGen*, i8*, i64)

; codegen_append_string_constant: defined in codegen.vibe
declare void @codegen_append_string_constant(%CodeGen*, i8*, i8*, i64)

; codegen_append_escaped_string: defined in codegen.vibe
declare void @codegen_append_escaped_string(%CodeGen*, i8*, i64)

; Handle define-bitcode-type AST node
; codegen_define_llvm_type: Generate LLVM type definition using direct LLVM API
; codegen_define_llvm_type: Migrated to kernel/codegen.vibe
declare i32 @codegen_define_llvm_type(%CodeGen* %cg, %ASTNode* %node)

; codegen_append_type_fields: Migrated to kernel/codegen.vibe
declare void @codegen_append_type_fields(%CodeGen* %cg, %ASTNode* %fields)

; codegen_define_llvm_constant: Migrated to kernel/codegen.vibe
declare i32 @codegen_define_llvm_constant(%CodeGen* %cg, %ASTNode* %node)

; OLD PARSING CODE REMOVED - Now using direct LLVM API
; The following code was removed as it's no longer needed:
; - parse_constant_old and all its IR building code
; - link_constant and module linking code  
; - All the old parsing/linking infrastructure
; We now create constants directly using:
; - codegen_resolve_type_string to get LLVMTypeRef
; - llvm_create_constant_string to create the constant value
; - llvm_add_global to create the global
; - llvm_set_initializer, llvm_set_global_constant, llvm_set_linkage to configure it
; - codegen_store_constant to store it for later lookup

; codegen_create_pointer_node: defined in codegen.vibe
declare %ASTNode* @codegen_create_pointer_node(i8*)

; codegen_store_constant: defined in codegen.vibe
declare void @codegen_store_constant(%CodeGen*, i8*, i64, %LLVMValueRef)

; Get constant by name
; codegen_get_constant: defined in codegen.vibe
declare %LLVMValueRef @codegen_get_constant(%CodeGen*, i8*, i64)

; codegen_is_array_type: defined in codegen.vibe
declare i32 @codegen_is_array_type(%LLVMTypeRef)

; codegen_eval_dsl_expr: Evaluate DSL expressions (llvm-call, llvm-get-function, etc.)
; This function is defined later in the file (around line 4004)

; codegen_collect_field_types: defined in codegen.vibe
declare i32 @codegen_collect_field_types(%CodeGen* %cg, %ASTNode* %fields, %LLVMTypeRef* %types_array, i32 %max_fields)

; DUPLICATE codegen_define_llvm_type REMOVED - the correct version is at line 568
; DUPLICATE codegen_append_type_fields REMOVED - the correct version is at line 629

; OLD PARSING CODE REMOVED - All the old IR building, parsing, and linking code has been deleted
; This code was replaced with direct LLVM API calls:
; - For constants: llvm_create_constant_string, llvm_add_global, llvm_set_initializer, etc.
; - For types: llvm_get_struct_type with field types collected via codegen_collect_field_types

; DUPLICATE codegen_create_pointer_node REMOVED - the correct version is at line 861
; DUPLICATE codegen_store_constant REMOVED - the correct version is at line 898
; DUPLICATE codegen_get_constant REMOVED - the correct version is at line 936
; DUPLICATE codegen_is_array_type REMOVED - the correct version is at line 1024
; All duplicate functions removed - continuing with rest of file...

; Store type in types list
; codegen_store_type: Store a type name and LLVMTypeRef pair
; Parameters:
;   cg: Pointer to CodeGen structure
;   name: Type name
;   name_len: Name length
;   type: LLVMTypeRef for the type

; codegen_store_llvm_function: defined in codegen.vibe
declare void @codegen_store_llvm_function(%CodeGen*, i8*, i64, %LLVMValueRef, %LLVMTypeRef)

; codegen_get_llvm_function: Look up a function by name and return LLVMValueRef and LLVMTypeRef
; Deferred migration: complex let*/label structure causes segfault when bootstrap compiles codegen.vibe
define i32 @codegen_get_llvm_function(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef* %func_value_out, %LLVMTypeRef* %func_type_out) {
entry:
    ; Get llvm_functions list
    %llvm_functions_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 14
    %functions = load %ASTNode*, %ASTNode** %llvm_functions_ptr
    %functions_null = icmp eq %ASTNode* %functions, null
    br i1 %functions_null, label %not_found_func, label %search_loop_func

search_loop_func:
    %current_func = alloca %ASTNode*
    store %ASTNode* %functions, %ASTNode** %current_func
    br label %iterate_func

iterate_func:
    %current_val_func = load %ASTNode*, %ASTNode** %current_func
    %current_null_func = icmp eq %ASTNode* %current_val_func, null
    br i1 %current_null_func, label %not_found_func, label %check_pair_func

check_pair_func:
    %car_ptr_func = getelementptr %ASTNode, %ASTNode* %current_val_func, i32 0, i32 4
    %pair_func = load %ASTNode*, %ASTNode** %car_ptr_func
    %pair_null_func = icmp eq %ASTNode* %pair_func, null
    br i1 %pair_null_func, label %next_func, label %compare_name_func

compare_name_func:
    %pair_car_ptr_func = getelementptr %ASTNode, %ASTNode* %pair_func, i32 0, i32 4
    %name_node_func = load %ASTNode*, %ASTNode** %pair_car_ptr_func
    %name_node_null_func = icmp eq %ASTNode* %name_node_func, null
    br i1 %name_node_null_func, label %next_func, label %get_name_func

get_name_func:
    %stored_name_ptr_func = getelementptr %ASTNode, %ASTNode* %name_node_func, i32 0, i32 2
    %stored_name_func = load i8*, i8** %stored_name_ptr_func
    %stored_len_ptr_func = getelementptr %ASTNode, %ASTNode* %name_node_func, i32 0, i32 3
    %stored_len_func = load i64, i64* %stored_len_ptr_func
    %len_match_func = icmp eq i64 %stored_len_func, %name_len
    br i1 %len_match_func, label %compare_chars_func, label %next_func

compare_chars_func:
    %len_int_func = trunc i64 %name_len to i32
    %cmp_result_func = call i32 @strncmp(i8* %stored_name_func, i8* %name, i32 %len_int_func)
    %is_match_func = icmp eq i32 %cmp_result_func, 0
    br i1 %is_match_func, label %found_func, label %next_func

found_func:
    %pair_cdr_ptr_func = getelementptr %ASTNode, %ASTNode* %pair_func, i32 0, i32 5
    %value_type_pair = load %ASTNode*, %ASTNode** %pair_cdr_ptr_func
    %value_type_pair_null = icmp eq %ASTNode* %value_type_pair, null
    br i1 %value_type_pair_null, label %not_found_func, label %extract_func_value

extract_func_value:
    %value_type_car_ptr = getelementptr %ASTNode, %ASTNode* %value_type_pair, i32 0, i32 4
    %func_value_node = load %ASTNode*, %ASTNode** %value_type_car_ptr
    %func_value_node_null = icmp eq %ASTNode* %func_value_node, null
    br i1 %func_value_node_null, label %not_found_func, label %extract_func_type

extract_func_type:
    %value_type_cdr_ptr = getelementptr %ASTNode, %ASTNode* %value_type_pair, i32 0, i32 5
    %func_type_node = load %ASTNode*, %ASTNode** %value_type_cdr_ptr
    %func_type_node_null = icmp eq %ASTNode* %func_type_node, null
    br i1 %func_type_node_null, label %not_found_func, label %cast_back_func

cast_back_func:
    %func_value_ptr_field = getelementptr %ASTNode, %ASTNode* %func_value_node, i32 0, i32 2
    %func_value_ptr = load i8*, i8** %func_value_ptr_field
    %func_value_ref = bitcast i8* %func_value_ptr to %LLVMValueRef
    %func_type_ptr_field = getelementptr %ASTNode, %ASTNode* %func_type_node, i32 0, i32 2
    %func_type_ptr = load i8*, i8** %func_type_ptr_field
    %func_type_ref = bitcast i8* %func_type_ptr to %LLVMTypeRef
    store %LLVMValueRef %func_value_ref, %LLVMValueRef* %func_value_out
    store %LLVMTypeRef %func_type_ref, %LLVMTypeRef* %func_type_out
    ret i32 1

next_func:
    %cdr_ptr_func = getelementptr %ASTNode, %ASTNode* %current_val_func, i32 0, i32 5
    %cdr_func = load %ASTNode*, %ASTNode** %cdr_ptr_func
    store %ASTNode* %cdr_func, %ASTNode** %current_func
    br label %iterate_func

not_found_func:
    ret i32 0
}

; Handle define-bitcode-function AST node (migrated to codegen.vibe)
declare i32 @codegen_define_bitcode_function(%CodeGen* %cg, %ASTNode* %node)

; codegen_append_typed_params: Migrated to kernel/codegen.vibe
declare void @codegen_append_typed_params(%CodeGen* %cg, %ASTNode* %params)

; codegen_write_typed_params_to_buffer: Migrated to kernel/codegen.vibe
declare void @codegen_write_typed_params_to_buffer(i8* %buf, i64* %pos, %ASTNode* %params)

; codegen_define_bitcode: Migrated to kernel/codegen.vibe
declare i32 @codegen_define_bitcode(%CodeGen* %cg, %ASTNode* %node)

; codegen_append_function_def: Migrated to kernel/codegen.vibe
declare void @codegen_append_function_def(%CodeGen* %cg, i8* %name, %ASTNode* %params, i8* %body, i64 %body_len)

; codegen_append_params: defined in codegen.vibe
declare void @codegen_append_params(%CodeGen* %cg, %ASTNode* %params)

; Generate function call
; codegen_call: Generate a function call
; Parameters:
;   cg: Pointer to CodeGen structure
;   func_name: Function name
;   args: AST node list of arguments
; Returns: 0 on success, -1 on error
define i32 @codegen_call(%CodeGen* %cg, i8* %func_name, %ASTNode* %args) {
entry:
    ; Get LLVM module and builder
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    ; Check if we can use LLVM API (both module and builder must be non-null)
    %module_null = icmp eq %LLVMModuleRef %module, null
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    %either_null = or i1 %module_null, %builder_null
    br i1 %either_null, label %text_only, label %use_llvm_api
    
use_llvm_api:
    br label %lookup_func
    
lookup_func:
    ; Get function name length
    %func_name_len = call i64 @strlen(i8* %func_name)
    
    ; First check if this is a define-llvm-function function
    %func_value_storage = alloca %LLVMValueRef
    %func_type_storage = alloca %LLVMTypeRef
    %found_tracked = call i32 @codegen_get_llvm_function(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMValueRef* %func_value_storage, %LLVMTypeRef* %func_type_storage)
    %is_tracked = icmp ne i32 %found_tracked, 0
    br i1 %is_tracked, label %use_tracked_func, label %lookup_in_module
    
use_tracked_func:
    ; Use tracked function value and type
    %tracked_func = load %LLVMValueRef, %LLVMValueRef* %func_value_storage
    %tracked_func_type = load %LLVMTypeRef, %LLVMTypeRef* %func_type_storage
    br label %build_call_with_type
    
lookup_in_module:
    ; Look up function in module (for legacy functions)
    ; Note: Function names in LLVM are stored without @ prefix
    %func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %func_name)
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error_not_found, label %get_func_type_legacy
    
get_func_type_legacy:
    ; For legacy functions, get the function type from the function value
    ; llvm_type_of returns the pointer type, so we need to get the element type
    %func_ptr_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    %func_type_legacy = call %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %func_ptr_type)
    br label %build_call_with_type
    
build_call_with_type:
    %func_phi = phi %LLVMValueRef [ %tracked_func, %use_tracked_func ], [ %func, %get_func_type_legacy ]
    %func_type_phi = phi %LLVMTypeRef [ %tracked_func_type, %use_tracked_func ], [ %func_type_legacy, %get_func_type_legacy ]
    br label %build_call

error_not_found:
    ; Function not found in module - return error
    br label %return_error
    
return_error:
    ; TODO: This should not happen if functions are properly linked
    ret i32 -1
    
build_call:
    ; Use func_phi and func_type_phi from build_call_with_type
    ; Get context for types
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    
    ; For printf and other functions, we now have the function type from func_type_phi
    ; Get i32 and i8* types for argument conversion
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type, i32 0)
    
    ; Count arguments and build argument array
    ; For now, assume printf with one string argument
    ; Allocate space for one argument
    %arg_array = alloca %LLVMValueRef, i32 1
    
    ; Build argument: getelementptr to string constant
    ; First, we need to get the string constant from args
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %call_with_no_args, label %get_first_arg
    
get_first_arg:
    %arg_car_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %arg_node = load %ASTNode*, %ASTNode** %arg_car_ptr
    
    ; Check if argument is a string literal
    %arg_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 0
    %arg_type = load i32, i32* %arg_type_ptr
    %is_atom = icmp eq i32 %arg_type, 0  ; AST_ATOM
    br i1 %is_atom, label %check_string_type, label %call_with_no_args
    
check_string_type:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    %is_string = icmp eq i32 %atom_type, 3  ; TOKEN_STRING
    br i1 %is_string, label %build_string_arg, label %call_with_no_args
    
build_string_arg:
    ; Get string value and length
    %str_val_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 2
    %str_val = load i8*, i8** %str_val_ptr
    %str_len_ptr = getelementptr %ASTNode, %ASTNode* %arg_node, i32 0, i32 3
    %str_len = load i64, i64* %str_len_ptr
    
    ; Get the string constant name (should already be generated)
    %const_name = call i8* @codegen_get_string_constant_name(%CodeGen* %cg, i8* %str_val, i64 %str_len)
    
    ; Look up the global constant
    %global = call %LLVMValueRef @llvm_get_named_global(%LLVMModuleRef %module, i8* %const_name)
    %global_null = icmp eq %LLVMValueRef %global, null
    br i1 %global_null, label %call_with_no_args, label %build_gep
    
build_gep:
    ; Build getelementptr: getelementptr ([len x i8], [len x i8]* @.str.N, i32 0, i32 0)
    %len_plus_one = add i64 %str_len, 1
    %len_plus_one_int = trunc i64 %len_plus_one to i32
    %array_type = call %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %i8_type, i32 %len_plus_one_int)
    
    ; Create indices: [0, 0]
    %indices = alloca %LLVMValueRef, i32 2
    %zero_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type, i64 0, i32 0)
    %zero_idx = getelementptr %LLVMValueRef, %LLVMValueRef* %indices, i32 0
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx
    %zero_idx2 = getelementptr %LLVMValueRef, %LLVMValueRef* %indices, i32 1
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx2
    
    ; Build GEP instruction
    ; Use empty string instead of null for name (LLVMBuildGEP2 may not handle null properly)
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %gep = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %array_type, %LLVMValueRef %global, %LLVMValueRef* %indices, i32 2, i8* %empty_str)
    
    ; Validate GEP result
    %gep_null = icmp eq %LLVMValueRef %gep, null
    br i1 %gep_null, label %call_with_no_args, label %store_gep
    
store_gep:
    ; Store in argument array
    store %LLVMValueRef %gep, %LLVMValueRef* %arg_array
    br label %call_func
    
call_with_no_args:
    ; No arguments - but still need a valid pointer (even if empty)
    ; Use the arg_array which is already allocated (it's safe to pass even with count 0)
    br label %call_func
    
call_func:
    ; PHI nodes must be first in the block
    %args_count = phi i32 [ 1, %store_gep ], [ 0, %call_with_no_args ]
    %args_ptr = phi %LLVMValueRef* [ %arg_array, %store_gep ], [ %arg_array, %call_with_no_args ]
    
    ; Use func_type_phi from build_call_with_type (already has the correct function type)
    %func_type_null_check = icmp eq %LLVMTypeRef %func_type_phi, null
    br i1 %func_type_null_check, label %text_only, label %build_call_inst
    
build_call_inst:
    ; Build call instruction using func_type_phi and func_phi
    ; Use empty string instead of null for name (LLVMBuildCall2 may not handle null properly)
    %empty_str_call = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %call_result = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type_phi, %LLVMValueRef %func_phi, %LLVMValueRef* %args_ptr, i32 %args_count, i8* %empty_str_call)
    br label %done
    
text_only:
    ; Generate: call void @func_name(args...)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.call_void, i32 0, i32 0), i64 9)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.space, i32 0, i32 0), i64 1)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.at_sign, i32 0, i32 0), i64 1)
    %func_name_len_text = call i64 @strlen(i8* %func_name)
    call void @codegen_append(%CodeGen* %cg, i8* %func_name, i64 %func_name_len_text)
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.lparen, i32 0, i32 0), i64 1)
    
    ; Generate arguments
    call void @codegen_append_call_args(%CodeGen* %cg, %ASTNode* %args)
    
    call void @codegen_append(%CodeGen* %cg, i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.rparen, i32 0, i32 0), i64 1)
    br label %done
    
done:
    ret i32 0
}


; codegen_define_string_constant_only: defined in codegen.vibe
declare i8* @codegen_define_string_constant_only(%CodeGen*, i8*, i64)

; codegen_get_string_constant_name: defined in codegen.vibe
declare i8* @codegen_get_string_constant_name(%CodeGen*, i8*, i64)

; codegen_append_call_args: Migrated to kernel/codegen.vibe
declare void @codegen_append_call_args(%CodeGen* %cg, %ASTNode* %args)

; codegen_collect_string_constants: defined in codegen.vibe
declare void @codegen_collect_string_constants(%CodeGen*, %ASTNode*)

; codegen_collect_string_constants_from_args: defined in codegen.vibe
declare void @codegen_collect_string_constants_from_args(%CodeGen*, %ASTNode*)

; Generate main function
; codegen_main: Generate main function with top-level expressions
; Parameters:
;   cg: Pointer to CodeGen structure
;   exprs: AST node list of top-level expressions
; Returns: 0 on success, -1 on error
; Note: If exprs is null/empty (only definitions, no executable expressions),
;       no main function is generated (library module).
; codegen_main: Migrated to kernel/codegen.vibe
declare i32 @codegen_main(%CodeGen* %cg, %ASTNode* %exprs)

; codegen_append_top_level_exprs: Migrated to kernel/codegen.vibe
declare void @codegen_append_top_level_exprs(%CodeGen* %cg, %ASTNode* %exprs)

; codegen_get_ir: defined in codegen.vibe
declare i8* @codegen_get_ir(%CodeGen*)

; codegen_extract_function_name: defined in codegen.vibe
declare i8* @codegen_extract_function_name(i8*, i64)

; Note: Function cloning APIs are not available in LLVM 21 C API.
; We use module linking instead, which automatically resolves symbols between modules.

; Parse complete function definition from IR text
; codegen_parse_function_ir: Parse a complete function definition from IR text and add to module
; Parameters:
;   cg: Pointer to CodeGen structure
;   func_ir: Complete function definition as IR text (including signature and body)
;   func_ir_len: Length of IR text
; Returns: 0 on success, -1 on error
; NOTE: This wraps the function in a minimal module, parses it into a temporary module,
; extracts the function, clones it to the main module, and disposes the temp module.
; The function can reference undeclared symbols - LLVMParseIRInContext handles
; undeclared symbols gracefully, and they will be resolved when the module is linked
; to the main module where those symbols are already defined.
; codegen_parse_function_ir: Migrated to kernel/codegen.vibe
declare i32 @codegen_parse_function_ir(%CodeGen* %cg, i8* %func_ir, i64 %func_ir_len)

; codegen_write_ir_text: defined in codegen.vibe
declare i32 @codegen_write_ir_text(%CodeGen* %cg, i8* %filename)

; codegen_write_bitcode: defined in codegen.vibe
declare i32 @codegen_write_bitcode(%CodeGen* %cg, i8* %filename)

; Write object file
; codegen_write_object_file: Write module directly to object file using TargetMachine API
; Parameters:
;   cg: Pointer to CodeGen structure
;   filename: Output file path (null-terminated string)
; Returns: 0 on success, -1 on error
; codegen_write_object_file: Migrated to kernel/codegen.vibe
declare i32 @codegen_write_object_file(%CodeGen* %cg, i8* %filename)

; Forward declaration for printf (from ffi.ll)
declare i32 @printf(i8*, ...)

; String literals
@.str.target_triple = external constant [39 x i8]
@.str.printf_decl = private unnamed_addr constant [42 x i8] c"declare i32 @printf(i8* nocapture, ...)\0A\0A\00"
@.str.debug_prefix_lexer = private unnamed_addr constant [9 x i8] c"[LEXER] \00"
@.str.debug_prefix_parser = private unnamed_addr constant [10 x i8] c"[PARSER] \00"
@.str.debug_prefix_codegen = private unnamed_addr constant [11 x i8] c"[CODEGEN] \00"
@.str.debug_prefix_dsl_body = private unnamed_addr constant [12 x i8] c"[DSL-BODY] \00"
@.str.debug_prefix_dsl_expr = private unnamed_addr constant [12 x i8] c"[DSL-EXPR] \00"
@.str.debug_newline = private unnamed_addr constant [2 x i8] c"\0A\00"
@.str.debug_define_llvm_function_start = private unnamed_addr constant [39 x i8] c"codegen_define_llvm_function: starting\00"
@.str.debug_define_llvm_ffi_function_start = private unnamed_addr constant [43 x i8] c"codegen_define_llvm_ffi_function: starting\00"
@.str.debug_declare_llvm_function_start = private unnamed_addr constant [40 x i8] c"codegen_declare_llvm_function: starting\00"
@.str.debug_extracting_dsl_body = private unnamed_addr constant [29 x i8] c"Extracting DSL body from AST\00"
@.str.debug_dsl_body_extracted = private unnamed_addr constant [32 x i8] c"DSL body extracted successfully\00"
@.str.debug_evaluating_dsl_body = private unnamed_addr constant [20 x i8] c"Evaluating DSL body\00"
@.str.debug_dsl_body_expr = private unnamed_addr constant [30 x i8] c"Evaluating expression in body\00"
@.str.debug_dsl_expr_atom = private unnamed_addr constant [15 x i8] c"DSL expr: atom\00"
@.str.debug_dsl_expr_list = private unnamed_addr constant [15 x i8] c"DSL expr: list\00"
@.str.debug_dsl_primitive = private unnamed_addr constant [16 x i8] c"DSL primitive: \00"
@.str.debug_dsl_body_start = private unnamed_addr constant [29 x i8] c"codegen_eval_dsl_body: start\00"
@.str.debug_body_type_check = private unnamed_addr constant [25 x i8] c"Body type check: type=%d\00"
@.str.debug_dsl_body_done = private unnamed_addr constant [28 x i8] c"codegen_eval_dsl_body: done\00"
@.str.debug_expr_null = private unnamed_addr constant [15 x i8] c"DSL expr: null\00"
@.str.debug_expr_type = private unnamed_addr constant [18 x i8] c"DSL expr type: %d\00"
@.str.debug_unknown_primitive = private unnamed_addr constant [25 x i8] c"ERROR: Unknown primitive\00"
@.str.debug_func_eval_result = private unnamed_addr constant [32 x i8] c"Function eval result (checking)\00"
@.str.debug_get_function_result = private unnamed_addr constant [27 x i8] c"llvm-get-function result: \00"
@.str.debug_looking_up_func = private unnamed_addr constant [22 x i8] c"Looking up function: \00"
@.str.debug_null = private unnamed_addr constant [5 x i8] c"NULL\00"
@.str.debug_not_null = private unnamed_addr constant [3 x i8] c"OK\00"
@.str.debug_func_not_found_error = private unnamed_addr constant [27 x i8] c"ERROR: Function not found!\00"
@.str.debug_getting_func_type = private unnamed_addr constant [25 x i8] c"Getting function type...\00"
@.str.debug_func_type_result = private unnamed_addr constant [21 x i8] c"Function type result\00"
@.str.debug_func_type_null_error = private unnamed_addr constant [30 x i8] c"ERROR: Function type is null!\00"
@.str.debug_null_arg_error = private unnamed_addr constant [28 x i8] c"ERROR: Argument %d is null!\00"
@.str.debug_building_call = private unnamed_addr constant [27 x i8] c"Building call with %d args\00"
@.str.debug_resolving_param = private unnamed_addr constant [22 x i8] c"Resolving parameter: \00"
@.str.debug_param_names_null = private unnamed_addr constant [33 x i8] c"ERROR: param_names list is null!\00"
@.str.debug_current_func_null = private unnamed_addr constant [33 x i8] c"ERROR: current_function is null!\00"
@.str.debug_param_found = private unnamed_addr constant [24 x i8] c"Parameter found in list\00"
@.str.debug_param_value_null = private unnamed_addr constant [40 x i8] c"ERROR: Parameter value null at index %d\00"
@.str.debug_param_value_ok = private unnamed_addr constant [31 x i8] c"Parameter value OK at index %d\00"
@.str.debug_getting_param_by_index = private unnamed_addr constant [30 x i8] c"Getting parameter at index %d\00"
@.str.debug_param_count = private unnamed_addr constant [29 x i8] c"Function has %d parameter(s)\00"
@.str.debug_collected_param_count = private unnamed_addr constant [31 x i8] c"Collected %d parameter type(s)\00"
@.str.debug_collect_params_start = private unnamed_addr constant [35 x i8] c"codegen_collect_param_types: start\00"
@.str.debug_params_null = private unnamed_addr constant [28 x i8] c"ERROR: params list is null!\00"
@.str.debug_processing_param = private unnamed_addr constant [27 x i8] c"Processing parameter %d...\00"
@.str.debug_param_pair_null = private unnamed_addr constant [27 x i8] c"ERROR: param_pair is null!\00"
@.str.debug_pair_cdr_null_collect = private unnamed_addr constant [25 x i8] c"ERROR: pair_cdr is null!\00"
@.str.debug_type_node_null = private unnamed_addr constant [26 x i8] c"ERROR: type_node is null!\00"
@.str.debug_resolving_type = private unnamed_addr constant [17 x i8] c"Resolving type: \00"
@.str.debug_type_resolve_failed = private unnamed_addr constant [28 x i8] c"ERROR: Type resolve failed!\00"
@.str.debug_param_lookup_still_null = private unnamed_addr constant [46 x i8] c"ERROR: param_lookup still null before return!\00"
@.str.debug_returning_param_value = private unnamed_addr constant [37 x i8] c"Returning parameter value (non-null)\00"
@.str.debug_returning_from_eval = private unnamed_addr constant [39 x i8] c"codegen_eval_dsl_expr returning param:\00"
@.str.debug_storing_arg = private unnamed_addr constant [30 x i8] c"Storing argument %d in array:\00"
@.str.debug_stored_value_null = private unnamed_addr constant [35 x i8] c"ERROR: Stored value is null at %d!\00"
@.str.debug_value_stored_ok = private unnamed_addr constant [32 x i8] c"Value stored successfully at %d\00"
@.str.debug_extracting_args_list = private unnamed_addr constant [24 x i8] c"Extracting args list...\00"
@.str.debug_checking_i8_ptr = private unnamed_addr constant [26 x i8] c"Checking for i8* match...\00"
@.str.debug_i8_ptr_cmp_result = private unnamed_addr constant [26 x i8] c"i8* comparison result: %d\00"
@.str.debug_i8_ptr_bar_cmp_result = private unnamed_addr constant [28 x i8] c"|i8*| comparison result: %d\00"
@.str.debug_looking_up_global = private unnamed_addr constant [20 x i8] c"Looking up global: \00"
@.str.debug_local = private unnamed_addr constant [8 x i8] c"local: \00"
@.str.debug_global_not_found = private unnamed_addr constant [25 x i8] c"ERROR: Global not found!\00"
@.str.warn_unresolved_atom = private unnamed_addr constant [54 x i8] c"[WARN] Unresolved atom (len=%lld): all lookups failed\00"
@.str.debug_params_list_null = private unnamed_addr constant [48 x i8] c"[DEBUG] params_list passed to build_param=null!\00"
@.str.debug_params_list_ok = private unnamed_addr constant [43 x i8] c"[DEBUG] params_list passed to build_param=\00"
@.str.debug_name_colon_space = private unnamed_addr constant [8 x i8] c" name: \00"
@.str.debug_local_not_found = private unnamed_addr constant [18 x i8] c"Local not found: \00"
@.str.debug_global_found = private unnamed_addr constant [17 x i8] c"Global found: OK\00"
@.str.debug_creating_constant = private unnamed_addr constant [25 x i8] c"Creating constant: name=\00"
@.str.debug_constant_created = private unnamed_addr constant [28 x i8] c"Constant created, pointer: \00"
@.str.debug_storing_constant = private unnamed_addr constant [24 x i8] c"Storing constant: name=\00"
@.str.debug_constant_stored = private unnamed_addr constant [27 x i8] c"Constant stored, pointer: \00"
@.str.debug_looking_up_constant = private unnamed_addr constant [27 x i8] c"Looking up constant: name=\00"
@.str.debug_evaluating_value = private unnamed_addr constant [14 x i8] c" - evaluating\00"
@.str.debug_value_eval_failed = private unnamed_addr constant [21 x i8] c" - value eval FAILED\00"
@.str.debug_let_star_recognized = private unnamed_addr constant [8 x i8] c"let* OK\00"
@.str.debug_let_star_body_struct = private unnamed_addr constant [67 x i8] c"[LET*-BODY] body=%p car.type=%d cdr=%p cdr.car.type=%d cdr.cdr=%p\0A\00"
@.str.debug_let_star_body_iter = private unnamed_addr constant [35 x i8] c"[LET*-BODY] iter N=%d car.type=%d\0A\00"
@.str.debug_let_star_not_binding = private unnamed_addr constant [44 x i8] c"[LET*-BIND] not_binding->eval_body type=%d\0A\00"
@.str.debug_processing_binding = private unnamed_addr constant [19 x i8] c"Processing binding\00"
@.str.debug_extracted_name = private unnamed_addr constant [17 x i8] c"Extracted name: \00"
@.str.debug_binding_local_value = private unnamed_addr constant [22 x i8] c"Binding local value: \00"
@.str.debug_no_more_bindings = private unnamed_addr constant [34 x i8] c"No more bindings, evaluating body\00"
@.str.debug_processing_bindings_list = private unnamed_addr constant [28 x i8] c"Processing bindings list...\00"
@.str.debug_binding_pair_null = private unnamed_addr constant [22 x i8] c"Binding pair is null!\00"
@.str.debug_binding_type_check = private unnamed_addr constant [28 x i8] c"Binding type check: type=%d\00"
@.str.debug_binding_not_list = private unnamed_addr constant [32 x i8] c"Binding is not a list, skipping\00"
@.str.debug_binding_name_null = private unnamed_addr constant [22 x i8] c"Binding name is null!\00"
@.str.debug_name_type_check = private unnamed_addr constant [25 x i8] c"Name type check: type=%d\00"
@.str.debug_name_not_atom = private unnamed_addr constant [26 x i8] c"Binding name is not atom!\00"
@.str.debug_binding_val_type = private unnamed_addr constant [27 x i8] c"binding_val type check: %d\00"
@.str.debug_bindings_list_type = private unnamed_addr constant [34 x i8] c"bindings_list type check: type=%d\00"
@.str.debug_value_expr_type = private unnamed_addr constant [31 x i8] c"value_expr type check: type=%d\00"
@.str.debug_binding_val_car_type = private unnamed_addr constant [36 x i8] c"binding_val.car type check: type=%d\00"
@.str.debug_value_wrapper_type = private unnamed_addr constant [34 x i8] c"value_wrapper type check: type=%d\00"
@.str.debug_constant_found = private unnamed_addr constant [26 x i8] c"Constant found, pointer: \00"
@.str.debug_constant_not_found = private unnamed_addr constant [26 x i8] c"Constant not found: name=\00"
@.str.debug_pointer_value = private unnamed_addr constant [13 x i8] c", pointer=%p\00"
@.str.debug_type_fmt = private unnamed_addr constant [3 x i8] c"%s\00"
@.str.debug_type_len = private unnamed_addr constant [17 x i8] c"Type length: %ld\00"
@.str.debug_name_len_bounds_check = private unnamed_addr constant [46 x i8] c"ERROR: name_len out of bounds: %ld (max 1000)\00"
@.str.debug_name_null_check = private unnamed_addr constant [29 x i8] c"ERROR: name pointer is null!\00"
@.str.debug_atom_val_ptr = private unnamed_addr constant [31 x i8] c"Atom val pointer: %p, len: %ld\00"
@.str.debug_atom_first_bytes = private unnamed_addr constant [27 x i8] c"Atom first bytes: %c%c%c%c\00"
@.str.debug_looking_up_function = private unnamed_addr constant [27 x i8] c"Looking up function: name=\00"
@.str.debug_function_list_size = private unnamed_addr constant [29 x i8] c"Function list has %d entries\00"
@.str.debug_function_found = private unnamed_addr constant [19 x i8] c"Function found: OK\00"
@.str.debug_function_not_found = private unnamed_addr constant [21 x i8] c"Function not found: \00"
@.str.debug_checking_array = private unnamed_addr constant [22 x i8] c"Checking for array...\00"
@.str.debug_reached_array_check = private unnamed_addr constant [26 x i8] c"Reached check_array block\00"
@.str.debug_first_char = private unnamed_addr constant [21 x i8] c"First char: %d (dec)\00"
@.str.debug_checking_builder = private unnamed_addr constant [19 x i8] c"Checking builder: \00"
@.str.debug_checking_func_type = private unnamed_addr constant [21 x i8] c"Checking func_type: \00"
@.str.debug_checking_func = private unnamed_addr constant [16 x i8] c"Checking func: \00"
@.str.debug_checking_args_array = private unnamed_addr constant [22 x i8] c"Checking args_array: \00"
@.str.debug_first_arg_value = private unnamed_addr constant [18 x i8] c"First arg value: \00"
@.str.debug_arg_value_at = private unnamed_addr constant [18 x i8] c"Arg value at %d: \00"
@.str.debug_index_out_of_range = private unnamed_addr constant [54 x i8] c"ERROR: Index %d out of range (function has %d params)\00"
@.str.debug_getting_index_node = private unnamed_addr constant [22 x i8] c"Getting index node...\00"
@.str.debug_checking_pair_cdr = private unnamed_addr constant [21 x i8] c"Checking pair cdr...\00"
@.str.debug_param_atom_type = private unnamed_addr constant [26 x i8] c"Param value atom_type: %d\00"
@.str.debug_param_not_number_type = private unnamed_addr constant [39 x i8] c"ERROR: Param value not number type: %d\00"
@.str.debug_creating_pair = private unnamed_addr constant [28 x i8] c"Creating pair with index %d\00"
@.str.debug_pair_cdr_null = private unnamed_addr constant [25 x i8] c"ERROR: Pair cdr is null!\00"
@.str.debug_pair_cdr_lost = private unnamed_addr constant [37 x i8] c"ERROR: Pair cdr lost after creation!\00"
@.str.debug_checking_pair = private unnamed_addr constant [20 x i8] c"Checking pair cdr: \00"
@.str.debug_pair_cdr_null_before_store = private unnamed_addr constant [37 x i8] c"ERROR: Pair cdr null before storing!\00"
@.str.debug_comparing_names = private unnamed_addr constant [24 x i8] c"Comparing with stored: \00"
@.str.debug_empty_str = private unnamed_addr constant [8 x i8] c"<empty>\00"
@.str.debug_building_param_name = private unnamed_addr constant [27 x i8] c"Building param name node: \00"
@.str.debug_retrieving_name_node = private unnamed_addr constant [31 x i8] c"Retrieving name node from pair\00"
@.str.debug_name_node_type = private unnamed_addr constant [31 x i8] c"Name node type=%d atom_type=%d\00"
@.str.module_name = external constant [5 x i8]
@.str.target_triple_value = external constant [19 x i8]
@.str.data_layout_value = external constant [34 x i8]
@.str.space_at = private unnamed_addr constant [3 x i8] c" @\00"
@.str.newline_close_brace = private unnamed_addr constant [4 x i8] c"\0A}\0A\00"
@.str.main_name = private unnamed_addr constant [5 x i8] c"main\00"
@.str.debug_codegen_skip_main = private unnamed_addr constant [61 x i8] c"[CODEGEN] codegen_main: exprs null or empty - skipping main\0A\00"
@.str.debug_codegen_generating_main = private unnamed_addr constant [61 x i8] c"[CODEGEN] codegen_main: exprs has content - generating main\0A\00"
@.str.data_layout_prefix = private unnamed_addr constant [22 x i8] c"target datalayout = \22\00"
@.str.data_layout_suffix = private unnamed_addr constant [3 x i8] c"\22\0A\00"
@.str.target_triple_prefix = private unnamed_addr constant [18 x i8] c"target triple = \22\00"
@.str.target_triple_suffix = private unnamed_addr constant [4 x i8] c"\22\0A\0A\00"
@.str.entry_block_name = private unnamed_addr constant [6 x i8] c"entry\00"
@.str.define_void = private unnamed_addr constant [12 x i8] c"define void\00"
@.str.lparen = private unnamed_addr constant [2 x i8] c"(\00"
@.str.rparen = private unnamed_addr constant [2 x i8] c")\00"
@.str.rparen_brace = private unnamed_addr constant [4 x i8] c") {\00"
@.str.close_brace = private unnamed_addr constant [2 x i8] c"}\00"
@.str.i8_ptr = private unnamed_addr constant [4 x i8] c"i8*\00"
@.str.percent = external constant [2 x i8]
@.str.comma_space = external constant [3 x i8]
@.str.call_void = private unnamed_addr constant [10 x i8] c"call void\00"
@.str.define_main = private unnamed_addr constant [21 x i8] c"define i32 @main() {\00"
@.str.ret_zero = private unnamed_addr constant [12 x i8] c"  ret i32 0\00"
@.str.type_equals = external constant [8 x i8]
@.str.lbrace = external constant [3 x i8]
@.str.rbrace = external constant [2 x i8]
@.str.newline = external constant [2 x i8]
@.str.at_sign = external constant [2 x i8]
@.str.constant_equals = external constant [12 x i8]
@.str.space = external constant [2 x i8]
@.str.define = private unnamed_addr constant [8 x i8] c"define \00"
@.str.c_quote_open = external constant [3 x i8]
@.str.quote = external constant [2 x i8]
@.str.backslash_00 = private unnamed_addr constant [4 x i8] c"\\00\00"
@.str.backslash_quote = private unnamed_addr constant [3 x i8] c"\\\22\00"
@.str.backslash_backslash = private unnamed_addr constant [3 x i8] c"\\\\\00"
@.str.func_not_found_after_link = private unnamed_addr constant [42 x i8] c"ERROR: Function not found after linking: \00"
@.str.func_not_found_in_call = private unnamed_addr constant [36 x i8] c"ERROR: Function not found in call: \00"
@.str.processing_call = private unnamed_addr constant [27 x i8] c"Processing function call: \00"
@.str.func_name_extraction_failed = private unnamed_addr constant [47 x i8] c"ERROR: Failed to extract function name from IR\00"
@.str.extracting_from_ir = private unnamed_addr constant [32 x i8] c"Extracting function name from: \00"
@.str.extracted_name = private unnamed_addr constant [26 x i8] c"Extracted function name: \00"
@.str.reached_verify_after_link = private unnamed_addr constant [33 x i8] c"DEBUG: Reached verify_after_link\00"
@.str.about_to_link = private unnamed_addr constant [22 x i8] c"About to link modules\00"
@.str.link_succeeded = private unnamed_addr constant [33 x i8] c"DEBUG: Link succeeded (result=0)\00"
@.str.link_failed = private unnamed_addr constant [31 x i8] c"DEBUG: Link failed (result!=0)\00"
@.str.external_hello_string = private unnamed_addr constant [45 x i8] c"@hello_string = external constant [14 x i8]\0A\00"
@.str.func_found_after_link = private unnamed_addr constant [36 x i8] c"DEBUG: Function found after linking\00"
@.str.printf_decl_module = private unnamed_addr constant [42 x i8] c"declare i32 @printf(i8* nocapture, ...)\0A\0A\00"
@.str.constant_decl = private unnamed_addr constant [22 x i8] c" = private constant [\00"
@.str.x_i8_c_quote = private unnamed_addr constant [10 x i8] c" x i8] c\22\00"
@.str.quote_newline = private unnamed_addr constant [3 x i8] c"\22\0A\00"
@.str.getelementptr_start = private unnamed_addr constant [16 x i8] c"getelementptr [\00"
@.str.getelementptr_open = private unnamed_addr constant [15 x i8] c"getelementptr(\00"
@.str.lbracket = private unnamed_addr constant [2 x i8] c"[\00"
@.str.x_i8_bracket_comma = private unnamed_addr constant [10 x i8] c" x i8], [\00"
@.str.x_i8_ptr_at = private unnamed_addr constant [10 x i8] c" x i8]* @\00"
@.str.getelementptr_indices = private unnamed_addr constant [15 x i8] c", i32 0, i32 0\00"
@.str.printf_name = private unnamed_addr constant [7 x i8] c"printf\00"
@.str.empty = external constant [1 x i8]
; Type strings for codegen_resolve_type_string
@.str.type_void = private unnamed_addr constant [5 x i8] c"void\00"
@.str.type_i1 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.type_i8 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.type_i8_ptr = private unnamed_addr constant [4 x i8] c"i8*\00"
@.str.type_i32 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.type_i64 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.type_i64_ptr = private unnamed_addr constant [5 x i8] c"i64*\00"
@.str.dsl_gep = private unnamed_addr constant [9 x i8] c"llvm:gep\00"
@.str.dsl_call = private unnamed_addr constant [10 x i8] c"llvm:call\00"
@.str.dsl_ret_void = private unnamed_addr constant [14 x i8] c"llvm:ret-void\00"
@.str.dsl_ret = private unnamed_addr constant [9 x i8] c"llvm:ret\00"
@.str.dsl_get_global = private unnamed_addr constant [16 x i8] c"llvm:get-global\00"
@.str.dsl_get_function = private unnamed_addr constant [18 x i8] c"llvm:get-function\00"
@.str.dsl_get_param = private unnamed_addr constant [15 x i8] c"llvm:get-param\00"
@.str.dsl_const_int = private unnamed_addr constant [15 x i8] c"llvm:const-int\00"
@.str.dsl_const_null = private unnamed_addr constant [16 x i8] c"llvm:const-null\00"
@.str.dsl_list = private unnamed_addr constant [5 x i8] c"list\00"
@.str.dsl_array = private unnamed_addr constant [11 x i8] c"llvm:array\00"
@.str.let_star = private unnamed_addr constant [5 x i8] c"let*\00"
@.str.dsl_bitcast = private unnamed_addr constant [13 x i8] c"llvm:bitcast\00"
@.str.dsl_store = private unnamed_addr constant [11 x i8] c"llvm:store\00"
@.str.dsl_load = private unnamed_addr constant [10 x i8] c"llvm:load\00"
@.str.dsl_icmp = private unnamed_addr constant [10 x i8] c"llvm:icmp\00"
@.str.dsl_br = private unnamed_addr constant [8 x i8] c"llvm:br\00"
@.str.dsl_zext = private unnamed_addr constant [10 x i8] c"llvm:zext\00"
@.str.dsl_add = private unnamed_addr constant [9 x i8] c"llvm:add\00"
@.str.dsl_or = private unnamed_addr constant [8 x i8] c"llvm:or\00"
@.str.dsl_label = private unnamed_addr constant [11 x i8] c"llvm:label\00"
@.str.dsl_alloca = private unnamed_addr constant [12 x i8] c"llvm:alloca\00"
@.str.dsl_sub = private unnamed_addr constant [9 x i8] c"llvm:sub\00"
@.str.dsl_and = private unnamed_addr constant [9 x i8] c"llvm:and\00"
@.str.dsl_mul = private unnamed_addr constant [9 x i8] c"llvm:mul\00"
@.str.dsl_trunc = private unnamed_addr constant [11 x i8] c"llvm:trunc\00"
@.str.dsl_select = private unnamed_addr constant [12 x i8] c"llvm:select\00"
@.str.dsl_phi = private unnamed_addr constant [9 x i8] c"llvm:phi\00"
@.str.dsl_undef = private unnamed_addr constant [11 x i8] c"llvm:undef\00"
@.str.dsl_insertvalue = private unnamed_addr constant [17 x i8] c"llvm:insertvalue\00"
@.str.dsl_extractvalue = private unnamed_addr constant [18 x i8] c"llvm:extractvalue\00"
@.str.dsl_urem = private unnamed_addr constant [10 x i8] c"llvm:urem\00"
@.str.dsl_udiv = private unnamed_addr constant [10 x i8] c"llvm:udiv\00"
@.str.dsl_ptrtoint = private unnamed_addr constant [14 x i8] c"llvm:ptrtoint\00"
@.str.err_label_no_terminator = private unnamed_addr constant [37 x i8] c"error: label '%s' has no terminator\0A\00"
@.str.err_entry_no_terminator = private unnamed_addr constant [55 x i8] c"error: entry block of function '%s' has no terminator\0A\00"
; Predicate string constants moved to codegen.vibe (codegen_map_predicate_string)

; ============================================================================
; Debug Logging Helpers
; ============================================================================

; debug_log_string: defined in codegen.vibe
declare void @debug_log_string(i8* %prefix, i8* %message, i64 %message_len)

; codegen_append_bytevector: defined in codegen.vibe
declare void @codegen_append_bytevector(%CodeGen*, i8*, i64)

; codegen_write_bytevector_to_buffer: defined in codegen.vibe
declare void @codegen_write_bytevector_to_buffer(i8*, i64*, i8*, i64)

; ============================================================================
; DSL Evaluation Infrastructure
; ============================================================================

; codegen_resolve_type_string: Parse type string and return LLVMTypeRef
define %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %type_str, i64 %type_len) {
entry:
    %type_str_null_check = icmp eq i8* %type_str, null
    %type_len_zero_check = icmp eq i64 %type_len, 0
    %type_invalid_check = or i1 %type_str_null_check, %type_len_zero_check
    br i1 %type_invalid_check, label %error, label %check_context
    
check_context:
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %error, label %check_void
    
check_void:
    %is_void_len = icmp eq i64 %type_len, 4
    br i1 %is_void_len, label %check_void_str, label %check_i1
    
check_void_str:
    %void_str = getelementptr [5 x i8], [5 x i8]* @.str.type_void, i32 0, i32 0
    %void_cmp = call i32 @strncmp(i8* %type_str, i8* %void_str, i32 4)
    %is_void = icmp eq i32 %void_cmp, 0
    br i1 %is_void, label %return_void, label %check_i1
    
return_void:
    %void_type = call %LLVMTypeRef @llvm_get_void_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %void_type
    
check_i1:
    %is_i1_len = icmp eq i64 %type_len, 2
    br i1 %is_i1_len, label %check_i1_str, label %check_i8
    
check_i1_str:
    %i1_str = getelementptr [3 x i8], [3 x i8]* @.str.type_i1, i32 0, i32 0
    %i1_cmp = call i32 @strncmp(i8* %type_str, i8* %i1_str, i32 2)
    %is_i1 = icmp eq i32 %i1_cmp, 0
    br i1 %is_i1, label %return_i1, label %check_i8
    
return_i1:
    %i1_type = call %LLVMTypeRef @llvm_get_int1_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i1_type
    
check_i8:
    %is_i8_len = icmp eq i64 %type_len, 2
    br i1 %is_i8_len, label %check_i8_str, label %check_i8_ptr
    
check_i8_str:
    %i8_str = getelementptr [3 x i8], [3 x i8]* @.str.type_i8, i32 0, i32 0
    %i8_cmp = call i32 @strncmp(i8* %type_str, i8* %i8_str, i32 2)
    %is_i8 = icmp eq i32 %i8_cmp, 0
    br i1 %is_i8, label %return_i8, label %check_i8_ptr
    
check_i8_ptr:
    %is_i8_ptr_len = icmp eq i64 %type_len, 3
    br i1 %is_i8_ptr_len, label %check_i8_ptr_str, label %check_i32
    
check_i8_ptr_str:
    %i8_ptr_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i8_ptr, i32 0, i32 0
    %i8_ptr_cmp = call i32 @strncmp(i8* %type_str, i8* %i8_ptr_str, i32 3)
    %is_i8_ptr = icmp eq i32 %i8_ptr_cmp, 0
    br i1 %is_i8_ptr, label %return_i8_ptr, label %check_i32
    
return_i8:
    %i8_type = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i8_type
    
return_i8_ptr:
    %i8_type_base = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %i8_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i8_type_base, i32 0)
    ret %LLVMTypeRef %i8_ptr_type
    
check_i32:
    %is_i32_len = icmp eq i64 %type_len, 3
    br i1 %is_i32_len, label %check_i32_str, label %check_i64
    
check_i32_str:
    %i32_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i32, i32 0, i32 0
    %i32_cmp = call i32 @strncmp(i8* %type_str, i8* %i32_str, i32 3)
    %is_i32 = icmp eq i32 %i32_cmp, 0
    br i1 %is_i32, label %return_i32, label %check_i64
    
return_i32:
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i32_type
    
check_i64:
    %is_i64_ptr_len = icmp eq i64 %type_len, 4
    br i1 %is_i64_ptr_len, label %check_i64_ptr_str, label %check_i64_len
    
check_i64_ptr_str:
    %i64_ptr_str = getelementptr [5 x i8], [5 x i8]* @.str.type_i64_ptr, i32 0, i32 0
    %i64_ptr_cmp = call i32 @strncmp(i8* %type_str, i8* %i64_ptr_str, i32 4)
    %is_i64_ptr = icmp eq i32 %i64_ptr_cmp, 0
    br i1 %is_i64_ptr, label %return_i64_ptr, label %check_array
    
return_i64_ptr:
    %i64_type_base = call %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef %context)
    %i64_ptr_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %i64_type_base, i32 0)
    ret %LLVMTypeRef %i64_ptr_type
    
check_i64_len:
    %is_i64_len = icmp eq i64 %type_len, 3
    br i1 %is_i64_len, label %check_i64_str, label %check_array
    
check_i64_str:
    %i64_str = getelementptr [4 x i8], [4 x i8]* @.str.type_i64, i32 0, i32 0
    %i64_cmp = call i32 @strncmp(i8* %type_str, i8* %i64_str, i32 3)
    %is_i64 = icmp eq i32 %i64_cmp, 0
    br i1 %is_i64, label %return_i64, label %check_array
    
return_i64:
    %i64_type = call %LLVMTypeRef @llvm_get_int64_type(%LLVMContextRef %context)
    ret %LLVMTypeRef %i64_type
    
check_array:
    %first_char = load i8, i8* %type_str
    %is_bracket = icmp eq i8 %first_char, 91
    br i1 %is_bracket, label %parse_array, label %check_named_type
    
check_named_type:
    %last_char_idx = sub i64 %type_len, 1
    %last_char_ptr = getelementptr i8, i8* %type_str, i64 %last_char_idx
    %last_char = load i8, i8* %last_char_ptr
    %is_pointer = icmp eq i8 %last_char, 42
    br i1 %is_pointer, label %lookup_named_type_ptr, label %lookup_named_type_direct
    
lookup_named_type_ptr:
    %name_len_ptr_val = sub i64 %type_len, 1
    br label %lookup_named_type_common
    
lookup_named_type_direct:
    %name_len_direct_val = add i64 %type_len, 0
    br label %lookup_named_type_common
    
lookup_named_type_common:
    %name_len = phi i64 [ %name_len_ptr_val, %lookup_named_type_ptr ], [ %name_len_direct_val, %lookup_named_type_direct ]
    %is_pointer_flag = phi i1 [ %is_pointer, %lookup_named_type_ptr ], [ %is_pointer, %lookup_named_type_direct ]
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %type_str, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    %resolved_type = call %LLVMTypeRef @codegen_get_type(%CodeGen* %cg, i8* %name_buf, i64 %name_len)
    call void @free(i8* %name_buf)
    %resolved_null = icmp eq %LLVMTypeRef %resolved_type, null
    br i1 %resolved_null, label %error, label %check_if_pointer
    
check_if_pointer:
    br i1 %is_pointer_flag, label %create_pointer_type, label %return_named_type
    
create_pointer_type:
    %pointer_type = call %LLVMTypeRef @llvm_get_pointer_type(%LLVMTypeRef %resolved_type, i32 0)
    %pointer_null = icmp eq %LLVMTypeRef %pointer_type, null
    br i1 %pointer_null, label %error, label %return_pointer_type
    
return_pointer_type:
    ret %LLVMTypeRef %pointer_type
    
return_named_type:
    ret %LLVMTypeRef %resolved_type
    
parse_array:
    %array_start_plus1 = getelementptr i8, i8* %type_str, i64 1
    %array_len_minus1 = sub i64 %type_len, 1
    %num_start = alloca i8*
    store i8* %array_start_plus1, i8** %num_start
    %num_end = alloca i8*
    store i8* %array_start_plus1, i8** %num_end
    %num_value = alloca i32
    store i32 0, i32* %num_value
    %found_x = alloca i32
    store i32 0, i32* %found_x
    br label %find_x_pattern
    
find_x_pattern:
    %current_pos_val = load i8*, i8** %num_end
    %current_offset = ptrtoint i8* %current_pos_val to i64
    %start_offset = ptrtoint i8* %array_start_plus1 to i64
    %offset = sub i64 %current_offset, %start_offset
    %max_offset = sub i64 %array_len_minus1, 3
    %within_bounds = icmp ult i64 %offset, %max_offset
    br i1 %within_bounds, label %check_pattern, label %parse_digits
    
check_pattern:
    %current_char = load i8, i8* %current_pos_val
    %current_char_int = zext i8 %current_char to i32
    %is_digit_check = icmp uge i32 %current_char_int, 48
    %is_digit_max_check = icmp ule i32 %current_char_int, 57
    %is_valid_digit_check = and i1 %is_digit_check, %is_digit_max_check
    br i1 %is_valid_digit_check, label %check_x_pattern, label %increment_pos
    
check_x_pattern:
    %pos_plus1 = getelementptr i8, i8* %current_pos_val, i64 1
    %pos_plus2 = getelementptr i8, i8* %current_pos_val, i64 2
    %pos_plus3 = getelementptr i8, i8* %current_pos_val, i64 3
    %char1 = load i8, i8* %pos_plus1
    %char2 = load i8, i8* %pos_plus2
    %char3 = load i8, i8* %pos_plus3
    %is_space1 = icmp eq i8 %char1, 32
    %is_x = icmp eq i8 %char2, 120
    %is_space2 = icmp eq i8 %char3, 32
    %both_spaces = and i1 %is_space1, %is_space2
    %found_pattern = and i1 %both_spaces, %is_x
    br i1 %found_pattern, label %mark_found_x, label %increment_pos
    
mark_found_x:
    %num_end_pos = getelementptr i8, i8* %current_pos_val, i64 1
    store i8* %num_end_pos, i8** %num_end
    store i32 1, i32* %found_x
    br label %parse_digits
    
increment_pos:
    %next_pos = getelementptr i8, i8* %current_pos_val, i64 1
    store i8* %next_pos, i8** %num_end
    br label %find_x_pattern
    
parse_digits:
    %num_start_val = load i8*, i8** %num_start
    %num_end_val = load i8*, i8** %num_end
    %num_len_ptr = alloca i64
    %num_start_int = ptrtoint i8* %num_start_val to i64
    %num_end_int = ptrtoint i8* %num_end_val to i64
    %num_len_calc = sub i64 %num_end_int, %num_start_int
    store i64 %num_len_calc, i64* %num_len_ptr
    %num_len_val = load i64, i64* %num_len_ptr
    %num_len_zero = icmp eq i64 %num_len_val, 0
    br i1 %num_len_zero, label %error, label %convert_digits
    
convert_digits:
    %num_result = alloca i32
    store i32 0, i32* %num_result
    %digit_pos = alloca i8*
    store i8* %num_start_val, i8** %digit_pos
    %digit_count = alloca i32
    store i32 0, i32* %digit_count
    br label %digit_loop
    
digit_loop:
    %digit_pos_val = load i8*, i8** %digit_pos
    %digit_pos_end = load i8*, i8** %num_end
    %digit_pos_int = ptrtoint i8* %digit_pos_val to i64
    %digit_end_int = ptrtoint i8* %digit_pos_end to i64
    %digit_done = icmp uge i64 %digit_pos_int, %digit_end_int
    br i1 %digit_done, label %check_element_type, label %read_digit
    
read_digit:
    %digit_char = load i8, i8* %digit_pos_val
    %digit_int = zext i8 %digit_char to i32
    %is_digit = icmp uge i32 %digit_int, 48
    %is_digit_max = icmp ule i32 %digit_int, 57
    %is_valid_digit = and i1 %is_digit, %is_digit_max
    br i1 %is_valid_digit, label %accumulate_digit, label %check_element_type
    
accumulate_digit:
    %num_result_val = load i32, i32* %num_result
    %digit_value = sub i32 %digit_int, 48
    %num_result_times10 = mul i32 %num_result_val, 10
    %num_result_new = add i32 %num_result_times10, %digit_value
    store i32 %num_result_new, i32* %num_result
    %digit_pos_next = getelementptr i8, i8* %digit_pos_val, i64 1
    store i8* %digit_pos_next, i8** %digit_pos
    br label %digit_loop
    
check_element_type:
    %num_end_val_check = load i8*, i8** %num_end
    %check_pos = getelementptr i8, i8* %num_end_val_check, i64 3
    %check_char_i = load i8, i8* %check_pos
    %check_pos_plus1 = getelementptr i8, i8* %check_pos, i64 1
    %check_char_8 = load i8, i8* %check_pos_plus1
    %check_pos_plus2 = getelementptr i8, i8* %check_pos, i64 2
    %check_char_bracket = load i8, i8* %check_pos_plus2
    %is_i_check = icmp eq i8 %check_char_i, 105
    %is_8_check = icmp eq i8 %check_char_8, 56
    %is_bracket_check = icmp eq i8 %check_char_bracket, 93
    %is_i8_check = and i1 %is_i_check, %is_8_check
    %is_i8_bracket = and i1 %is_i8_check, %is_bracket_check
    br i1 %is_i8_bracket, label %create_array_type, label %error
    
create_array_type:
    %num_result_final = load i32, i32* %num_result
    %i8_type_arr = call %LLVMTypeRef @llvm_get_int8_type(%LLVMContextRef %context)
    %array_type = call %LLVMTypeRef @llvm_get_array_type(%LLVMTypeRef %i8_type_arr, i32 %num_result_final)
    ret %LLVMTypeRef %array_type
    
error:
    ret %LLVMTypeRef null
}

; Evaluate DSL expression and return LLVMValueRef
; codegen_eval_dsl_expr: Recursively evaluate DSL AST expression
; Parameters:
;   cg: Pointer to CodeGen structure
;   expr: AST node for DSL expression
; Returns: LLVMValueRef for expressions that produce values, null for statements
; Expression types:
;   - Atom (symbol): Look up as DSL primitive or parameter name
;   - Atom (string): String literal (for function names, etc.)
;   - Atom (number): Integer literal (not yet supported - would need to parse)
;   - List: Function call - first element is function name, rest are args
define %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %expr) {
entry:
    %expr_null = icmp eq %ASTNode* %expr, null
    br i1 %expr_null, label %return_null, label %check_type
    
return_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_expr_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
check_type:
    %expr_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 0
    %expr_type = load i32, i32* %expr_type_ptr
    
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_expr_type, i32 0, i32 0), i32 %expr_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if quote (type 2), atom (type 0), or list (type 1)
    %is_quote = icmp eq i32 %expr_type, 2  ; AST_QUOTE
    br i1 %is_quote, label %handle_quote, label %check_atom
    
check_atom:
    %is_atom = icmp eq i32 %expr_type, 0  ; AST_ATOM
    br i1 %is_atom, label %handle_atom, label %handle_list
    
handle_quote:
    ; Extract quoted expression from car field
    %quote_car_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 4
    %quoted_expr = load %ASTNode*, %ASTNode** %quote_car_ptr
    %quoted_expr_null = icmp eq %ASTNode* %quoted_expr, null
    br i1 %quoted_expr_null, label %return_null, label %check_quoted_atom
    
check_quoted_atom:
    ; Check if quoted expression is an atom (type 0)
    %quoted_type_ptr = getelementptr %ASTNode, %ASTNode* %quoted_expr, i32 0, i32 0
    %quoted_type = load i32, i32* %quoted_type_ptr
    %quoted_is_atom = icmp eq i32 %quoted_type, 0  ; AST_ATOM
    br i1 %quoted_is_atom, label %extract_atom_name, label %return_null
    
extract_atom_name:
    ; Extract atom name and return as special marker
    ; For now, we'll use a helper function to extract the atom name
    ; This will be used by llvm:icmp, llvm:br, llvm:label to get quoted identifiers
    ; We need to return the atom name somehow - but LLVMValueRef can't hold strings directly
    ; Instead, we'll store it in a special way that handlers can extract
    ; For now, return null and let handlers call codegen_extract_quoted_atom directly
    ; This is a limitation - we need a way to pass quoted atom names through the evaluation
    ; The handlers will check if their argument is AST_QUOTE and extract it themselves
    ret %LLVMValueRef null
    
handle_atom:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_dsl_expr_atom, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get atom value and length
    %atom_val_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 2
    %atom_val = load i8*, i8** %atom_val_ptr
    %atom_len_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 3
    %atom_len = load i64, i64* %atom_len_ptr
    
    ; Debug: Print atom value pointer and length to verify they're not corrupted
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_atom_val_ptr, i32 0, i32 0), i8* %atom_val, i64 %atom_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Print first few bytes of atom_val to verify it's not corrupted
    %atom_val_not_null = icmp ne i8* %atom_val, null
    %atom_len_gt_zero = icmp ugt i64 %atom_len, 0
    %can_print_bytes = and i1 %atom_val_not_null, %atom_len_gt_zero
    br i1 %can_print_bytes, label %print_first_bytes, label %skip_print_bytes
    
print_first_bytes:
    ; Print first 4 bytes (or fewer if atom_len < 4)
    %atom_len_ge_4 = icmp uge i64 %atom_len, 4
    br i1 %atom_len_ge_4, label %print_4_bytes, label %print_less_than_4
    
print_4_bytes:
    %byte0_ptr = getelementptr i8, i8* %atom_val, i64 0
    %byte0 = load i8, i8* %byte0_ptr
    %byte1_ptr = getelementptr i8, i8* %atom_val, i64 1
    %byte1 = load i8, i8* %byte1_ptr
    %byte2_ptr = getelementptr i8, i8* %atom_val, i64 2
    %byte2 = load i8, i8* %byte2_ptr
    %byte3_ptr = getelementptr i8, i8* %atom_val, i64 3
    %byte3 = load i8, i8* %byte3_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_atom_first_bytes, i32 0, i32 0), i8 %byte0, i8 %byte1, i8 %byte2, i8 %byte3)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %skip_print_bytes
    
print_less_than_4:
    ; For shorter atoms, just print what we have
    br label %skip_print_bytes
    
skip_print_bytes:
    %atom_type_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 1
    %atom_type = load i32, i32* %atom_type_ptr
    
    ; Check atom type: TOKEN_IDENTIFIER (symbol), TOKEN_STRING, TOKEN_NUMBER
    ; Handle TOKEN_NUMBER (type 2) by converting to constant integer
    %is_number = icmp eq i32 %atom_type, 2  ; TOKEN_NUMBER
    br i1 %is_number, label %handle_number, label %try_resolve_symbol
    
handle_number:
    ; Parse integer from AST node
    %int_value = call i32 @codegen_parse_int_from_ast(%ASTNode* %expr)
    
    ; Get context to create i32 type
    %context_for_int_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context_for_int = load %LLVMContextRef, %LLVMContextRef* %context_for_int_ptr
    %context_for_int_null = icmp eq %LLVMContextRef %context_for_int, null
    br i1 %context_for_int_null, label %return_null, label %get_i32_type
    
get_i32_type:
    ; Get i32 type for the constant
    %i32_type_for_const = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context_for_int)
    %i32_type_for_const_null = icmp eq %LLVMTypeRef %i32_type_for_const, null
    br i1 %i32_type_for_const_null, label %return_null, label %create_int_const
    
create_int_const:
    ; Create constant integer (value is already i32, extend to i64 for API)
    %int_value_64 = zext i32 %int_value to i64
    %int_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type_for_const, i64 %int_value_64, i32 0)
    ret %LLVMValueRef %int_const
    
try_resolve_symbol:
    ; Resolution order: Check functions before parameters to avoid crashes
    ; 1. Local values (let* bindings) - most local scope
    ; 2. Functions - module-level functions (check before parameters to find function names)
    ; 3. Parameters - function parameters
    ; 4. Constants - module-level constants
    
    ; Try to resolve as local value name first (let* bindings shadow parameters)
    %local_value_first = call %LLVMValueRef @codegen_dsl_resolve_local(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %local_not_null_first = icmp ne %LLVMValueRef %local_value_first, null
    br i1 %local_not_null_first, label %return_local_first, label %try_function_first
    
return_local_first:
    ret %LLVMValueRef %local_value_first
    
try_function_first:
    ; Try to resolve as function name (before checking parameters)
    ; This prevents crashes when a function name is mistaken for a parameter
    ; Allocate space for function value and type output
    %func_value_out_first = alloca %LLVMValueRef
    %func_type_out_first = alloca %LLVMTypeRef
    %func_found_first = call i32 @codegen_get_llvm_function(%CodeGen* %cg, i8* %atom_val, i64 %atom_len, %LLVMValueRef* %func_value_out_first, %LLVMTypeRef* %func_type_out_first)
    %func_found_bool_first = icmp ne i32 %func_found_first, 0
    br i1 %func_found_bool_first, label %return_function_first, label %try_param
    
return_function_first:
    ; Get function value from output parameter
    %func_value_first = load %LLVMValueRef, %LLVMValueRef* %func_value_out_first
    ret %LLVMValueRef %func_value_first
    
try_param:
    ; Try to resolve as parameter name (after checking locals and functions)
    %param_value = call %LLVMValueRef @codegen_dsl_resolve_param(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %param_not_null = icmp ne %LLVMValueRef %param_value, null
    br i1 %param_not_null, label %return_param, label %try_constant
    
return_param:
    ; Debug: Returning parameter value from codegen_eval_dsl_expr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([35 x i8], [35 x i8]* @.str.debug_returning_from_eval, i32 0, i32 0))
    %param_value_check = icmp eq %LLVMValueRef %param_value, null
    br i1 %param_value_check, label %param_value_null_in_eval, label %return_param_ok
    
param_value_null_in_eval:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
    
return_param_ok:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef %param_value
    
try_constant:
    ; Try to resolve as constant name (after checking locals)
    ; Debug: Looking up constant
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_looking_up_constant, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %atom_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %constant_value = call %LLVMValueRef @codegen_get_constant(%CodeGen* %cg, i8* %atom_val, i64 %atom_len)
    %constant_not_null = icmp ne %LLVMValueRef %constant_value, null
    br i1 %constant_not_null, label %return_constant, label %constant_not_found
    
constant_not_found:
    ; Debug: Constant not found (locals, functions, and parameters were already checked)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_global_not_found, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @.str.debug_name_colon_space, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* %atom_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([54 x i8], [54 x i8]* @.str.warn_unresolved_atom, i32 0, i32 0), i64 %atom_len)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; All resolution attempts failed, return null
    br label %return_null_atom
    
return_constant:
    ; Check if constant is an array type and convert to pointer if needed
    ; Get the type of the constant (globals are pointers)
    %constant_type = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %constant_value)
    %constant_type_null = icmp eq %LLVMTypeRef %constant_type, null
    br i1 %constant_type_null, label %return_constant_as_is, label %check_if_array
    
check_if_array:
    ; Check if the constant type is an array
    %is_array = call i32 @codegen_is_array_type(%LLVMTypeRef %constant_type)
    %is_array_bool = icmp eq i32 %is_array, 1
    br i1 %is_array_bool, label %create_gep, label %return_constant_as_is
    
create_gep:
    ; Get builder from CodeGen structure
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %return_constant_as_is, label %get_context_for_gep
    
get_context_for_gep:
    ; Get context to create constant integers
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %context_null = icmp eq %LLVMContextRef %context, null
    br i1 %context_null, label %return_constant_as_is, label %create_indices
    
create_indices:
    ; Get i32 type for indices
    %i32_type = call %LLVMTypeRef @llvm_get_int32_type(%LLVMContextRef %context)
    %i32_type_null = icmp eq %LLVMTypeRef %i32_type, null
    br i1 %i32_type_null, label %return_constant_as_is, label %create_zero_const
    
create_zero_const:
    ; Create constant zero for indices [0, 0]
    %zero_const = call %LLVMValueRef @llvm_create_constant_int(%LLVMTypeRef %i32_type, i64 0, i32 0)
    %zero_const_null = icmp eq %LLVMValueRef %zero_const, null
    br i1 %zero_const_null, label %return_constant_as_is, label %allocate_indices_array
    
allocate_indices_array:
    ; Allocate array for two indices [0, 0]
    %indices_array = call i8* @malloc(i64 16)  ; 2 * 8 bytes for LLVMValueRef
    %indices_ptr = bitcast i8* %indices_array to %LLVMValueRef*
    
    ; Store first zero index
    %zero_idx0 = getelementptr %LLVMValueRef, %LLVMValueRef* %indices_ptr, i32 0
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx0
    
    ; Store second zero index
    %zero_idx1 = getelementptr %LLVMValueRef, %LLVMValueRef* %indices_ptr, i32 1
    store %LLVMValueRef %zero_const, %LLVMValueRef* %zero_idx1
    
    ; Get the element type of the pointer (the array type)
    %array_element_type = call %LLVMTypeRef @llvm_get_element_type(%LLVMTypeRef %constant_type)
    %array_element_type_null = icmp eq %LLVMTypeRef %array_element_type, null
    br i1 %array_element_type_null, label %free_indices_and_return, label %build_gep
    
build_gep:
    ; Build GEP instruction: getelementptr array_element_type, constant_type* %constant_value, [0, 0]
    ; Use empty string for name
    %empty_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %constant_gep_result = call %LLVMValueRef @llvm_build_gep(%LLVMBuilderRef %builder, %LLVMTypeRef %array_element_type, %LLVMValueRef %constant_value, %LLVMValueRef* %indices_ptr, i32 2, i8* %empty_str)
    
    ; Free indices array
    call void @free(i8* %indices_array)
    
    ; Check if GEP succeeded
    %constant_gep_null = icmp eq %LLVMValueRef %constant_gep_result, null
    br i1 %constant_gep_null, label %return_constant_as_is, label %return_gep
    
free_indices_and_return:
    ; Free indices array if we couldn't get element type
    call void @free(i8* %indices_array)
    br label %return_constant_as_is
    
return_gep:
    ; Return the GEP result (pointer to first element of array)
    ret %LLVMValueRef %constant_gep_result
    
return_constant_as_is:
    ; Return constant value as-is (not an array or GEP failed)
    ret %LLVMValueRef %constant_value
    
return_null_atom:
    ret %LLVMValueRef null
    
handle_list:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_dsl_expr_list, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if this is a let* special form
    %list_car_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 4
    %list_car = load %ASTNode*, %ASTNode** %list_car_ptr
    
    %list_car_null = icmp eq %ASTNode* %list_car, null
    br i1 %list_car_null, label %return_null, label %check_let_star
    
check_let_star:
    ; Check if first element is "let*"
    %car_type_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 0
    %car_type = load i32, i32* %car_type_ptr
    %car_is_atom = icmp eq i32 %car_type, 0  ; AST_ATOM
    br i1 %car_is_atom, label %check_let_star_name, label %handle_function_call
    
check_let_star_name:
    %car_val_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 2
    %car_val = load i8*, i8** %car_val_ptr
    %car_len_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 3
    %car_len = load i64, i64* %car_len_ptr
    
    ; Check if it's "let*" (4 characters)
    %is_let_star = call i32 @codegen_dsl_check_primitive(i8* %car_val, i64 %car_len, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.let_star, i32 0, i32 0), i64 4)
    %is_let_star_bool = icmp ne i32 %is_let_star, 0
    br i1 %is_let_star_bool, label %handle_let_star, label %handle_function_call
    
handle_let_star:
    ; Debug: let* form recognized
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_let_star_recognized, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    %let_star_result = call %LLVMValueRef @codegen_eval_let_star(%CodeGen* %cg, %ASTNode* %expr)
    ret %LLVMValueRef %let_star_result
    
handle_function_call:
    ; List is a function call: (primitive-name arg1 arg2 ...)
    ; Get function name (first element)
    %func_name_node_null = icmp eq %ASTNode* %list_car, null
    br i1 %func_name_node_null, label %return_null, label %get_func_name
    
get_func_name:
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
    ; Debug logging - print primitive name
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_dsl_primitive, i32 0, i32 0))
    ; Print primitive name (create null-terminated string)
    %prim_buf_size = add i64 %func_name_len, 1
    %prim_buf = call i8* @malloc(i64 %prim_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %prim_buf, i8* %func_name, i64 %func_name_len, i1 false)
    %prim_null_ptr = getelementptr i8, i8* %prim_buf, i64 %func_name_len
    store i8 0, i8* %prim_null_ptr
    call i32 (i8*, ...) @printf(i8* %prim_buf)
    call void @free(i8* %prim_buf)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get arguments (rest of list)
    %list_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 5
    %args_list = load %ASTNode*, %ASTNode** %list_cdr_ptr
    
    ; Dispatch to appropriate primitive handler
    ; Check for each primitive by name
    %is_gep = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_gep, i32 0, i32 0), i64 8)
    %is_gep_bool = icmp ne i32 %is_gep, 0
    br i1 %is_gep_bool, label %call_gep, label %check_call
    
call_gep:
    %gep_result = call %LLVMValueRef @codegen_dsl_gep(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %gep_result
    
check_call:
    %is_call = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_call, i32 0, i32 0), i64 9)
    %is_call_bool = icmp ne i32 %is_call, 0
    br i1 %is_call_bool, label %call_call, label %check_ret_void
    
call_call:
    %call_result = call %LLVMValueRef @codegen_dsl_call(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %call_result
    
check_ret_void:
    %is_ret_void = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.dsl_ret_void, i32 0, i32 0), i64 13)
    %is_ret_void_bool = icmp ne i32 %is_ret_void, 0
    br i1 %is_ret_void_bool, label %call_ret_void, label %check_ret
    
call_ret_void:
    %ret_void_result = call %LLVMValueRef @codegen_dsl_ret_void(%CodeGen* %cg)
    ret %LLVMValueRef %ret_void_result
    
check_ret:
    %is_ret = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_ret, i32 0, i32 0), i64 8)
    %is_ret_bool = icmp ne i32 %is_ret, 0
    br i1 %is_ret_bool, label %call_ret, label %check_get_global
    
call_ret:
    %ret_result = call %LLVMValueRef @codegen_dsl_ret(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %ret_result
    
check_get_global:
    %is_get_global = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([16 x i8], [16 x i8]* @.str.dsl_get_global, i32 0, i32 0), i64 15)
    %is_get_global_bool = icmp ne i32 %is_get_global, 0
    br i1 %is_get_global_bool, label %call_get_global, label %check_get_function
    
call_get_global:
    %get_global_result = call %LLVMValueRef @codegen_dsl_get_global(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_global_result
    
check_get_function:
    %is_get_function = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.dsl_get_function, i32 0, i32 0), i64 17)
    %is_get_function_bool = icmp ne i32 %is_get_function, 0
    br i1 %is_get_function_bool, label %call_get_function, label %check_get_param
    
call_get_function:
    %get_function_result = call %LLVMValueRef @codegen_dsl_get_function(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_function_result
    
check_get_param:
    %is_get_param = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.dsl_get_param, i32 0, i32 0), i64 14)
    %is_get_param_bool = icmp ne i32 %is_get_param, 0
    br i1 %is_get_param_bool, label %call_get_param, label %check_const_int
    
call_get_param:
    %get_param_result = call %LLVMValueRef @codegen_dsl_get_param(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %get_param_result
    
check_const_int:
    %is_const_int = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([15 x i8], [15 x i8]* @.str.dsl_const_int, i32 0, i32 0), i64 14)
    %is_const_int_bool = icmp ne i32 %is_const_int, 0
    br i1 %is_const_int_bool, label %call_const_int, label %check_const_null
    
call_const_int:
    %const_int_result = call %LLVMValueRef @codegen_dsl_const_int(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %const_int_result
    
check_const_null:
    %is_const_null = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([16 x i8], [16 x i8]* @.str.dsl_const_null, i32 0, i32 0), i64 15)
    %is_const_null_bool = icmp ne i32 %is_const_null, 0
    br i1 %is_const_null_bool, label %call_const_null, label %check_list
    
call_const_null:
    %const_null_result = call %LLVMValueRef @codegen_dsl_const_null(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %const_null_result
    
check_list:
    ; Check for "list" form - evaluates arguments and returns them as a list structure
    ; For now, "list" is handled by evaluating arguments directly
    ; The list structure in AST is already correct for passing to functions
    ; So we just evaluate the list normally (which will fail for unknown primitives)
    ; Actually, "list" should be handled specially - it creates a list of evaluated values
    %is_list = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.dsl_list, i32 0, i32 0), i64 4)
    %is_list_bool = icmp ne i32 %is_list, 0
    br i1 %is_list_bool, label %handle_list_form, label %check_array
    
handle_list_form:
    ; For "list" form, we just return the args_list as-is
    ; The caller will evaluate each element when needed
    ; Actually, we can't return an AST node as LLVMValueRef
    ; So "list" needs special handling in the caller
    ; For now, return null and handle it in the caller
    ret %LLVMValueRef null
    
check_array:
    ; Check for "llvm:array" form - evaluates arguments and returns them as an array
    ; Similar to "list" but semantically correct for LLVM argument arrays
    %is_llvm_array = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_array, i32 0, i32 0), i64 10)
    %is_llvm_array_bool = icmp ne i32 %is_llvm_array, 0
    br i1 %is_llvm_array_bool, label %handle_array_form, label %check_bitcast
    
check_bitcast:
    ; Check for "llvm:bitcast" form
    %is_bitcast = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.dsl_bitcast, i32 0, i32 0), i64 12)
    %is_bitcast_bool = icmp ne i32 %is_bitcast, 0
    br i1 %is_bitcast_bool, label %call_bitcast, label %check_store
    
call_bitcast:
    %bitcast_result = call %LLVMValueRef @codegen_dsl_bitcast(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %bitcast_result
    
check_store:
    ; Check for "llvm:store" form
    %is_store = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_store, i32 0, i32 0), i64 10)
    %is_store_bool = icmp ne i32 %is_store, 0
    br i1 %is_store_bool, label %call_store, label %check_load
    
call_store:
    %store_result = call %LLVMValueRef @codegen_dsl_store(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %store_result
    
check_load:
    ; Check for "llvm:load" form
    %is_load = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_load, i32 0, i32 0), i64 9)
    %is_load_bool = icmp ne i32 %is_load, 0
    br i1 %is_load_bool, label %call_load, label %check_icmp
    
call_load:
    %load_result = call %LLVMValueRef @codegen_dsl_load(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %load_result
    
check_icmp:
    ; Check for "llvm:icmp" form
    %is_icmp = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_icmp, i32 0, i32 0), i64 9)
    %is_icmp_bool = icmp ne i32 %is_icmp, 0
    br i1 %is_icmp_bool, label %call_icmp, label %check_br
    
call_icmp:
    %icmp_result = call %LLVMValueRef @codegen_dsl_icmp(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %icmp_result
    
check_br:
    ; Check for "llvm:br" form
    %is_br = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.dsl_br, i32 0, i32 0), i64 7)
    %is_br_bool = icmp ne i32 %is_br, 0
    br i1 %is_br_bool, label %call_br, label %check_zext
    
call_br:
    %br_result = call %LLVMValueRef @codegen_dsl_br(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %br_result
    
check_zext:
    ; Check for "llvm:zext" form
    %is_zext = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_zext, i32 0, i32 0), i64 9)
    %is_zext_bool = icmp ne i32 %is_zext, 0
    br i1 %is_zext_bool, label %call_zext, label %check_add
    
call_zext:
    %zext_result = call %LLVMValueRef @codegen_dsl_zext(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %zext_result
    
check_add:
    ; Check for "llvm:add" form
    %is_add = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_add, i32 0, i32 0), i64 8)
    %is_add_bool = icmp ne i32 %is_add, 0
    br i1 %is_add_bool, label %call_add, label %check_or
    
call_add:
    %add_result = call %LLVMValueRef @codegen_dsl_add(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %add_result
    
check_or:
    ; Check for "llvm:or" form
    %is_or = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.dsl_or, i32 0, i32 0), i64 7)
    %is_or_bool = icmp ne i32 %is_or, 0
    br i1 %is_or_bool, label %call_or, label %check_label
    
call_or:
    %or_result = call %LLVMValueRef @codegen_dsl_or(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %or_result
    
check_label:
    ; Check for "llvm:label" form
    %is_label = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_label, i32 0, i32 0), i64 10)
    %is_label_bool = icmp ne i32 %is_label, 0
    br i1 %is_label_bool, label %call_label, label %check_alloca
    
call_label:
    %label_result = call %LLVMValueRef @codegen_dsl_label(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %label_result
    
check_alloca:
    %is_alloca = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.dsl_alloca, i32 0, i32 0), i64 11)
    %is_alloca_bool = icmp ne i32 %is_alloca, 0
    br i1 %is_alloca_bool, label %call_alloca, label %check_sub

call_alloca:
    %alloca_result = call %LLVMValueRef @codegen_dsl_alloca(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %alloca_result

check_sub:
    %is_sub = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_sub, i32 0, i32 0), i64 8)
    %is_sub_bool = icmp ne i32 %is_sub, 0
    br i1 %is_sub_bool, label %call_sub, label %check_and

call_sub:
    %sub_result = call %LLVMValueRef @codegen_dsl_sub(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %sub_result

check_and:
    %is_and = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_and, i32 0, i32 0), i64 8)
    %is_and_bool = icmp ne i32 %is_and, 0
    br i1 %is_and_bool, label %call_and, label %check_mul

call_and:
    %and_result = call %LLVMValueRef @codegen_dsl_and(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %and_result

check_mul:
    %is_mul = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_mul, i32 0, i32 0), i64 8)
    %is_mul_bool = icmp ne i32 %is_mul, 0
    br i1 %is_mul_bool, label %call_mul, label %check_trunc

call_mul:
    %mul_result = call %LLVMValueRef @codegen_dsl_mul(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %mul_result

check_trunc:
    %is_trunc = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_trunc, i32 0, i32 0), i64 10)
    %is_trunc_bool = icmp ne i32 %is_trunc, 0
    br i1 %is_trunc_bool, label %call_trunc, label %check_select

call_trunc:
    %trunc_result = call %LLVMValueRef @codegen_dsl_trunc(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %trunc_result

check_select:
    %is_select = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.dsl_select, i32 0, i32 0), i64 11)
    %is_select_bool = icmp ne i32 %is_select, 0
    br i1 %is_select_bool, label %call_select, label %check_phi

call_select:
    %select_result = call %LLVMValueRef @codegen_dsl_select(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %select_result

check_phi:
    %is_phi = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([9 x i8], [9 x i8]* @.str.dsl_phi, i32 0, i32 0), i64 8)
    %is_phi_bool = icmp ne i32 %is_phi, 0
    br i1 %is_phi_bool, label %call_phi, label %check_undef

call_phi:
    %phi_result = call %LLVMValueRef @codegen_dsl_phi(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %phi_result

check_undef:
    %is_undef = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_undef, i32 0, i32 0), i64 10)
    %is_undef_bool = icmp ne i32 %is_undef, 0
    br i1 %is_undef_bool, label %call_undef, label %check_insertvalue

call_undef:
    %undef_result = call %LLVMValueRef @codegen_dsl_undef(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %undef_result

check_insertvalue:
    %is_insertvalue = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.dsl_insertvalue, i32 0, i32 0), i64 16)
    %is_insertvalue_bool = icmp ne i32 %is_insertvalue, 0
    br i1 %is_insertvalue_bool, label %call_insertvalue, label %check_extractvalue

call_insertvalue:
    %insertvalue_result = call %LLVMValueRef @codegen_dsl_insertvalue(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %insertvalue_result

check_extractvalue:
    %is_extractvalue = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.dsl_extractvalue, i32 0, i32 0), i64 17)
    %is_extractvalue_bool = icmp ne i32 %is_extractvalue, 0
    br i1 %is_extractvalue_bool, label %call_extractvalue, label %check_urem

call_extractvalue:
    %extractvalue_result = call %LLVMValueRef @codegen_dsl_extractvalue(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %extractvalue_result

check_urem:
    ; Check for "llvm:urem" form
    %is_urem = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_urem, i32 0, i32 0), i64 9)
    %is_urem_bool = icmp ne i32 %is_urem, 0
    br i1 %is_urem_bool, label %call_urem, label %check_udiv

call_urem:
    %urem_result = call %LLVMValueRef @codegen_dsl_urem(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %urem_result

check_udiv:
    ; Check for "llvm:udiv" form
    %is_udiv = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([10 x i8], [10 x i8]* @.str.dsl_udiv, i32 0, i32 0), i64 9)
    %is_udiv_bool = icmp ne i32 %is_udiv, 0
    br i1 %is_udiv_bool, label %call_udiv, label %check_ptrtoint

call_udiv:
    %udiv_result = call %LLVMValueRef @codegen_dsl_udiv(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %udiv_result

check_ptrtoint:
    ; Check for "llvm:ptrtoint" form
    %is_ptrtoint = call i32 @codegen_dsl_check_primitive(i8* %func_name, i64 %func_name_len, i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.dsl_ptrtoint, i32 0, i32 0), i64 13)
    %is_ptrtoint_bool = icmp ne i32 %is_ptrtoint, 0
    br i1 %is_ptrtoint_bool, label %call_ptrtoint, label %unknown_primitive

call_ptrtoint:
    %ptrtoint_result = call %LLVMValueRef @codegen_dsl_ptrtoint(%CodeGen* %cg, %ASTNode* %args_list)
    ret %LLVMValueRef %ptrtoint_result

handle_array_form:
    ; For "llvm-array" form, we return null and let the caller handle it
    ; The caller (codegen_dsl_call) will evaluate each element when needed
    ret %LLVMValueRef null
    
unknown_primitive:
    ; Unknown primitive - return null (error case)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_unknown_primitive, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ret %LLVMValueRef null
}

; codegen_dsl_check_primitive: defined in codegen.vibe
declare i32 @codegen_dsl_check_primitive(i8*, i64, i8*, i64)

; codegen_dsl_resolve_param: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_resolve_param(%CodeGen* %cg, i8* %name, i64 %name_len)

; codegen_dsl_resolve_local: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_resolve_local(%CodeGen* %cg, i8* %name, i64 %name_len)

; codegen_dsl_bind_local: Migrated to kernel/codegen.vibe
declare void @codegen_dsl_bind_local(%CodeGen* %cg, i8* %name, i64 %name_len, %LLVMValueRef %value)

; codegen_parse_int_from_ast: defined in codegen.vibe
declare i32 @codegen_parse_int_from_ast(%ASTNode*)

; codegen_parse_int_string: defined in codegen.vibe
declare i32 @codegen_parse_int_string(i8*, i64)

; ============================================================================
; DSL Primitive Implementations
; ============================================================================

; codegen_dsl_gep: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_gep(%CodeGen* %cg, %ASTNode* %args)

; llvm-call: Build function call instruction
; Signature: (llvm-call func-type func args name)
define %LLVMValueRef @codegen_dsl_call(%CodeGen* %cg, %ASTNode* %args) {
entry:
    ; Get builder
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    %builder = load %LLVMBuilderRef, %LLVMBuilderRef* %builder_ptr
    
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %error, label %get_func
    
get_func:
    ; Get function value (second element - func-type is first but we'll infer it)
    %args_null = icmp eq %ASTNode* %args, null
    br i1 %args_null, label %error, label %get_func_node
    
get_func_node:
    %func_node_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 4
    %func_node = load %ASTNode*, %ASTNode** %func_node_ptr
    
    ; Evaluate function expression
    %func = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %func_node)
    
    ; Debug logging - check function result
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_func_eval_result, i32 0, i32 0))
    %func_is_null_check = icmp eq %LLVMValueRef %func, null
    br i1 %func_is_null_check, label %print_func_null, label %print_func_ok
    
print_func_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    br label %print_func_done
    
print_func_ok:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    br label %print_func_done
    
print_func_done:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %get_func_type
    
get_func_type:
    ; Look up the stored function type using reverse lookup by function value
    ; This uses the exact function type that was stored when the function was
    ; retrieved via llvm-get-function or defined via define-llvm-function
    %stored_func_type = call %LLVMTypeRef @codegen_get_function_type_by_value(%CodeGen* %cg, %LLVMValueRef %func)
    %has_stored_type = icmp ne %LLVMTypeRef %stored_func_type, null
    br i1 %has_stored_type, label %use_stored_func_type, label %fallback_to_llvm_typeof
    
use_stored_func_type:
    ; Use the stored function type (preferred)
    br label %use_func_type
    
fallback_to_llvm_typeof:
    ; Fallback to LLVMTypeOf if stored type not found
    ; This should only happen for functions not stored in llvm_functions list
    %func_type_from_value = call %LLVMTypeRef @llvm_type_of(%LLVMValueRef %func)
    %func_type_from_value_null = icmp eq %LLVMTypeRef %func_type_from_value, null
    br i1 %func_type_from_value_null, label %func_type_error, label %use_func_type
    
use_func_type:
    ; Use function type from stored lookup or LLVMTypeOf fallback
    %func_type = phi %LLVMTypeRef [ %stored_func_type, %use_stored_func_type ], [ %func_type_from_value, %fallback_to_llvm_typeof ]
    
    ; Check if function type is null (shouldn't be if we got here, but be safe)
    %func_type_null = icmp eq %LLVMTypeRef %func_type, null
    br i1 %func_type_null, label %func_type_error, label %get_args_list
    
func_type_error:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_func_type_null_error, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %error
    
get_args_list:
    ; Get args list (cdr of args, which contains all arguments after the function name)
    ; args is (func-name arg1 arg2 ...), so args.cdr is (arg1 arg2 ...)
    %args_cdr_ptr = getelementptr %ASTNode, %ASTNode* %args, i32 0, i32 5
    %args_list_raw = load %ASTNode*, %ASTNode** %args_cdr_ptr
    
    ; Debug: Log args list extraction
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_extracting_args_list, i32 0, i32 0))
    %args_list_raw_null = icmp eq %ASTNode* %args_list_raw, null
    br i1 %args_list_raw_null, label %args_list_null_debug, label %args_list_ok_debug
    
args_list_null_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_args
    
args_list_ok_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; Check if args_list is a "list" form
    %args_is_list = icmp ne %ASTNode* %args_list_raw, null
    br i1 %args_is_list, label %check_args_list_form, label %eval_args
    
check_args_list_form:
    %args_car_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 4
    %args_car = load %ASTNode*, %ASTNode** %args_car_ptr
    %args_car_type_ptr = getelementptr %ASTNode, %ASTNode* %args_car, i32 0, i32 0
    %args_car_type = load i32, i32* %args_car_type_ptr
    %is_atom_args = icmp eq i32 %args_car_type, 0
    br i1 %is_atom_args, label %check_list_name_args, label %eval_args
    
check_list_name_args:
    %list_name_args_ptr = getelementptr %ASTNode, %ASTNode* %args_car, i32 0, i32 2
    %list_name_args = load i8*, i8** %list_name_args_ptr
    %list_name_len_args_ptr = getelementptr %ASTNode, %ASTNode* %args_car, i32 0, i32 3
    %list_name_len_args = load i64, i64* %list_name_len_args_ptr
    ; Check for "llvm-array" form (preferred) or "list" form (for backward compatibility)
    %is_array_form_args = call i32 @codegen_dsl_check_primitive(i8* %list_name_args, i64 %list_name_len_args, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.dsl_array, i32 0, i32 0), i64 10)
    %is_array_form_args_bool = icmp ne i32 %is_array_form_args, 0
    br i1 %is_array_form_args_bool, label %get_array_args_call, label %check_list_form_args
    
check_list_form_args:
    ; Check for legacy "list" form (for backward compatibility)
    %is_list_form_args = call i32 @codegen_dsl_check_primitive(i8* %list_name_args, i64 %list_name_len_args, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.dsl_list, i32 0, i32 0), i64 4)
    %is_list_form_args_bool = icmp ne i32 %is_list_form_args, 0
    br i1 %is_list_form_args_bool, label %get_list_args_call, label %eval_args
    
get_array_args_call:
    ; Get arguments from llvm-array form: (llvm-array arg1 arg2 ...)
    %args_cdr_array_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 5
    %array_args_call = load %ASTNode*, %ASTNode** %args_cdr_array_ptr
    br label %eval_args
    
get_list_args_call:
    ; Get arguments from legacy list form: (list arg1 arg2 ...)
    %args_cdr_list_ptr = getelementptr %ASTNode, %ASTNode* %args_list_raw, i32 0, i32 5
    %list_args_call = load %ASTNode*, %ASTNode** %args_cdr_list_ptr
    br label %eval_args
    
eval_args:
    %args_to_eval = phi %ASTNode* [ %args_list_raw, %check_args_list_form ], [ %args_list_raw, %check_list_form_args ], [ %array_args_call, %get_array_args_call ], [ %list_args_call, %get_list_args_call ], [ %args_list_raw, %args_list_null_debug ], [ %args_list_raw, %args_list_ok_debug ]
    
    ; Evaluate args list
    %args_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %args_array_ptr = bitcast i8* %args_array to %LLVMValueRef*
    %arg_count = call i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %args_to_eval, %LLVMValueRef* %args_array_ptr, i32 10)
    
    ; Get name (optional, would be after arguments if present)
    ; For now, we don't support optional names in llvm:call, so use empty string
    %name_list = alloca %ASTNode*
    store %ASTNode* null, %ASTNode** %name_list
    %name_list_val = load %ASTNode*, %ASTNode** %name_list
    %name_str = getelementptr [1 x i8], [1 x i8]* @.str.empty, i32 0, i32 0
    %has_name = icmp ne %ASTNode* %name_list_val, null
    br i1 %has_name, label %get_name_call, label %build_call
    
get_name_call:
    %name_node_ptr = getelementptr %ASTNode, %ASTNode* %name_list_val, i32 0, i32 4
    %name_node = load %ASTNode*, %ASTNode** %name_node_ptr
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %name_node, i32 0, i32 2
    %name_str_val = load i8*, i8** %name_val_ptr
    br label %build_call
    
build_call:
    %name_phi_call = phi i8* [ %name_str, %eval_args ], [ %name_str_val, %get_name_call ]
    
    ; Additional safety checks before calling
    %func_check = icmp eq %LLVMValueRef %func, null
    br i1 %func_check, label %error_with_free, label %check_func_type_again
    
check_func_type_again:
    %func_type_check = icmp eq %LLVMTypeRef %func_type, null
    br i1 %func_type_check, label %error_with_free, label %do_call
    
do_call:
    ; Validate arguments array - check if any argument is null
    ; For vararg functions like printf, we need to be careful
    %arg_count_zero = icmp eq i32 %arg_count, 0
    br i1 %arg_count_zero, label %call_with_no_args, label %validate_args
    
validate_args:
    ; Check each argument for null (up to arg_count)
    %i = alloca i32
    store i32 0, i32* %i
    br label %validate_loop
    
validate_loop:
    %i_val = load i32, i32* %i
    %done_validate = icmp uge i32 %i_val, %arg_count
    br i1 %done_validate, label %args_valid, label %check_arg
    
check_arg:
    %arg_idx = getelementptr %LLVMValueRef, %LLVMValueRef* %args_array_ptr, i32 %i_val
    %arg_val = load %LLVMValueRef, %LLVMValueRef* %arg_idx
    %arg_null = icmp eq %LLVMValueRef %arg_val, null
    br i1 %arg_null, label %arg_error, label %next_arg
    
next_arg:
    %i_new = add i32 %i_val, 1
    store i32 %i_new, i32* %i
    br label %validate_loop
    
arg_error:
    ; Debug logging - null argument found
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_null_arg_error, i32 0, i32 0), i32 %i_val)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call void @free(i8* %args_array)
    br label %error
    
args_valid:
    ; All arguments are valid, proceed with call
    br label %call_with_args
    
call_with_no_args:
    ; No arguments - pass null array pointer (LLVM allows this for 0 args)
    %call_result_no_args = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* null, i32 0, i8* %name_phi_call)
    call void @free(i8* %args_array)
    ret %LLVMValueRef %call_result_no_args
    
error_with_free:
    ; Free args_array if it was allocated before returning error
    call void @free(i8* %args_array)
    br label %error
    
call_with_args:
    ; Debug logging before call
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([27 x i8], [27 x i8]* @.str.debug_building_call, i32 0, i32 0), i32 %arg_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check all parameters before call
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_checking_builder, i32 0, i32 0))
    %builder_ptr_debug = bitcast %LLVMBuilderRef %builder to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %builder_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_checking_func_type, i32 0, i32 0))
    %func_type_ptr_debug = bitcast %LLVMTypeRef %func_type to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %func_type_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_checking_func, i32 0, i32 0))
    %func_ptr_debug = bitcast %LLVMValueRef %func to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %func_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.str.debug_checking_args_array, i32 0, i32 0))
    %args_array_ptr_debug = bitcast %LLVMValueRef* %args_array_ptr to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %args_array_ptr_debug)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check all arguments
    %arg_idx_debug = alloca i32
    store i32 0, i32* %arg_idx_debug
    br label %debug_args_loop
    
debug_args_loop:
    %arg_idx_val = load i32, i32* %arg_idx_debug
    %done_debug = icmp uge i32 %arg_idx_val, %arg_count
    br i1 %done_debug, label %call_after_debug, label %debug_arg
    
debug_arg:
    %arg_ptr_debug = getelementptr %LLVMValueRef, %LLVMValueRef* %args_array_ptr, i32 %arg_idx_val
    %arg_val_debug = load %LLVMValueRef, %LLVMValueRef* %arg_ptr_debug
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_arg_value_at, i32 0, i32 0), i32 %arg_idx_val)
    %arg_ptr_debug_cast = bitcast %LLVMValueRef %arg_val_debug to i8*
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([13 x i8], [13 x i8]* @.str.debug_pointer_value, i32 0, i32 0), i8* %arg_ptr_debug_cast)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %arg_idx_next = add i32 %arg_idx_val, 1
    store i32 %arg_idx_next, i32* %arg_idx_debug
    br label %debug_args_loop
    
call_after_debug:
    %call_result = call %LLVMValueRef @llvm_build_call(%LLVMBuilderRef %builder, %LLVMTypeRef %func_type, %LLVMValueRef %func, %LLVMValueRef* %args_array_ptr, i32 %arg_count, i8* %name_phi_call)
    
    ; Free args array
    call void @free(i8* %args_array)
    
    ret %LLVMValueRef %call_result
    
error:
    ret %LLVMValueRef null
}

; codegen_dsl_ret_void: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_ret_void(%CodeGen* %cg)

; llvm-ret: Build return with value; defined in codegen.vibe
declare %LLVMValueRef @codegen_dsl_ret(%CodeGen* %cg, %ASTNode* %args)

; llvm-get-global: Get global variable by name; defined in codegen.vibe
declare %LLVMValueRef @codegen_dsl_get_global(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_get_function: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_get_function(%CodeGen* %cg, %ASTNode* %args)

; llvm-get-param: Get function parameter by index; defined in codegen.vibe
declare %LLVMValueRef @codegen_dsl_get_param(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_const_int: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_const_int(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_const_null: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_const_null(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_bitcast: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_bitcast(%CodeGen* %cg, %ASTNode* %args)

; llvm:store: Build store instruction
; codegen_dsl_store: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_store(%CodeGen* %cg, %ASTNode* %args)

; codegen_extract_quoted_atom: defined in codegen.vibe
declare i32 @codegen_extract_quoted_atom(%ASTNode*, i8**, i64*)

; codegen_dsl_load: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_load(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_add(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_or(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_alloca: Handle llvm:alloca form
; Syntax: (llvm:alloca type)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list with (type)
; Returns: LLVMValueRef for allocated pointer
; codegen_dsl_alloca: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_alloca(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_sub: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_sub(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_and(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_mul(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_trunc: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_trunc(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_select(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_phi: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_phi(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_zext: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_zext(%CodeGen* %cg, %ASTNode* %args)

; codegen_map_predicate_string: defined in codegen.vibe
declare i32 @codegen_map_predicate_string(i8*, i64)

; codegen_dsl_icmp: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_icmp(%CodeGen* %cg, %ASTNode* %args)

; Label tracking structure (simple linked list node)
%LabelEntry = type { i8*, i64, %LLVMBasicBlockRef, %LabelEntry* }

; codegen_get_or_create_label: Get or create a basic block with given name
; Deferred migration: complex let*/label structure causes segfault when bootstrap compiles codegen.vibe
define %LLVMBasicBlockRef @codegen_get_or_create_label(%CodeGen* %cg, %LLVMValueRef %func, i8* %name, i64 %name_len) {
entry:
    %func_null = icmp eq %LLVMValueRef %func, null
    br i1 %func_null, label %error, label %check_existing

check_existing:
    %first_block = call %LLVMBasicBlockRef @llvm_get_first_basic_block(%LLVMValueRef %func)
    %first_block_null = icmp eq %LLVMBasicBlockRef %first_block, null
    br i1 %first_block_null, label %create_label, label %iterate_blocks

iterate_blocks:
    %current_block = phi %LLVMBasicBlockRef [ %first_block, %check_existing ], [ %next_block_val, %check_next_block ]
    %block_name = call i8* @llvm_get_basic_block_name(%LLVMBasicBlockRef %current_block)
    %block_name_null = icmp eq i8* %block_name, null
    br i1 %block_name_null, label %check_next_block, label %compare_names

compare_names:
    %name_len_int = trunc i64 %name_len to i32
    %cmp_result = call i32 @strncmp(i8* %block_name, i8* %name, i32 %name_len_int)
    %names_match = icmp eq i32 %cmp_result, 0
    br i1 %names_match, label %check_null_term, label %check_next_block

check_null_term:
    %block_name_at_len = getelementptr i8, i8* %block_name, i64 %name_len
    %block_char_at_len = load i8, i8* %block_name_at_len
    %is_null_term = icmp eq i8 %block_char_at_len, 0
    br i1 %is_null_term, label %found_existing, label %check_next_block

found_existing:
    ret %LLVMBasicBlockRef %current_block

check_next_block:
    %next_block_val = call %LLVMBasicBlockRef @llvm_get_next_basic_block(%LLVMBasicBlockRef %current_block)
    %next_block_null = icmp eq %LLVMBasicBlockRef %next_block_val, null
    br i1 %next_block_null, label %create_label, label %iterate_blocks

create_label:
    %name_buf_size = add i64 %name_len, 1
    %name_buf = call i8* @malloc(i64 %name_buf_size)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf, i8* %name, i64 %name_len, i1 false)
    %name_null_ptr = getelementptr i8, i8* %name_buf, i64 %name_len
    store i8 0, i8* %name_null_ptr
    %block = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %func, i8* %name_buf)
    ret %LLVMBasicBlockRef %block

error:
    ret %LLVMBasicBlockRef null
}

; codegen_dsl_br: Handle llvm:br form
; Syntax: (llvm:br 'label-name) or (llvm:br cond 'then-label 'else-label)
; Parameters:
;   cg: CodeGen pointer
;   args: AST node list
; Returns: LLVMValueRef for branch instruction
; codegen_dsl_br: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_br(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_label: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_label(%CodeGen* %cg, %ASTNode* %args)

; codegen_eval_let_star: Handle let* special form
; Syntax: (let* ((var1 value1) (var2 value2) ...) body ...)
; Parameters:
;   cg: CodeGen pointer
;   expr: AST node for let* form
; Returns: LLVMValueRef (last expression value) or null
; Semantics: Sequential binding - each binding can use previous bindings
define %LLVMValueRef @codegen_eval_let_star(%CodeGen* %cg, %ASTNode* %expr) {
entry:
    %expr_null = icmp eq %ASTNode* %expr, null
    br i1 %expr_null, label %error, label %get_bindings
    
get_bindings:
    ; Extract bindings list and body from expr
    ; The parser creates: (let* bindings-list body)
    ;   Structure: (let* . (bindings-list . body))
    ;   - expr.cdr = (bindings-list . body) = cons cell
    ;   - expr.cdr.car = bindings-list = ((var1 val1) (var2 val2) ...)
    ;   - expr.cdr.cdr = body = ((body-expr1) (body-expr2) ...)
    %expr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr, i32 0, i32 5
    %expr_cdr = load %ASTNode*, %ASTNode** %expr_cdr_ptr
    %expr_cdr_null = icmp eq %ASTNode* %expr_cdr, null
    br i1 %expr_cdr_null, label %error, label %extract_bindings_list
    
extract_bindings_list:
    ; Extract bindings list from expr.cdr.car
    %bindings_list_car_ptr = getelementptr %ASTNode, %ASTNode* %expr_cdr, i32 0, i32 4
    %bindings_list = load %ASTNode*, %ASTNode** %bindings_list_car_ptr
    
    ; Debug: Check bindings_list type
    %bindings_list_type_ptr = getelementptr %ASTNode, %ASTNode* %bindings_list, i32 0, i32 0
    %bindings_list_type = load i32, i32* %bindings_list_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_bindings_list_type, i32 0, i32 0), i32 %bindings_list_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %bindings_null = icmp eq %ASTNode* %bindings_list, null
    br i1 %bindings_null, label %error, label %extract_body_from_expr
    
extract_body_from_expr:
    ; Extract body from expr.cdr.cdr (body comes after bindings-list)
    %expr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr_cdr, i32 0, i32 5
    %body = load %ASTNode*, %ASTNode** %expr_cdr_cdr_ptr
    
    ; [LET*-BODY] Debug: log body structure (H2, H5)
    %body_car_ptr = getelementptr %ASTNode, %ASTNode* %body, i32 0, i32 4
    %body_car = load %ASTNode*, %ASTNode** %body_car_ptr
    %body_car_type_ptr = getelementptr %ASTNode, %ASTNode* %body_car, i32 0, i32 0
    %body_car_type = load i32, i32* %body_car_type_ptr
    %body_rest_ptr = getelementptr %ASTNode, %ASTNode* %body, i32 0, i32 5
    %body_cdr = load %ASTNode*, %ASTNode** %body_rest_ptr
    %body_cdr_null = icmp eq %ASTNode* %body_cdr, null
    br i1 %body_cdr_null, label %log_body_1elem, label %get_body_cdr_car
get_body_cdr_car:
    %body_cdr_car_ptr = getelementptr %ASTNode, %ASTNode* %body_cdr, i32 0, i32 4
    %body_cdr_car = load %ASTNode*, %ASTNode** %body_cdr_car_ptr
    %body_cdr_car_type_ptr = getelementptr %ASTNode, %ASTNode* %body_cdr_car, i32 0, i32 0
    %body_cdr_car_type = load i32, i32* %body_cdr_car_type_ptr
    %body_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %body_cdr, i32 0, i32 5
    %body_cdr_cdr = load %ASTNode*, %ASTNode** %body_cdr_cdr_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([67 x i8], [67 x i8]* @.str.debug_let_star_body_struct, i32 0, i32 0), %ASTNode* %body, i32 %body_car_type, %ASTNode* %body_cdr, i32 %body_cdr_car_type, %ASTNode* %body_cdr_cdr)
    br label %body_struct_done
log_body_1elem:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([67 x i8], [67 x i8]* @.str.debug_let_star_body_struct, i32 0, i32 0), %ASTNode* %body, i32 %body_car_type, %ASTNode* null, i32 -1, %ASTNode* null)
    br label %body_struct_done
body_struct_done:
    ; Debug: Extracted bindings and body
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_let_star_recognized, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %body_ptr = alloca %ASTNode*
    store %ASTNode* %body, %ASTNode** %body_ptr
    br label %setup_iteration
    
setup_iteration:
    ; Process bindings sequentially
    ; bindings_list is ((var1 val1) (var2 val2) ...) - a list of binding pairs
    ; We iterate through bindings_list, processing each binding pair
    %current_bindings = alloca %ASTNode*
    store %ASTNode* %bindings_list, %ASTNode** %current_bindings
    br label %bind_loop
    
bind_loop:
    ; Get current bindings list
    %bindings_iter = load %ASTNode*, %ASTNode** %current_bindings
    %bindings_iter_null = icmp eq %ASTNode* %bindings_iter, null
    br i1 %bindings_iter_null, label %debug_no_more_bindings, label %get_binding_pair
    
debug_no_more_bindings:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([34 x i8], [34 x i8]* @.str.debug_no_more_bindings, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
get_binding_pair:
    ; Debug: Processing bindings list
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_processing_bindings_list, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get the first element from the current bindings list
    ; bindings_iter is a cons cell: (binding-pair . rest)
    ; bindings_iter.car is the binding pair: (name value-expr)
    %binding_pair_car_ptr = getelementptr %ASTNode, %ASTNode* %bindings_iter, i32 0, i32 4
    %binding_val = load %ASTNode*, %ASTNode** %binding_pair_car_ptr
    
    ; Debug: Check what binding_val is
    %binding_val_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 0
    %binding_val_type = load i32, i32* %binding_val_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_binding_val_type, i32 0, i32 0), i32 %binding_val_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Check binding_val.car type (should be atom for name)
    %binding_val_car_check_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 4
    %binding_val_car_check = load %ASTNode*, %ASTNode** %binding_val_car_check_ptr
    %binding_val_car_check_null = icmp eq %ASTNode* %binding_val_car_check, null
    br i1 %binding_val_car_check_null, label %check_binding_type, label %debug_car_type
    
debug_car_type:
    %binding_val_car_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_val_car_check, i32 0, i32 0
    %binding_val_car_type = load i32, i32* %binding_val_car_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([32 x i8], [32 x i8]* @.str.debug_binding_val_car_type, i32 0, i32 0), i32 %binding_val_car_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %check_binding_type
    
    %binding_null = icmp eq %ASTNode* %binding_val, null
    br i1 %binding_null, label %debug_binding_null, label %check_binding_type
    
debug_binding_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_binding_pair_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
check_binding_type:
    ; Check if this is a list (binding pair) or something else
    %binding_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 0
    %binding_type = load i32, i32* %binding_type_ptr
    %is_list = icmp eq i32 %binding_type, 1  ; AST_NODE_TYPE_LIST = 1
    
    ; Debug: Check binding type
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_binding_type_check, i32 0, i32 0), i32 %binding_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    br i1 %is_list, label %check_binding_pair_structure, label %debug_not_list
    
debug_not_list:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_binding_not_list, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([44 x i8], [44 x i8]* @.str.debug_let_star_not_binding, i32 0, i32 0), i32 %binding_type)
    br label %eval_body
    
check_binding_pair_structure:
    ; A binding pair is: (name value-expr) where name is an atom, value-expr can be atom/literal/list
    ; The parser creates: (lexer (llvm:call ...))
    ; So binding_val.car is the name atom, binding_val.cdr is the value expression
    ; However, if binding_val.car is a list (type 1), we need to unwrap it to get the actual atom
    %binding_val_car_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 4
    %binding_name_wrapper = load %ASTNode*, %ASTNode** %binding_val_car_ptr
    %binding_name_wrapper_null = icmp eq %ASTNode* %binding_name_wrapper, null
    br i1 %binding_name_wrapper_null, label %debug_name_null, label %check_wrapper_type
    
debug_name_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_binding_name_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %eval_body
    
check_wrapper_type:
    ; Check if binding_name_wrapper is a list (needs unwrapping) or an atom (direct use)
    %wrapper_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_name_wrapper, i32 0, i32 0
    %wrapper_type = load i32, i32* %wrapper_type_ptr
    %wrapper_is_list = icmp eq i32 %wrapper_type, 1  ; AST_NODE_TYPE_LIST = 1
    br i1 %wrapper_is_list, label %unwrap_name, label %use_name_directly
    
unwrap_name:
    ; binding_name_wrapper is a list, extract the atom from its car
    %wrapper_car_ptr = getelementptr %ASTNode, %ASTNode* %binding_name_wrapper, i32 0, i32 4
    %binding_name_unwrapped = load %ASTNode*, %ASTNode** %wrapper_car_ptr
    %binding_name_unwrap_null = icmp eq %ASTNode* %binding_name_unwrapped, null
    br i1 %binding_name_unwrap_null, label %debug_name_null, label %check_name_is_atom
    
use_name_directly:
    ; binding_name_wrapper is already an atom, use it directly
    br label %check_name_is_atom
    
check_name_is_atom:
    ; Get the actual name node (either unwrapped or direct)
    %binding_name = phi %ASTNode* [%binding_name_unwrapped, %unwrap_name], [%binding_name_wrapper, %use_name_directly]
    
    ; Check if the name is an atom (identifier)
    %name_type_ptr = getelementptr %ASTNode, %ASTNode* %binding_name, i32 0, i32 0
    %name_type = load i32, i32* %name_type_ptr
    
    ; Debug: Check name type
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.str.debug_name_type_check, i32 0, i32 0), i32 %name_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %name_is_atom = icmp eq i32 %name_type, 0  ; AST_NODE_TYPE_ATOM = 0
    br i1 %name_is_atom, label %process_binding, label %debug_name_not_atom
    
debug_name_not_atom:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_name_not_atom, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([44 x i8], [44 x i8]* @.str.debug_let_star_not_binding, i32 0, i32 0), i32 %name_type)
    br label %eval_body
    
process_binding:
    ; Debug: Processing binding
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([18 x i8], [18 x i8]* @.str.debug_processing_binding, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    ; binding_name is already extracted and validated as an atom in check_name_is_atom
    ; Extract name string from the validated atom
    %name_val_ptr = getelementptr %ASTNode, %ASTNode* %binding_name, i32 0, i32 2
    %name_str = load i8*, i8** %name_val_ptr
    %name_len_ptr = getelementptr %ASTNode, %ASTNode* %binding_name, i32 0, i32 3
    %name_len = load i64, i64* %name_len_ptr
    
    ; Debug: Extracted name
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* @.str.debug_extracted_name, i32 0, i32 0))
    %name_str_debug_valid = icmp ne i8* %name_str, null
    br i1 %name_str_debug_valid, label %print_name_debug, label %skip_name_debug
    
print_name_debug:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name_debug
    
skip_name_debug:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Check if name is empty (length 0 or null pointer)
    %name_len_zero = icmp eq i64 %name_len, 0
    %name_str_null = icmp eq i8* %name_str, null
    %name_empty = or i1 %name_len_zero, %name_str_null
    br i1 %name_empty, label %eval_body, label %get_value_expr
    
get_value_expr:
    ; Get value expression (cdr.car of binding)
    ; The parser creates: (name value-expr) where name is atom, value-expr can be atom/literal/list
    ; In cons cell representation: (name . (value-expr . rest))
    ; So binding_val.cdr is the cons cell for (value-expr . rest)
    ; The value expression is binding_val.cdr.car (the actual value expression)
    %binding_cdr_ptr = getelementptr %ASTNode, %ASTNode* %binding_val, i32 0, i32 5
    %value_expr_cons = load %ASTNode*, %ASTNode** %binding_cdr_ptr
    %value_expr_cons_null = icmp eq %ASTNode* %value_expr_cons, null
    br i1 %value_expr_cons_null, label %next_binding, label %extract_value_from_cons
    
extract_value_from_cons:
    ; Extract the actual value expression from the cons cell
    %value_expr_car_ptr = getelementptr %ASTNode, %ASTNode* %value_expr_cons, i32 0, i32 4
    %value_expr = load %ASTNode*, %ASTNode** %value_expr_car_ptr
    %value_expr_null = icmp eq %ASTNode* %value_expr, null
    br i1 %value_expr_null, label %next_binding, label %eval_value
    
eval_value:
    ; value_expr is the value expression (atom, literal, or list)
    
    ; Debug: Check value_expr type
    %value_expr_type_ptr = getelementptr %ASTNode, %ASTNode* %value_expr, i32 0, i32 0
    %value_expr_type = load i32, i32* %value_expr_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_value_expr_type, i32 0, i32 0), i32 %value_expr_type)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Debug: Evaluating value expression for binding
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_local, i32 0, i32 0))
    %name_str_valid = icmp ne i8* %name_str, null
    br i1 %name_str_valid, label %print_name, label %skip_name
    
print_name:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name
    
skip_name:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str.debug_evaluating_value, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Evaluate value expression (in current scope with previous bindings)
    %value = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %value_expr)
    %value_null = icmp eq %LLVMValueRef %value, null
    br i1 %value_null, label %value_eval_failed, label %bind_value
    
value_eval_failed:
    ; Debug: Value evaluation failed
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_local, i32 0, i32 0))
    %name_str_valid_failed = icmp ne i8* %name_str, null
    br i1 %name_str_valid_failed, label %print_name_failed, label %skip_name_failed
    
print_name_failed:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name_failed
    
skip_name_failed:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([21 x i8], [21 x i8]* @.str.debug_value_eval_failed, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %next_binding
    
bind_value:
    ; Bind variable name to value
    ; Debug: About to bind local value
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([12 x i8], [12 x i8]* @.str.debug_prefix_dsl_expr, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.str.debug_binding_local_value, i32 0, i32 0))
    %name_str_bind_valid = icmp ne i8* %name_str, null
    br i1 %name_str_bind_valid, label %print_name_bind, label %skip_name_bind
    
print_name_bind:
    call i32 (i8*, ...) @printf(i8* %name_str)
    br label %skip_name_bind
    
skip_name_bind:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    call void @codegen_dsl_bind_local(%CodeGen* %cg, i8* %name_str, i64 %name_len, %LLVMValueRef %value)
    br label %next_binding
    
next_binding:
    ; Move to next binding in the bindings list
    ; Get cdr of current bindings list to get rest of bindings
    %bindings_iter_cdr_ptr = getelementptr %ASTNode, %ASTNode* %bindings_iter, i32 0, i32 5
    %bindings_iter_cdr = load %ASTNode*, %ASTNode** %bindings_iter_cdr_ptr
    %bindings_iter_cdr_null = icmp eq %ASTNode* %bindings_iter_cdr, null
    br i1 %bindings_iter_cdr_null, label %eval_body, label %update_bindings_iter
    
update_bindings_iter:
    ; Update current_bindings to point to the rest of the bindings list
    store %ASTNode* %bindings_iter_cdr, %ASTNode** %current_bindings
    br label %bind_loop
    
eval_body:
    ; Load body from body_ptr (extracted after processing bindings)
    %body_loaded = load %ASTNode*, %ASTNode** %body_ptr
    ; Evaluate body expressions in sequence (in final scope with all bindings)
    %body_null = icmp eq %ASTNode* %body_loaded, null
    br i1 %body_null, label %return_null, label %eval_body_loop
    
eval_body_loop:
    %current_expr = alloca %ASTNode*
    store %ASTNode* %body_loaded, %ASTNode** %current_expr
    %last_result = alloca %LLVMValueRef
    store %LLVMValueRef null, %LLVMValueRef* %last_result
    %body_iter_count = alloca i32
    store i32 0, i32* %body_iter_count
    br label %body_iter
    
body_iter:
    %expr_val = load %ASTNode*, %ASTNode** %current_expr
    %expr_val_null = icmp eq %ASTNode* %expr_val, null
    br i1 %expr_val_null, label %return_last, label %eval_expr
    
eval_expr:
    ; [LET*-BODY] Debug: log body iteration (H1)
    %iter_val = load i32, i32* %body_iter_count
    %iter_inc = add i32 %iter_val, 1
    store i32 %iter_inc, i32* %body_iter_count
    %body_expr_car_ptr = getelementptr %ASTNode, %ASTNode* %expr_val, i32 0, i32 4
    %body_expr_car = load %ASTNode*, %ASTNode** %body_expr_car_ptr
    %body_expr_car_type_ptr = getelementptr %ASTNode, %ASTNode* %body_expr_car, i32 0, i32 0
    %body_expr_car_type = load i32, i32* %body_expr_car_type_ptr
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([35 x i8], [35 x i8]* @.str.debug_let_star_body_iter, i32 0, i32 0), i32 %iter_inc, i32 %body_expr_car_type)
    
    ; Evaluate expression
    %expr_result = call %LLVMValueRef @codegen_eval_dsl_expr(%CodeGen* %cg, %ASTNode* %body_expr_car)
    
    ; Store result (even if null, for void expressions)
    store %LLVMValueRef %expr_result, %LLVMValueRef* %last_result
    
    ; Move to next expression
    %body_expr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %expr_val, i32 0, i32 5
    %body_expr_cdr = load %ASTNode*, %ASTNode** %body_expr_cdr_ptr
    store %ASTNode* %body_expr_cdr, %ASTNode** %current_expr
    br label %body_iter
    
return_last:
    %result = load %LLVMValueRef, %LLVMValueRef* %last_result
    ret %LLVMValueRef %result
    
return_null:
    ret %LLVMValueRef null
    
error:
    ret %LLVMValueRef null
}

; Evaluate list of DSL expressions to array
; codegen_eval_dsl_list: Evaluate list of expressions and store in array (migrated to codegen.vibe)
declare i32 @codegen_eval_dsl_list(%CodeGen* %cg, %ASTNode* %list, %LLVMValueRef* %array, i32 %max_count)

; ============================================================================
; define-llvm-function Implementation
; ============================================================================

; Handle define-llvm-function AST node
; codegen_define_llvm_function: Process define-llvm-function form using DSL
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-llvm-function form
; Returns: 0 on success, -1 on error
; Syntax: (define-llvm-function (name (param1 type1) (param2 type2) ...) return-type (dsl-body ...))
define i32 @codegen_define_llvm_function(%CodeGen* %cg, %ASTNode* %node) {
entry:
    ; Debug logging
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([40 x i8], [40 x i8]* @.str.debug_define_llvm_function_start, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Clear local_values list at start of function definition
    ; This ensures bindings from previous functions don't leak into the new function
    %local_values_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_ptr
    
    ; AST structure: LIST { ATOM: "define-llvm-function", LIST: signature, ATOM: return-type, LIST: dsl-body }
    ; Get signature list (second element)
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %node, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    %sig_list_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 4
    %sig_list = load %ASTNode*, %ASTNode** %sig_list_node_ptr
    
    ; Extract function name (first element of signature list)
    %sig_car_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 4
    %func_name_node = load %ASTNode*, %ASTNode** %sig_car_ptr
    %func_name_val_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 2
    %func_name = load i8*, i8** %func_name_val_ptr
    %func_name_len_ptr = getelementptr %ASTNode, %ASTNode* %func_name_node, i32 0, i32 3
    %func_name_len = load i64, i64* %func_name_len_ptr
    
    ; Get parameters with types (rest of signature list)
    %sig_cdr_ptr = getelementptr %ASTNode, %ASTNode* %sig_list, i32 0, i32 5
    %params_list = load %ASTNode*, %ASTNode** %sig_cdr_ptr
    
    ; Get return type (third element)
    %cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr, i32 0, i32 5
    %cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_ptr
    %return_type_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 4
    %return_type_node = load %ASTNode*, %ASTNode** %return_type_node_ptr
    %return_type_val_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 2
    %return_type = load i8*, i8** %return_type_val_ptr
    %return_type_len_ptr = getelementptr %ASTNode, %ASTNode* %return_type_node, i32 0, i32 3
    %return_type_len = load i64, i64* %return_type_len_ptr
    
    ; Get DSL body (fourth element - list)
    ; Structure: (define-llvm-function signature return-type body)
    ; cdr = (signature return-type body)
    ; cdr.cdr = (return-type body)
    ; cdr.cdr.cdr = body - this is the list of expressions (or a wrapper)
    ; Try both: cdr_cdr_cdr directly and cdr_cdr_cdr.car
    %cdr_cdr_cdr_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr, i32 0, i32 5
    %cdr_cdr_cdr = load %ASTNode*, %ASTNode** %cdr_cdr_cdr_ptr
    
    ; Debug logging - log DSL body extraction
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([30 x i8], [30 x i8]* @.str.debug_extracting_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    %cdr_cdr_cdr_null = icmp eq %ASTNode* %cdr_cdr_cdr, null
    br i1 %cdr_cdr_cdr_null, label %error, label %try_body_direct
    
try_body_direct:
    ; First try: use cdr_cdr_cdr directly as the body
    ; Check if it's a list (AST_LIST = 1)
    %cdr_cdr_cdr_type_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 0
    %cdr_cdr_cdr_type = load i32, i32* %cdr_cdr_cdr_type_ptr
    %is_list_direct = icmp eq i32 %cdr_cdr_cdr_type, 1  ; AST_LIST
    br i1 %is_list_direct, label %use_direct_body, label %try_body_car
    
use_direct_body:
    ; Use cdr_cdr_cdr directly as the body
    br label %check_body_done
    
try_body_car:
    ; Second try: use cdr_cdr_cdr.car as the body
    %dsl_body_node_ptr = getelementptr %ASTNode, %ASTNode* %cdr_cdr_cdr, i32 0, i32 4
    %dsl_body_car = load %ASTNode*, %ASTNode** %dsl_body_node_ptr
    br label %check_body_done
    
check_body_done:
    %dsl_body = phi %ASTNode* [ %cdr_cdr_cdr, %use_direct_body ], [ %dsl_body_car, %try_body_car ]
    
    ; Debug logging - log extracted DSL body
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([28 x i8], [28 x i8]* @.str.debug_dsl_body_extracted, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Get LLVM context and module
    %context_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 5
    %context = load %LLVMContextRef, %LLVMContextRef* %context_ptr
    %module_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 6
    %module = load %LLVMModuleRef, %LLVMModuleRef* %module_ptr
    
    %context_null = icmp eq %LLVMContextRef %context, null
    %module_null = icmp eq %LLVMModuleRef %module, null
    %any_null = or i1 %context_null, %module_null
    br i1 %any_null, label %error, label %resolve_return_type
    
resolve_return_type:
    ; Resolve return type string to LLVMTypeRef
    %return_type_ref = call %LLVMTypeRef @codegen_resolve_type_string(%CodeGen* %cg, i8* %return_type, i64 %return_type_len)
    %return_type_null = icmp eq %LLVMTypeRef %return_type_ref, null
    br i1 %return_type_null, label %error, label %collect_params
    
collect_params:
    ; Collect parameter types
    ; Allocate array for parameter types (max 10 params)
    %param_types_array = call i8* @malloc(i64 80)  ; 10 * 8 bytes
    %param_types_ptr = bitcast i8* %param_types_array to %LLVMTypeRef*
    
    ; Count and resolve parameter types
    %param_count = call i32 @codegen_collect_param_types(%CodeGen* %cg, %ASTNode* %params_list, %LLVMTypeRef* %param_types_ptr, i32 10)
    
    ; Debug: Print parameter count collected
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([31 x i8], [31 x i8]* @.str.debug_collected_param_count, i32 0, i32 0), i32 %param_count)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    
    ; Create function type
    ; If param_count is 0, pass null for param_types (LLVM requirement)
    %has_params = icmp ne i32 %param_count, 0
    br i1 %has_params, label %create_func_type_with_params, label %create_func_type_no_params
    
create_func_type_with_params:
    %func_type = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* %param_types_ptr, i32 %param_count, i32 0)
    br label %check_func_type
    
create_func_type_no_params:
    %func_type_no_params = call %LLVMTypeRef @llvm_create_function_type(%LLVMTypeRef %return_type_ref, %LLVMTypeRef* null, i32 0, i32 0)
    br label %check_func_type
    
check_func_type:
    %func_type_phi = phi %LLVMTypeRef [ %func_type, %create_func_type_with_params ], [ %func_type_no_params, %create_func_type_no_params ]
    %param_types_array_phi = phi i8* [ %param_types_array, %create_func_type_with_params ], [ %param_types_array, %create_func_type_no_params ]
    %func_type_null = icmp eq %LLVMTypeRef %func_type_phi, null
    br i1 %func_type_null, label %free_param_types, label %add_function
    
free_param_types:
    call void @free(i8* %param_types_array_phi)
    br label %error
    
add_function:
    ; Add function to module (or reuse existing forward declaration)
    ; Create null-terminated function name
    %func_name_buf_plus1 = add i64 %func_name_len, 1
    %func_name_buf_full = call i8* @malloc(i64 %func_name_buf_plus1)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %func_name_buf_full, i8* %func_name, i64 %func_name_len, i1 false)
    %null_ptr = getelementptr i8, i8* %func_name_buf_full, i64 %func_name_len
    store i8 0, i8* %null_ptr
    
    ; Check if function already exists (e.g. from a forward declaration)
    %existing_func = call %LLVMValueRef @llvm_get_named_function(%LLVMModuleRef %module, i8* %func_name_buf_full)
    %existing_null = icmp eq %LLVMValueRef %existing_func, null
    br i1 %existing_null, label %create_new_function, label %reuse_existing_function

create_new_function:
    %new_func = call %LLVMValueRef @llvm_add_function(%LLVMModuleRef %module, i8* %func_name_buf_full, %LLVMTypeRef %func_type_phi)
    call void @free(i8* %func_name_buf_full)
    %new_func_null = icmp eq %LLVMValueRef %new_func, null
    br i1 %new_func_null, label %free_param_types, label %set_param_names

reuse_existing_function:
    ; Reuse the existing forward declaration - the definition body will be added to it
    call void @free(i8* %func_name_buf_full)
    br label %set_param_names
    
set_param_names:
    ; Merge function value from either new creation or reuse of existing declaration
    %func = phi %LLVMValueRef [ %new_func, %create_new_function ], [ %existing_func, %reuse_existing_function ]
    
    ; Create entry basic block FIRST (required before accessing parameters)
    ; Use non-null name (some LLVM versions may require this)
    %entry_block_name = bitcast [6 x i8]* @.str.entry_block_name to i8*
    %entry_bb = call %LLVMBasicBlockRef @llvm_append_basic_block(%LLVMValueRef %func, i8* %entry_block_name)
    
    ; Create builder BEFORE accessing parameters (builder positioning may initialize function state)
    %builder = call %LLVMBuilderRef @llvm_create_builder(%LLVMContextRef %context)
    %builder_null = icmp eq %LLVMBuilderRef %builder, null
    br i1 %builder_null, label %free_param_types, label %position_builder
    
position_builder:
    ; Position builder at end of entry block (this may initialize function's parameter list)
    call void @llvm_position_builder_at_end(%LLVMBuilderRef %builder, %LLVMBasicBlockRef %entry_bb)
    
    ; Debug: Check params_list before calling build_param_names
    %params_list_null_pre = icmp eq %ASTNode* %params_list, null
    br i1 %params_list_null_pre, label %debug_params_null_pre, label %debug_params_ok_pre
    
debug_params_null_pre:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([48 x i8], [48 x i8]* @.str.debug_params_list_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %call_build_param_names
    
debug_params_ok_pre:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([43 x i8], [43 x i8]* @.str.debug_params_list_ok, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.debug_not_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %call_build_param_names
    
call_build_param_names:
    ; NOW set parameter names and build parameter mapping (after builder is positioned)
    %param_names_list = call %ASTNode* @codegen_build_param_names(%CodeGen* %cg, %LLVMValueRef %func, %ASTNode* %params_list)
    
    ; Debug: Check if param_names_list is null
    %param_names_list_null = icmp eq %ASTNode* %param_names_list, null
    br i1 %param_names_list_null, label %debug_param_names_null, label %debug_param_names_ok
    
debug_param_names_null:
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([33 x i8], [33 x i8]* @.str.debug_param_names_null, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %continue_after_param_debug
    
debug_param_names_ok:
    br label %continue_after_param_debug
    
continue_after_param_debug:
    ; Store function and builder in CodeGen
    %current_function_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 8
    store %LLVMValueRef %func, %LLVMValueRef* %current_function_ptr
    
    %builder_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 7
    store %LLVMBuilderRef %builder, %LLVMBuilderRef* %builder_ptr
    
    %param_names_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 9
    store %ASTNode* %param_names_list, %ASTNode** %param_names_ptr
    
    ; Store function for later retrieval during function calls
    call void @codegen_store_llvm_function(%CodeGen* %cg, i8* %func_name, i64 %func_name_len, %LLVMValueRef %func, %LLVMTypeRef %func_type_phi)
    
    ; Evaluate DSL body (this should generate a return statement)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_evaluating_dsl_body, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    call void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %dsl_body)
    
    ; Visitor pattern exit check: verify the entry block has a terminator
    ; Every basic block must have a terminator (br, ret, etc.)
    ; If the DSL body didn't terminate the entry block, that's a compilation error.
    %entry_terminator = call %LLVMValueRef @llvm_get_basic_block_terminator(%LLVMBasicBlockRef %entry_bb)
    %entry_has_no_term = icmp eq %LLVMValueRef %entry_terminator, null
    br i1 %entry_has_no_term, label %entry_missing_terminator, label %cleanup_builder
    
entry_missing_terminator:
    ; Report compilation error: entry block has no terminator
    call i32 (i8*, ...) @printf(
        i8* getelementptr inbounds ([55 x i8], [55 x i8]* @.str.err_entry_no_terminator, i32 0, i32 0),
        i8* %func_name)
    br label %error
    
cleanup_builder:
    ; Clean up builder
    call void @llvm_dispose_builder(%LLVMBuilderRef %builder)
    
    ; Clear DSL evaluation fields
    store %LLVMValueRef null, %LLVMValueRef* %current_function_ptr
    store %LLVMBuilderRef null, %LLVMBuilderRef* %builder_ptr
    store %ASTNode* null, %ASTNode** %param_names_ptr
    
    ; Clear local_values list at end of function definition
    ; This ensures bindings don't leak to the next function
    %local_values_cleanup_ptr = getelementptr %CodeGen, %CodeGen* %cg, i32 0, i32 10
    store %ASTNode* null, %ASTNode** %local_values_cleanup_ptr
    
    ; Free param types array
    call void @free(i8* %param_types_array)
    
    ret i32 0
    
error:
    ret i32 -1
}

; Handle define-llvm-ffi-function AST node
; codegen_define_llvm_ffi_function: Process define-llvm-ffi-function form using FFI
; Parameters:
;   cg: Pointer to CodeGen structure
;   node: AST node for define-llvm-ffi-function form
; Returns: 0 on success, -1 on error
; Syntax: (define-llvm-ffi-function (name (param1 type1) (param2 type2) ...) return-type (library-name symbol-name) [is-vararg])
; codegen_define_llvm_ffi_function: Migrated to kernel/codegen.vibe
declare i32 @codegen_define_llvm_ffi_function(%CodeGen* %cg, %ASTNode* %node)

; ============================================================================
; declare-llvm-function Implementation
; ============================================================================

; Handle declare-llvm-function AST node
; codegen_declare_llvm_function: Migrated to kernel/codegen.vibe
declare i32 @codegen_declare_llvm_function(%CodeGen* %cg, %ASTNode* %node)

; codegen_collect_param_types: Migrated to kernel/codegen.vibe
declare i32 @codegen_collect_param_types(%CodeGen* %cg, %ASTNode* %params, %LLVMTypeRef* %array, i32 %max_count)

; Build parameter names mapping
; codegen_build_param_names: Create AST list of (name index) pairs
; Parameters:
;   cg: Pointer to CodeGen structure
;   func: LLVMValueRef for function
;   params: AST node list of (param-name type) pairs
; Returns: ASTNode* list of (name index) pairs
define %ASTNode* @codegen_build_param_names(%CodeGen* %cg, %LLVMValueRef %func, %ASTNode* %params) {
entry:
    %params_null = icmp eq %ASTNode* %params, null
    br i1 %params_null, label %return_null, label %build_list
    
return_null:
    ret %ASTNode* null
    
build_list:
    %result = alloca %ASTNode*
    store %ASTNode* null, %ASTNode** %result
    %current = alloca %ASTNode*
    store %ASTNode* %params, %ASTNode** %current
    %index = alloca i32
    store i32 0, i32* %index
    br label %build_loop
    
build_loop:
    %current_val = load %ASTNode*, %ASTNode** %current
    %current_null = icmp eq %ASTNode* %current_val, null
    br i1 %current_null, label %return_result, label %create_pair
    
create_pair:
    ; Get param pair: (param-name type)
    %car_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 4
    %param_pair = load %ASTNode*, %ASTNode** %car_ptr
    %param_pair_null = icmp eq %ASTNode* %param_pair, null
    br i1 %param_pair_null, label %skip_pair, label %get_param_name
    
get_param_name:
    ; Get param name (first element of pair)
    ; param_pair is (name type), so param_pair.car should be the name atom
    %pair_car_ptr = getelementptr %ASTNode, %ASTNode* %param_pair, i32 0, i32 4
    %param_name_node = load %ASTNode*, %ASTNode** %pair_car_ptr
    %param_name_node_null = icmp eq %ASTNode* %param_name_node, null
    br i1 %param_name_node_null, label %skip_pair, label %check_name_node_type
    
check_name_node_type:
    ; Check if name node is actually an atom (type 0)
    %name_node_type_check_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 0
    %name_node_type_check = load i32, i32* %name_node_type_check_ptr
    %is_atom_check = icmp eq i32 %name_node_type_check, 0  ; AST_ATOM
    br i1 %is_atom_check, label %check_name_node, label %try_extract_from_list
    
try_extract_from_list:
    ; If name node is a list, try to extract the atom from it
    ; This might happen if the parameter structure is different than expected
    %list_car_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node, i32 0, i32 4
    %list_car = load %ASTNode*, %ASTNode** %list_car_ptr
    %list_car_null = icmp eq %ASTNode* %list_car, null
    br i1 %list_car_null, label %skip_pair, label %check_list_car_type
    
check_list_car_type:
    ; Check if car is an atom
    %list_car_type_ptr = getelementptr %ASTNode, %ASTNode* %list_car, i32 0, i32 0
    %list_car_type = load i32, i32* %list_car_type_ptr
    %list_car_is_atom = icmp eq i32 %list_car_type, 0  ; AST_ATOM
    br i1 %list_car_is_atom, label %use_list_car, label %skip_pair
    
use_list_car:
    ; Use the atom from the list as the name node
    br label %check_name_node
    
check_name_node:
    ; Get the correct name node (either original or extracted from list)
    %param_name_node_phi = phi %ASTNode* [ %param_name_node, %check_name_node_type ], [ %list_car, %use_list_car ]
    ; Debug: Check name node value
    %name_val_check_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node_phi, i32 0, i32 2
    %name_val_check = load i8*, i8** %name_val_check_ptr
    %name_len_check_ptr = getelementptr %ASTNode, %ASTNode* %param_name_node_phi, i32 0, i32 3
    %name_len_check = load i64, i64* %name_len_check_ptr
    
    ; Debug logging - print name node info
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([11 x i8], [11 x i8]* @.str.debug_prefix_codegen, i32 0, i32 0))
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([25 x i8], [25 x i8]* @.str.debug_building_param_name, i32 0, i32 0))
    %name_val_check_null = icmp eq i8* %name_val_check, null
    %name_len_check_zero = icmp eq i64 %name_len_check, 0
    %name_check_invalid = or i1 %name_val_check_null, %name_len_check_zero
    br i1 %name_check_invalid, label %print_name_invalid, label %print_name_valid
    
print_name_invalid:
    %is_null_msg_build = select i1 %name_val_check_null, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.debug_null, i32 0, i32 0), i8* getelementptr inbounds ([8 x i8], [8 x i8]* @.str.debug_empty_str, i32 0, i32 0)
    call i32 (i8*, ...) @printf(i8* %is_null_msg_build)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %skip_pair
    
print_name_valid:
    ; Print name value
    %name_buf_build = call i8* @malloc(i64 %name_len_check)
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %name_buf_build, i8* %name_val_check, i64 %name_len_check, i1 false)
    %name_null_build = getelementptr i8, i8* %name_buf_build, i64 %name_len_check
    store i8 0, i8* %name_null_build
    call i32 (i8*, ...) @printf(i8* %name_buf_build)
    call void @free(i8* %name_buf_build)
    call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.debug_newline, i32 0, i32 0))
    br label %get_index
    
get_index:
    ; Get current index
    %index_val = load i32, i32* %index
    
    ; Always store the index - we'll look up the parameter value later during DSL evaluation
    ; when the function is fully initialized. This avoids issues with LLVMGetParam returning
    ; null when called before the function is fully set up.
    ; Create an index node to store
    %index_node = call %ASTNode* @codegen_create_int_node(i32 %index_val)
    
    ; Create (name . index) pair - we'll look up the parameter value when resolving
    %name_index_pair = call %ASTNode* @codegen_create_pair(%ASTNode* %param_name_node_phi, %ASTNode* %index_node)
    
    ; Prepend to result list
    %result_val = load %ASTNode*, %ASTNode** %result
    %new_cons = call %ASTNode* @codegen_create_cons(%ASTNode* %name_index_pair, %ASTNode* %result_val)
    store %ASTNode* %new_cons, %ASTNode** %result
    
    ; Increment index and move to next
    %index_new = add i32 %index_val, 1
    store i32 %index_new, i32* %index
    br label %move_to_next_param
    
skip_pair:
    ; Skip this pair if it's invalid - move to next without incrementing index
    br label %move_to_next_param
    
move_to_next_param:
    %cdr_ptr = getelementptr %ASTNode, %ASTNode* %current_val, i32 0, i32 5
    %cdr = load %ASTNode*, %ASTNode** %cdr_ptr
    store %ASTNode* %cdr, %ASTNode** %current
    
    ; NOTE: We skip setting parameter names in LLVM for now because LLVMGetParam
    ; triggers BuildLazyArguments() which can crash if the function state isn't fully initialized.
    ; Parameter names aren't strictly necessary for code generation - we can access parameters
    ; by index. We'll set names later if needed, or skip them entirely.
    ; The mapping we're building (name -> index) is sufficient for DSL evaluation.
    
    br label %build_loop
    
return_result:
    %result_ret = load %ASTNode*, %ASTNode** %result
    ret %ASTNode* %result_ret
}

; Create integer AST node


; codegen_create_pair: defined in codegen.vibe
declare %ASTNode* @codegen_create_pair(%ASTNode*, %ASTNode*)

; codegen_create_cons: defined in codegen.vibe
declare %ASTNode* @codegen_create_cons(%ASTNode*, %ASTNode*)

; codegen_create_string_node: defined in codegen.vibe
declare %ASTNode* @codegen_create_string_node(i8*, i64)

; codegen_format_string_name: defined in codegen.vibe
declare i8* @codegen_format_string_name(i32)

; codegen_format_number: defined in codegen.vibe
declare i8* @codegen_format_number(i64)

; codegen_store_type: defined in codegen.vibe
declare void @codegen_store_type(%CodeGen*, i8*, i64, %LLVMTypeRef)

; codegen_get_type: defined in codegen.vibe
declare %LLVMTypeRef @codegen_get_type(%CodeGen*, i8*, i64)

; codegen_store_function_type: defined in codegen.vibe
declare void @codegen_store_function_type(%CodeGen*, i8*, i64, %LLVMTypeRef)

; codegen_get_function_type: defined in codegen.vibe
declare %LLVMTypeRef @codegen_get_function_type(%CodeGen*, i8*, i64)

; codegen_int_to_string: defined in codegen.vibe
declare i64 @codegen_int_to_string(i32, i8*)

; codegen_create_int_node: defined in codegen.vibe
declare %ASTNode* @codegen_create_int_node(i32)


; codegen_get_function_type_by_value: defined in codegen.vibe
declare %LLVMTypeRef @codegen_get_function_type_by_value(%CodeGen* %cg, %LLVMValueRef %func_value)

; codegen_dsl_undef: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_undef(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_insertvalue: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_insertvalue(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_extractvalue(%CodeGen* %cg, %ASTNode* %args)

; codegen_dsl_urem: Migrated to kernel/codegen.vibe
declare %LLVMValueRef @codegen_dsl_urem(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_udiv(%CodeGen* %cg, %ASTNode* %args)

declare %LLVMValueRef @codegen_dsl_ptrtoint(%CodeGen* %cg, %ASTNode* %args)

; codegen_eval_dsl_body: Migrated to kernel/codegen.vibe
declare void @codegen_eval_dsl_body(%CodeGen* %cg, %ASTNode* %body)

; Declare external functions
declare i8* @malloc(i64)
declare i8* @realloc(i8*, i64)
declare void @free(i8*)
declare i64 @strlen(i8*)
declare i32 @memcmp(i8*, i8*, i64)
declare i32 @strncmp(i8*, i8*, i32)
; LLVM memcpy intrinsic - signature matches runtime.ll
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
