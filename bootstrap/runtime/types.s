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
	.globl	_create_symbol          ## -- Begin function create_symbol
	.p2align	4, 0x90
_create_symbol:                         ## @create_symbol
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
	movq	%rsi, %rbx
	movq	%rdi, %r14
	movq	%rbx, %rdi
	callq	_GC_malloc
	movq	%rax, %r15
	movq	%r15, %rdi
	movq	%r14, %rsi
	movq	%rbx, %rdx
	callq	_memcpy
	movl	$1, %edi
	movq	%r15, %rsi
	callq	_create_value
	popq	%rbx
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_create_string          ## -- Begin function create_string
	.p2align	4, 0x90
_create_string:                         ## @create_string
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
	movq	%rsi, %rbx
	movq	%rdi, %r14
	movq	%rbx, %rdi
	callq	_GC_malloc
	movq	%rax, %r15
	movq	%r15, %rdi
	movq	%r14, %rsi
	movq	%rbx, %rdx
	callq	_memcpy
	movl	$2, %edi
	movq	%r15, %rsi
	callq	_create_value
	popq	%rbx
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_create_function        ## -- Begin function create_function
	.p2align	4, 0x90
_create_function:                       ## @create_function
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	movq	%rdi, %rax
	movl	$4, %edi
	movq	%rax, %rsi
	callq	_create_value
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_create_function_with_args ## -- Begin function create_function_with_args
	.p2align	4, 0x90
_create_function_with_args:             ## @create_function_with_args
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
	movq	%rdx, %r14
	movq	%rsi, %r15
	movq	%rdi, %rbx
	movl	$24, %edi
	callq	_GC_malloc
	movq	%rbx, (%rax)
	movq	%r15, 8(%rax)
	movq	%r14, 16(%rax)
	movl	$4, %edi
	movq	%rax, %rsi
	callq	_create_value
	popq	%rbx
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_get_function_info      ## -- Begin function get_function_info
	.p2align	4, 0x90
_get_function_info:                     ## @get_function_info
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_get_value_ptr
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_get_function_ptr       ## -- Begin function get_function_ptr
	.p2align	4, 0x90
_get_function_ptr:                      ## @get_function_ptr
	.cfi_startproc
## %bb.0:
	movq	(%rdi), %rax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_get_function_args      ## -- Begin function get_function_args
	.p2align	4, 0x90
_get_function_args:                     ## @get_function_args
	.cfi_startproc
## %bb.0:
	movq	8(%rdi), %rax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_get_function_arg_count ## -- Begin function get_function_arg_count
	.p2align	4, 0x90
_get_function_arg_count:                ## @get_function_arg_count
	.cfi_startproc
## %bb.0:
	movq	16(%rdi), %rax
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_is_nil                 ## -- Begin function is_nil
	.p2align	4, 0x90
_is_nil:                                ## @is_nil
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_get_type
	testl	%eax, %eax
	sete	%al
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_is_symbol              ## -- Begin function is_symbol
	.p2align	4, 0x90
_is_symbol:                             ## @is_symbol
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_get_type
	cmpl	$1, %eax
	sete	%al
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_is_string              ## -- Begin function is_string
	.p2align	4, 0x90
_is_string:                             ## @is_string
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_get_type
	cmpl	$2, %eax
	sete	%al
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_is_list                ## -- Begin function is_list
	.p2align	4, 0x90
_is_list:                               ## @is_list
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_get_type
	cmpl	$3, %eax
	sete	%al
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_is_function            ## -- Begin function is_function
	.p2align	4, 0x90
_is_function:                           ## @is_function
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	callq	_get_type
	cmpl	$4, %eax
	sete	%al
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_string_length          ## -- Begin function string_length
	.p2align	4, 0x90
_string_length:                         ## @string_length
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	pushq	%rax
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -24
	.cfi_offset %rbp, -16
	movq	%rsi, %rbx
	movl	%edi, %ebp
	callq	_is_string
	testb	$1, %al
	je	LBB19_2
## %bb.1:                               ## %get_len
	movl	%ebp, %edi
	movq	%rbx, %rsi
	callq	_get_value_ptr
	movq	%rax, %rdi
	callq	_strlen
	jmp	LBB19_3
LBB19_2:                                ## %error
	leaq	L_.str.not_string(%rip), %rdi
	callq	_error
	xorl	%eax, %eax
LBB19_3:                                ## %error
	addq	$8, %rsp
	popq	%rbx
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_list_length            ## -- Begin function list_length
	.p2align	4, 0x90
_list_length:                           ## @list_length
	.cfi_startproc
## %bb.0:
	pushq	%rax
	.cfi_def_cfa_offset 16
	testq	%rdi, %rdi
	je	LBB20_2
## %bb.1:                               ## %count
	callq	_cdr
	movq	%rax, %rdi
	callq	_list_length
	incq	%rax
	popq	%rcx
	retq
LBB20_2:                                ## %done
	xorl	%eax, %eax
	popq	%rcx
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__const
	.globl	_TAG_NIL                ## @TAG_NIL
	.p2align	2
_TAG_NIL:
	.long	0                       ## 0x0

	.globl	_TAG_SYMBOL             ## @TAG_SYMBOL
	.p2align	2
_TAG_SYMBOL:
	.long	1                       ## 0x1

	.globl	_TAG_STRING             ## @TAG_STRING
	.p2align	2
_TAG_STRING:
	.long	2                       ## 0x2

	.globl	_TAG_LIST               ## @TAG_LIST
	.p2align	2
_TAG_LIST:
	.long	3                       ## 0x3

	.globl	_TAG_FUNCTION           ## @TAG_FUNCTION
	.p2align	2
_TAG_FUNCTION:
	.long	4                       ## 0x4

	.section	__TEXT,__cstring,cstring_literals
	.p2align	4               ## @.str.not_string
L_.str.not_string:
	.asciz	"not a string value"


.subsections_via_symbols
