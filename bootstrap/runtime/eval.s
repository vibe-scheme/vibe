	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 15
	.globl	_eval                   ## -- Begin function eval
	.p2align	4, 0x90
_eval:                                  ## @eval
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rdx, %r14
	movq	%rsi, %r12
	movl	%edi, %ebp
	callq	_get_type
	movl	%eax, %ebx
	movl	%ebx, %edi
	callq	l_is_symbol
	testb	$1, %al
	je	LBB0_1
## %bb.6:                               ## %eval_symbol
	movl	%ebp, %edi
	movq	%r12, %rsi
	callq	_get_value_ptr
	movq	(%rax), %rsi
	leaq	8(%rax), %rdi
	callq	_lookup_symbol
	jmp	LBB0_5
LBB0_1:                                 ## %check_list
	movl	%ebx, %edi
	callq	l_is_list
	testb	$1, %al
	je	LBB0_4
## %bb.2:                               ## %eval_list
	movl	%ebp, %edi
	movq	%r12, %rsi
	callq	_get_value_ptr
	movq	%rax, %r15
	testq	%r15, %r15
	je	LBB0_4
## %bb.3:                               ## %eval_application
	movq	%r15, %rdi
	callq	_car
	movl	%eax, %edi
	movq	%rdx, %rsi
	movq	%r14, %rdx
	callq	_eval
	movl	%eax, %ebx
	movq	%rdx, %rbp
	movq	%r15, %rdi
	callq	_cdr
	movl	%ebx, %edi
	movq	%rbp, %rsi
	movq	%rax, %rdx
	movq	%r14, %rcx
	callq	_apply
	jmp	LBB0_5
LBB0_4:                                 ## %return_as_is
	movl	%ebp, %eax
	movq	%r12, %rdx
LBB0_5:                                 ## %return_as_is
	popq	%rbx
	popq	%r12
	popq	%r14
	popq	%r15
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_apply                  ## -- Begin function apply
	.p2align	4, 0x90
_apply:                                 ## @apply
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %rbp, -16
	movq	%rdx, %r14
	movq	%rsi, %rbx
	movl	%edi, %ebp
	callq	_get_type
	movl	%eax, %edi
	callq	l_is_native_function
	testb	$1, %al
	je	LBB1_2
## %bb.1:                               ## %apply_native
	movl	%ebp, %edi
	movq	%rbx, %rsi
	callq	_get_value_ptr
	movq	%r14, %rdi
	callq	*%rax
	jmp	LBB1_3
LBB1_2:                                 ## %apply_closure
	movq	_TAG_NIL@GOTPCREL(%rip), %rax
	movl	(%rax), %edi
	xorl	%esi, %esi
	callq	_create_value
LBB1_3:                                 ## %apply_closure
	popq	%rbx
	popq	%r14
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function is_symbol
l_is_symbol:                            ## @is_symbol
	.cfi_startproc
## %bb.0:
	movq	_TAG_SYMBOL@GOTPCREL(%rip), %rax
	cmpl	(%rax), %edi
	sete	%al
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function is_list
l_is_list:                              ## @is_list
	.cfi_startproc
## %bb.0:
	movq	_TAG_LIST@GOTPCREL(%rip), %rax
	cmpl	(%rax), %edi
	sete	%al
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function is_native_function
l_is_native_function:                   ## @is_native_function
	.cfi_startproc
## %bb.0:
	movq	_TAG_FUNCTION@GOTPCREL(%rip), %rax
	cmpl	(%rax), %edi
	sete	%al
	retq
	.cfi_endproc
                                        ## -- End function

.subsections_via_symbols
