	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 15
	.globl	_main                   ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%r14
	.cfi_def_cfa_offset 16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	pushq	%rax
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -24
	.cfi_offset %r14, -16
	leaq	L_.str.prompt(%rip), %r14
	leaq	L_.str.newline(%rip), %rbx
	jmp	LBB0_1
	.p2align	4, 0x90
LBB0_2:                                 ## %print_result
                                        ##   in Loop: Header=BB0_1 Depth=1
	movq	%rax, %rdi
	callq	l_print_ast
	xorl	%eax, %eax
	movq	%rbx, %rdi
	callq	_printf
LBB0_1:                                 ## %repl_loop
                                        ## =>This Inner Loop Header: Depth=1
	xorl	%eax, %eax
	movq	%r14, %rdi
	callq	_printf
	callq	_parse_expr
	testq	%rax, %rax
	jne	LBB0_2
## %bb.3:                               ## %exit
	xorl	%eax, %eax
	addq	$8, %rsp
	popq	%rbx
	popq	%r14
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function print_ast
l_print_ast:                            ## @print_ast
	.cfi_startproc
## %bb.0:                               ## %entry
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r12
	.cfi_def_cfa_offset 32
	pushq	%rbx
	.cfi_def_cfa_offset 40
	pushq	%rax
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -40
	.cfi_offset %r12, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %r14
	movl	(%r14), %eax
	cmpq	$7, %rax
	ja	LBB1_18
## %bb.1:                               ## %entry
	leaq	LJTI1_0(%rip), %rcx
	movslq	(%rcx,%rax,4), %rax
	addq	%rcx, %rax
	jmpq	*%rax
LBB1_6:                                 ## %print_number
	movq	8(%r14), %rdi
	jmp	LBB1_3
LBB1_18:                                ## %print_error
	leaq	L_.str.error(%rip), %rdi
	jmp	LBB1_3
LBB1_2:                                 ## %print_nil
	leaq	L_.str.nil(%rip), %rdi
	jmp	LBB1_3
LBB1_7:                                 ## %print_string
	movq	8(%r14), %rbx
	leaq	L_.str.quote_char(%rip), %r14
	xorl	%eax, %eax
	movq	%r14, %rdi
	callq	_printf
	xorl	%eax, %eax
	movq	%rbx, %rdi
	callq	_printf
	xorl	%eax, %eax
	movq	%r14, %rdi
	jmp	LBB1_4
LBB1_8:                                 ## %print_list
	leaq	L_.str.lparen(%rip), %rdi
	xorl	%eax, %eax
	callq	_printf
	movq	24(%r14), %r15
	movq	32(%r14), %r12
	leaq	L_.str.space(%rip), %r14
	xorl	%ebx, %ebx
	cmpq	%rbx, %r12
	jne	LBB1_10
	jmp	LBB1_13
	.p2align	4, 0x90
LBB1_12:                                ## %skip_space
                                        ##   in Loop: Header=BB1_10 Depth=1
	movq	(%r15,%rbx,8), %rdi
	callq	l_print_ast
	incq	%rbx
	cmpq	%rbx, %r12
	je	LBB1_13
LBB1_10:                                ## %print_child
                                        ## =>This Inner Loop Header: Depth=1
	testq	%rbx, %rbx
	je	LBB1_12
## %bb.11:                              ## %print_space
                                        ##   in Loop: Header=BB1_10 Depth=1
	xorl	%eax, %eax
	movq	%r14, %rdi
	callq	_printf
	jmp	LBB1_12
LBB1_14:                                ## %print_quote
	leaq	L_.str.quote_char(%rip), %rdi
	jmp	LBB1_15
LBB1_16:                                ## %print_quasiquote
	leaq	L_.str.backquote(%rip), %rdi
	jmp	LBB1_15
LBB1_17:                                ## %print_unquote
	leaq	L_.str.comma(%rip), %rdi
LBB1_15:                                ## %print_quote
	xorl	%eax, %eax
	callq	_printf
	movq	24(%r14), %rax
	movq	(%rax), %rdi
	callq	l_print_ast
	jmp	LBB1_5
LBB1_13:                                ## %end_list
	leaq	L_.str.rparen(%rip), %rdi
LBB1_3:                                 ## %print_nil
	xorl	%eax, %eax
LBB1_4:                                 ## %print_nil
	callq	_printf
LBB1_5:                                 ## %print_nil
	addq	$8, %rsp
	popq	%rbx
	popq	%r12
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
	.p2align	2, 0x90
	.data_region jt32
L1_0_set_2 = LBB1_2-LJTI1_0
L1_0_set_6 = LBB1_6-LJTI1_0
L1_0_set_7 = LBB1_7-LJTI1_0
L1_0_set_8 = LBB1_8-LJTI1_0
L1_0_set_14 = LBB1_14-LJTI1_0
L1_0_set_16 = LBB1_16-LJTI1_0
L1_0_set_17 = LBB1_17-LJTI1_0
LJTI1_0:
	.long	L1_0_set_2
	.long	L1_0_set_6
	.long	L1_0_set_6
	.long	L1_0_set_7
	.long	L1_0_set_8
	.long	L1_0_set_14
	.long	L1_0_set_16
	.long	L1_0_set_17
	.end_data_region
                                        ## -- End function
	.section	__TEXT,__cstring,cstring_literals
L_.str.prompt:                          ## @.str.prompt
	.asciz	"> "

L_.str.newline:                         ## @.str.newline
	.asciz	"\n"

L_.str.nil:                             ## @.str.nil
	.asciz	"nil"

L_.str.lparen:                          ## @.str.lparen
	.asciz	"("

L_.str.rparen:                          ## @.str.rparen
	.asciz	")"

L_.str.quote_char:                      ## @.str.quote_char
	.asciz	"\""

L_.str.backquote:                       ## @.str.backquote
	.asciz	"`"

L_.str.comma:                           ## @.str.comma
	.asciz	","

L_.str.space:                           ## @.str.space
	.asciz	" "

L_.str.error:                           ## @.str.error
	.asciz	"<invalid-node>"


.subsections_via_symbols
