	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 15
	.p2align	4, 0x90         ## -- Begin function hash_symbol
l_hash_symbol:                          ## @hash_symbol
	.cfi_startproc
## %bb.0:                               ## %entry
	movq	$5381, -16(%rsp)        ## imm = 0x1505
	movq	$0, -8(%rsp)
	jmp	LBB0_1
	.p2align	4, 0x90
LBB0_2:                                 ## %continue_hash
                                        ##   in Loop: Header=BB0_1 Depth=1
	movq	-16(%rsp), %rdx
	movzbl	(%rdi,%rax), %r8d
	movq	%rdx, %rcx
	shlq	$5, %rcx
	addq	%rdx, %rcx
	addq	%r8, %rcx
	movq	%rcx, -16(%rsp)
	incq	%rax
	movq	%rax, -8(%rsp)
LBB0_1:                                 ## %hash_loop
                                        ## =>This Inner Loop Header: Depth=1
	movq	-8(%rsp), %rax
	cmpq	%rsi, %rax
	jne	LBB0_2
## %bb.3:                               ## %finalize
	movq	-16(%rsp), %rcx
	movabsq	$4736576211504157687, %rdx ## imm = 0x41BBB2F80A4553F7
	movq	%rcx, %rax
	mulq	%rdx
	shrq	$8, %rdx
	imulq	$997, %rdx, %rax        ## imm = 0x3E5
	subq	%rax, %rcx
	movq	%rcx, %rax
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function create_symbol_entry
l_create_symbol_entry:                  ## @create_symbol_entry
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r13
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r13, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdx, %r14
	movq	%rsi, %r12
	movq	%rdi, %r15
	leaq	24(%r12), %rdi
	callq	_malloc
	movq	%rax, %rbx
	movq	%r12, %rdi
	callq	_malloc
	movq	%rax, %r13
	movq	%r13, %rdi
	movq	%r15, %rsi
	movq	%r12, %rdx
	callq	_memcpy
	movq	%r13, (%rbx)
	movq	%r12, 8(%rbx)
	movq	%r14, 16(%rbx)
	movq	$0, 24(%rbx)
	movq	%rbx, %rax
	popq	%rbx
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_register_function      ## -- Begin function register_function
	.p2align	4, 0x90
_register_function:                     ## @register_function
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	pushq	%rax
	.cfi_def_cfa_offset 64
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rdx, %r14
	movq	%rsi, %r12
	movq	%rdi, %r13
	callq	l_hash_symbol
	movq	%rax, %r15
	leaq	_symbol_table(%rip), %rbp
	movq	(%rbp,%r15,8), %rbx
	movq	%r13, %rdi
	movq	%r12, %rsi
	movq	%r14, %rdx
	callq	l_create_symbol_entry
	testq	%rbx, %rbx
	je	LBB2_1
	.p2align	4, 0x90
LBB2_3:                                 ## %traverse
                                        ## =>This Inner Loop Header: Depth=1
	movq	%rbx, %rcx
	movq	24(%rcx), %rbx
	testq	%rbx, %rbx
	jne	LBB2_3
## %bb.4:                               ## %append
	movq	%rax, 24(%rcx)
	jmp	LBB2_2
LBB2_1:                                 ## %insert
	movq	%rax, (%rbp,%r15,8)
LBB2_2:                                 ## %insert
	addq	$8, %rsp
	popq	%rbx
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_lookup_function        ## -- Begin function lookup_function
	.p2align	4, 0x90
_lookup_function:                       ## @lookup_function
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rsi, %r15
	movq	%rdi, %r14
	callq	l_hash_symbol
	leaq	_symbol_table(%rip), %rcx
	movq	(%rcx,%rax,8), %rbx
	testq	%rbx, %rbx
	jne	LBB3_2
	jmp	LBB3_6
	.p2align	4, 0x90
LBB3_4:                                 ## %next_entry
                                        ##   in Loop: Header=BB3_2 Depth=1
	movq	24(%rbx), %rbx
	testq	%rbx, %rbx
	je	LBB3_6
LBB3_2:                                 ## %check_symbol
                                        ## =>This Inner Loop Header: Depth=1
	cmpq	%r15, 8(%rbx)
	jne	LBB3_4
## %bb.3:                               ## %compare_strings
                                        ##   in Loop: Header=BB3_2 Depth=1
	movq	(%rbx), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	_memcmp
	testl	%eax, %eax
	jne	LBB3_4
## %bb.5:                               ## %found
	movq	16(%rbx), %rax
	jmp	LBB3_7
LBB3_6:                                 ## %not_found
	xorl	%eax, %eax
LBB3_7:                                 ## %not_found
	popq	%rbx
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function list_next
l_list_next:                            ## @list_next
	.cfi_startproc
## %bb.0:                               ## %entry
	testq	%rdi, %rdi
	je	LBB4_2
## %bb.1:                               ## %get_values
	movq	(%rdi), %rax
	movq	8(%rdi), %rdx
	retq
LBB4_2:                                 ## %return_null
	xorl	%eax, %eax
	xorl	%edx, %edx
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function compile_bitcode
l_compile_bitcode:                      ## @compile_bitcode
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	pushq	%r15
	pushq	%r14
	pushq	%r13
	pushq	%r12
	pushq	%rbx
	pushq	%rax
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	movq	%rdi, %rbx
	callq	_LLVMContextCreate
	movq	%rax, %r14
	leaq	L_.str.module(%rip), %rsi
	movq	%rbx, %rdi
	callq	_LLVMCreateMemoryBufferWithString
	movq	%rax, %r12
	leaq	-48(%rbp), %rdx
	movq	%r14, %rdi
	movq	%r12, %rsi
	callq	_LLVMParseIRInContext
	movq	%rax, %r15
	movq	-48(%rbp), %rdi
	testq	%rdi, %rdi
	je	LBB5_4
## %bb.1:                               ## %handle_error
	callq	_LLVMDisposeMessage
	jmp	LBB5_2
LBB5_4:                                 ## %create_engine
	movq	%rsp, %rbx
	addq	$-16, %rbx
	movq	%rbx, %rsp
	movq	%rsp, %r13
	leaq	-16(%r13), %rdx
	movq	%rdx, %rsp
	movq	%rbx, %rdi
	movq	%r15, %rsi
	callq	_LLVMCreateExecutionEngineForModule
	movq	-16(%r13), %rdi
	testq	%rdi, %rdi
	je	LBB5_6
## %bb.5:                               ## %handle_engine_error
	callq	_LLVMDisposeMessage
	movq	%r15, %rdi
	callq	_LLVMDisposeModule
LBB5_2:                                 ## %handle_error
	movq	%r12, %rdi
	callq	_LLVMDisposeMemoryBuffer
	movq	%r14, %rdi
	callq	_LLVMContextDispose
	xorl	%eax, %eax
LBB5_3:                                 ## %handle_error
	leaq	-40(%rbp), %rsp
	popq	%rbx
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	popq	%rbp
	retq
LBB5_6:                                 ## %get_function
	movq	(%rbx), %rbx
	leaq	L_.str.func(%rip), %rsi
	movq	%rbx, %rdi
	callq	_LLVMGetFunctionAddress
	movq	%rax, %r15
	movq	%rbx, %rdi
	callq	_LLVMDisposeExecutionEngine
	movq	%r12, %rdi
	callq	_LLVMDisposeMemoryBuffer
	movq	%r14, %rdi
	callq	_LLVMContextDispose
	movq	%r15, %rax
	jmp	LBB5_3
	.cfi_endproc
                                        ## -- End function
	.globl	_register_primitives    ## -- Begin function register_primitives
	.p2align	4, 0x90
_register_primitives:                   ## @register_primitives
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	leaq	L_.str.plus(%rip), %rdi
	leaq	_scheme_plus(%rip), %rdx
	movl	$1, %esi
	callq	_register_function
	leaq	L_.str.minus(%rip), %rdi
	leaq	_scheme_minus(%rip), %rdx
	movl	$1, %esi
	callq	_register_function
	leaq	L_.str.define_bitcode(%rip), %rdi
	leaq	_scheme_define_bitcode(%rip), %rdx
	movl	$14, %esi
	callq	_register_function
	popq	%rax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_scheme_plus            ## -- Begin function scheme_plus
	.p2align	4, 0x90
_scheme_plus:                           ## @scheme_plus
	.cfi_startproc
## %bb.0:
	xorl	%eax, %eax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_scheme_minus           ## -- Begin function scheme_minus
	.p2align	4, 0x90
_scheme_minus:                          ## @scheme_minus
	.cfi_startproc
## %bb.0:
	xorl	%eax, %eax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_scheme_define_bitcode  ## -- Begin function scheme_define_bitcode
	.p2align	4, 0x90
_scheme_define_bitcode:                 ## @scheme_define_bitcode
	.cfi_startproc
## %bb.0:
	xorl	%eax, %eax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_init_runtime           ## -- Begin function init_runtime
	.p2align	4, 0x90
_init_runtime:                          ## @init_runtime
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_register_primitives
	popq	%rax
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__literal8,8byte_literals
	.p2align	3               ## @HASH_TABLE_SIZE
L_HASH_TABLE_SIZE:
	.quad	997                     ## 0x3e5

	.globl	_symbol_table           ## @symbol_table
.zerofill __DATA,__common,_symbol_table,7976,4
	.section	__TEXT,__cstring,cstring_literals
L_.str.module:                          ## @.str.module
	.asciz	"module"

L_.str.func:                            ## @.str.func
	.asciz	"func"

L_.str.define_bitcode:                  ## @.str.define_bitcode
	.asciz	"define-bitcode"

L_.str.plus:                            ## @.str.plus
	.asciz	"+"

L_.str.minus:                           ## @.str.minus
	.asciz	"-"


.subsections_via_symbols
