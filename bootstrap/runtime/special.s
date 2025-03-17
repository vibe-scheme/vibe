	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 15
	.globl	_handle_define          ## -- Begin function handle_define
	.p2align	4, 0x90
_handle_define:                         ## @handle_define
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%rbx
	.cfi_def_cfa_offset 40
	pushq	%rax
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rsi, %r15
	movq	%rdi, %rbx
	callq	_car
	movl	%eax, %ebp
	movq	%rdx, %r14
	movl	%ebp, %edi
	movq	%r14, %rsi
	callq	_get_type
	movq	_TAG_SYMBOL@GOTPCREL(%rip), %rcx
	cmpl	(%rcx), %eax
	jne	LBB0_2
## %bb.1:                               ## %valid_symbol
	movq	%rbx, %rdi
	callq	_cdr
	movq	%rax, %rdi
	callq	_car
	movl	%eax, %edi
	movq	%rdx, %rsi
	movq	%r15, %rdx
	callq	_eval
	movl	%eax, %ebx
	movq	%rdx, %r15
	movl	%ebp, %edi
	movq	%r14, %rsi
	callq	_get_value_ptr
	movq	(%rax), %rsi
	leaq	8(%rax), %rdi
	movl	%ebx, %edx
	movq	%r15, %rcx
	callq	_define_symbol
	movl	%ebx, %eax
	movq	%r15, %rdx
	jmp	LBB0_3
LBB0_2:                                 ## %type_error
	movq	_TAG_NIL@GOTPCREL(%rip), %rax
	movl	(%rax), %edi
	xorl	%esi, %esi
	callq	_create_value
LBB0_3:                                 ## %type_error
	addq	$8, %rsp
	popq	%rbx
	popq	%r14
	popq	%r15
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_handle_bitcode_lambda  ## -- Begin function handle_bitcode_lambda
	.p2align	4, 0x90
_handle_bitcode_lambda:                 ## @handle_bitcode_lambda
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	pushq	%r15
	pushq	%r14
	pushq	%r12
	pushq	%rbx
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	movq	%rdi, %rbx
	callq	_car
	movl	%eax, %edi
	movq	%rdx, %rsi
	callq	_get_type
	movq	_TAG_LIST@GOTPCREL(%rip), %rcx
	cmpl	(%rcx), %eax
	jne	LBB1_6
## %bb.1:                               ## %valid_params
	movq	%rbx, %rdi
	callq	_cdr
	movq	%rax, %rdi
	callq	_car
	movl	%eax, %ebx
	movq	%rdx, %r14
	movl	%ebx, %edi
	movq	%r14, %rsi
	callq	_get_type
	testl	%eax, %eax
	jne	LBB1_6
## %bb.2:                               ## %compile_bitcode
	movl	%ebx, %edi
	movq	%r14, %rsi
	callq	_get_value_ptr
	leaq	8(%rax), %rbx
	callq	_LLVMContextCreate
	movq	%rax, %r14
	leaq	L_.str.anon_fn(%rip), %rsi
	movq	%rbx, %rdi
	callq	_LLVMCreateMemoryBufferWithString
	movq	%rax, %r15
	movq	%rsp, %rbx
	addq	$-16, %rbx
	movq	%rbx, %rsp
	movq	%rsp, %rcx
	addq	$-16, %rcx
	movq	%rcx, %rsp
	movq	%r14, %rdi
	movq	%r15, %rsi
	movq	%rbx, %rdx
	callq	_LLVMParseIRInContext
	testl	%eax, %eax
	jne	LBB1_5
## %bb.3:                               ## %create_engine
	movq	%rsp, %r12
	addq	$-16, %r12
	movq	%r12, %rsp
	movq	%rsp, %rdx
	addq	$-16, %rdx
	movq	%rdx, %rsp
	movq	(%rbx), %rsi
	movq	%r12, %rdi
	callq	_LLVMCreateExecutionEngineForModule
	testl	%eax, %eax
	je	LBB1_4
LBB1_5:                                 ## %cleanup_engine_error
	movq	%r15, %rdi
	callq	_LLVMDisposeMemoryBuffer
	movq	%r14, %rdi
	callq	_LLVMContextDispose
LBB1_6:                                 ## %type_error
	movq	_TAG_NIL@GOTPCREL(%rip), %rax
	movl	(%rax), %edi
	xorl	%esi, %esi
LBB1_7:                                 ## %type_error
	callq	_create_value
	leaq	-32(%rbp), %rsp
	popq	%rbx
	popq	%r12
	popq	%r14
	popq	%r15
	popq	%rbp
	retq
LBB1_4:                                 ## %get_function
	movq	(%r12), %rdi
	leaq	L_.str.anon_fn(%rip), %rsi
	callq	_LLVMGetFunctionAddress
	movq	_TAG_FUNCTION@GOTPCREL(%rip), %rcx
	movl	(%rcx), %edi
	movq	%rax, %rsi
	jmp	LBB1_7
	.cfi_endproc
                                        ## -- End function
	.globl	_register_special_forms ## -- Begin function register_special_forms
	.p2align	4, 0x90
_register_special_forms:                ## @register_special_forms
	.cfi_startproc
## %bb.0:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	leaq	L_.str.define(%rip), %rdi
	movl	_TAG_FUNCTION@GOTPCREL(%rip), %ebx
	leaq	_handle_define(%rip), %rcx
	movl	$6, %esi
	movl	%ebx, %edx
	callq	_define_symbol
	leaq	L_.str.bitcode_lambda(%rip), %rdi
	leaq	_handle_bitcode_lambda(%rip), %rcx
	movl	$14, %esi
	movl	%ebx, %edx
	callq	_define_symbol
	popq	%rbx
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__cstring,cstring_literals
L_.str.define:                          ## @.str.define
	.asciz	"define"

L_.str.bitcode_lambda:                  ## @.str.bitcode_lambda
	.asciz	"bitcode-lambda"

L_.str.anon_fn:                         ## @.str.anon_fn
	.asciz	"anon_fn"


.subsections_via_symbols
