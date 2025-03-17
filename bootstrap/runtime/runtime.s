	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 15
	.globl	_create_value           ## -- Begin function create_value
	.p2align	4, 0x90
_create_value:                          ## @create_value
	.cfi_startproc
## %bb.0:
	movl	%edi, %eax
	movq	%rsi, %rdx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_get_type               ## -- Begin function get_type
	.p2align	4, 0x90
_get_type:                              ## @get_type
	.cfi_startproc
## %bb.0:
	movl	%edi, %eax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_get_value_ptr          ## -- Begin function get_value_ptr
	.p2align	4, 0x90
_get_value_ptr:                         ## @get_value_ptr
	.cfi_startproc
## %bb.0:
	movq	%rsi, %rax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_create_list_node       ## -- Begin function create_list_node
	.p2align	4, 0x90
_create_list_node:                      ## @create_list_node
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
	movl	$24, %edi
	callq	_GC_malloc
	movq	%rbx, 8(%rax)
	movl	%ebp, (%rax)
	movq	%r14, 16(%rax)
	popq	%rbx
	popq	%r14
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_car                    ## -- Begin function car
	.p2align	4, 0x90
_car:                                   ## @car
	.cfi_startproc
## %bb.0:
	movl	(%rdi), %eax
	movq	8(%rdi), %rdx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_cdr                    ## -- Begin function cdr
	.p2align	4, 0x90
_cdr:                                   ## @cdr
	.cfi_startproc
## %bb.0:
	movq	16(%rdi), %rax
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function string_copy
l_string_copy:                          ## @string_copy
	.cfi_startproc
## %bb.0:
	movq	$0, -8(%rsp)
	jmp	LBB6_1
	.p2align	4, 0x90
LBB6_2:                                 ## %copy_char
                                        ##   in Loop: Header=BB6_1 Depth=1
	movzbl	(%rsi,%rax), %ecx
	movb	%cl, (%rdi,%rax)
	incq	%rax
	movq	%rax, -8(%rsp)
LBB6_1:                                 ## %loop
                                        ## =>This Inner Loop Header: Depth=1
	movq	-8(%rsp), %rax
	cmpq	%rdx, %rax
	jb	LBB6_2
## %bb.3:                               ## %done
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function hash_symbol
l_hash_symbol:                          ## @hash_symbol
	.cfi_startproc
## %bb.0:
	movq	$5381, -16(%rsp)        ## imm = 0x1505
	movq	$0, -8(%rsp)
	jmp	LBB7_1
	.p2align	4, 0x90
LBB7_2:                                 ## %hash_char
                                        ##   in Loop: Header=BB7_1 Depth=1
	movq	-16(%rsp), %rcx
	movq	%rcx, %rdx
	shlq	$5, %rdx
	addq	%rcx, %rdx
	movzbl	(%rdi,%rax), %ecx
	addq	%rdx, %rcx
	movq	%rcx, -16(%rsp)
	incq	%rax
	movq	%rax, -8(%rsp)
LBB7_1:                                 ## %loop
                                        ## =>This Inner Loop Header: Depth=1
	movq	-8(%rsp), %rax
	cmpq	%rsi, %rax
	jb	LBB7_2
## %bb.3:                               ## %done
	movzbl	-16(%rsp), %eax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_lookup_symbol          ## -- Begin function lookup_symbol
	.p2align	4, 0x90
_lookup_symbol:                         ## @lookup_symbol
	.cfi_startproc
## %bb.0:
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
	jne	LBB8_2
	jmp	LBB8_7
	.p2align	4, 0x90
LBB8_4:                                 ## %continue
                                        ##   in Loop: Header=BB8_2 Depth=1
	movq	32(%rbx), %rbx
	testq	%rbx, %rbx
	je	LBB8_7
LBB8_2:                                 ## %check_name
                                        ## =>This Inner Loop Header: Depth=1
	cmpq	%r15, 8(%rbx)
	jne	LBB8_4
## %bb.3:                               ## %compare_names
                                        ##   in Loop: Header=BB8_2 Depth=1
	movq	(%rbx), %rdi
	movq	%r14, %rsi
	movq	%r15, %rdx
	callq	l_string_equal
	testb	$1, %al
	je	LBB8_4
## %bb.5:                               ## %found
	movl	16(%rbx), %eax
	movq	24(%rbx), %rdx
	jmp	LBB8_6
LBB8_7:                                 ## %not_found
	xorl	%edi, %edi
	xorl	%esi, %esi
	callq	_create_value
LBB8_6:                                 ## %found
	popq	%rbx
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_define_symbol          ## -- Begin function define_symbol
	.p2align	4, 0x90
_define_symbol:                         ## @define_symbol
	.cfi_startproc
## %bb.0:
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
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movq	%rcx, %r14
	movl	%edx, %r13d
	movq	%rsi, %rbx
	movq	%rdi, %r12
	callq	l_hash_symbol
	leaq	_symbol_table(%rip), %rcx
	movq	%rax, 16(%rsp)          ## 8-byte Spill
	movq	(%rcx,%rax,8), %r15
	movq	%r15, %rbp
	testq	%rbp, %rbp
	jne	LBB9_2
	jmp	LBB9_7
	.p2align	4, 0x90
LBB9_4:                                 ## %continue
                                        ##   in Loop: Header=BB9_2 Depth=1
	movq	32(%rbp), %rbp
	testq	%rbp, %rbp
	je	LBB9_7
LBB9_2:                                 ## %check_name
                                        ## =>This Inner Loop Header: Depth=1
	cmpq	%rbx, 8(%rbp)
	jne	LBB9_4
## %bb.3:                               ## %compare_names
                                        ##   in Loop: Header=BB9_2 Depth=1
	movq	(%rbp), %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	l_string_equal
	testb	$1, %al
	je	LBB9_4
## %bb.5:                               ## %update
	movl	%r13d, 16(%rbp)
	movq	%r14, 24(%rbp)
	jmp	LBB9_6
LBB9_7:                                 ## %create_new
	movl	$32, %edi
	callq	_GC_malloc
	movl	%r13d, 12(%rsp)         ## 4-byte Spill
	movq	%rax, %r13
	movq	%rbx, %rdi
	callq	_GC_malloc
	movq	%r14, %rbp
	movq	%rax, %r14
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rbx, %rdx
	callq	l_string_copy
	movq	%r14, (%r13)
	movq	%rbx, 8(%r13)
	movq	%rbp, 24(%r13)
	movl	12(%rsp), %eax          ## 4-byte Reload
	movl	%eax, 16(%r13)
	movq	%r15, 32(%r13)
	movq	16(%rsp), %rax          ## 8-byte Reload
	leaq	_symbol_table(%rip), %rcx
	movq	%r13, (%rcx,%rax,8)
LBB9_6:                                 ## %update
	addq	$24, %rsp
	popq	%rbx
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.p2align	4, 0x90         ## -- Begin function string_equal
l_string_equal:                         ## @string_equal
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_memcmp
	testl	%eax, %eax
	sete	%al
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_init_runtime           ## -- Begin function init_runtime
	.p2align	4, 0x90
_init_runtime:                          ## @init_runtime
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_GC_init
	popq	%rax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_print_string           ## -- Begin function print_string
	.p2align	4, 0x90
_print_string:                          ## @print_string
	.cfi_startproc
## %bb.0:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	movq	%rdi, %rbx
	callq	_strlen
	movl	$1, %edi
	movq	%rbx, %rsi
	movq	%rax, %rdx
	callq	_write
	popq	%rbx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_eval_string            ## -- Begin function eval_string
	.p2align	4, 0x90
_eval_string:                           ## @eval_string
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
	cmpl	$2, %eax
	jne	LBB13_2
## %bb.1:                               ## %eval_str
	movl	%ebp, %edi
	movq	%rbx, %rsi
	callq	_get_value_ptr
	movq	%rax, %rdi
	callq	_create_lexer
	movq	%rax, %rdi
	callq	_create_parser
	movq	%rax, %rdi
	callq	_parse
	movl	%eax, %edi
	movq	%rdx, %rsi
	movq	%r14, %rdx
	callq	_eval
	jmp	LBB13_3
LBB13_2:                                ## %error
	xorl	%edi, %edi
	xorl	%esi, %esi
	callq	_create_value
LBB13_3:                                ## %error
	popq	%rbx
	popq	%r14
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__const
	.globl	_TAG_NIL                ## @TAG_NIL
	.p2align	2
_TAG_NIL:
	.long	0                       ## 0x0

	.globl	_TAG_NUMBER             ## @TAG_NUMBER
	.p2align	2
_TAG_NUMBER:
	.long	1                       ## 0x1

	.globl	_TAG_SYMBOL             ## @TAG_SYMBOL
	.p2align	2
_TAG_SYMBOL:
	.long	2                       ## 0x2

	.globl	_TAG_FUNCTION           ## @TAG_FUNCTION
	.p2align	2
_TAG_FUNCTION:
	.long	3                       ## 0x3

	.globl	_TAG_LIST               ## @TAG_LIST
	.p2align	2
_TAG_LIST:
	.long	4                       ## 0x4

	.globl	_symbol_table           ## @symbol_table
.zerofill __DATA,__common,_symbol_table,2048,4

.subsections_via_symbols
