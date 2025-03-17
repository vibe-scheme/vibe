	.section	__TEXT,__text,regular,pure_instructions
	.macosx_version_min 10, 15
	.globl	_main                   ## -- Begin function main
	.p2align	4, 0x90
_main:                                  ## @main
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
	movq	%rsi, %rbx
	movl	%edi, %ebp
	callq	_init_runtime
	callq	_register_special_forms
	movq	_TAG_NIL@GOTPCREL(%rip), %rax
	movl	(%rax), %edi
	xorl	%esi, %esi
	callq	_create_value
	movq	%rdx, %rcx
	xorl	%edx, %edx
	movl	%eax, %edi
	movq	%rcx, %rsi
	callq	_create_list_node
	movq	%rax, %r14
	cmpl	$2, %ebp
	jl	LBB0_5
## %bb.1:                               ## %read_file
	movq	8(%rbx), %rbx
	movq	%rbx, %rdi
	callq	_read_file
	testq	%rax, %rax
	je	LBB0_4
## %bb.2:                               ## %eval_file
	movq	_TAG_STRING@GOTPCREL(%rip), %rcx
	movl	(%rcx), %edi
	movq	%rax, %rsi
	callq	_create_value
	movl	%eax, %edi
	movq	%rdx, %rsi
	movq	%r14, %rdx
	callq	_eval_string
	xorl	%eax, %eax
	jmp	LBB0_3
LBB0_5:                                 ## %no_args
	movl	$41, %edi
	callq	_GC_malloc
	movabsq	$7308332182666289253, %rcx ## imm = 0x656C696620612065
	movq	%rcx, 32(%rax)
	movabsq	$8386113089492632864, %rcx ## imm = 0x7461756C61764520
	movq	%rcx, 24(%rax)
	movabsq	$3251667536309218917, %rcx ## imm = 0x2D203E656D616E65
	movq	%rcx, 16(%rax)
	movabsq	$7811887437078422121, %rcx ## imm = 0x6C69663C20656269
	movq	%rcx, 8(%rax)
	movabsq	$8511867502930785109, %rcx ## imm = 0x76203A6567617355
	movq	%rcx, (%rax)
	movb	$0, 40(%rax)
	movq	%rax, %rdi
	jmp	LBB0_6
LBB0_4:                                 ## %file_error
	movl	$21, %edi
	callq	_GC_malloc
	movabsq	$9071406539695648, %rcx ## imm = 0x203A656C696620
	movq	%rcx, 13(%rax)
	movabsq	$7594793450213041249, %rcx ## imm = 0x696620676E696461
	movq	%rcx, 8(%rax)
	movabsq	$7309940821043868229, %rcx ## imm = 0x657220726F727245
	movq	%rcx, (%rax)
	movq	%rax, %rdi
	callq	_print_string
	movq	%rbx, %rdi
LBB0_6:                                 ## %no_args
	callq	_print_string
	movl	$2, %edi
	callq	_GC_malloc
	movw	$10, (%rax)
	movq	%rax, %rdi
	callq	_print_string
	movl	$1, %eax
LBB0_3:                                 ## %eval_file
	popq	%rbx
	popq	%r14
	popq	%rbp
	retq
	.cfi_endproc
                                        ## -- End function
	.globl	_read_file              ## -- Begin function read_file
	.p2align	4, 0x90
_read_file:                             ## @read_file
	.cfi_startproc
## %bb.0:
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
	movq	%rdi, %rbx
	movl	$2, %edi
	callq	_GC_malloc
	movw	$114, (%rax)
	movq	%rbx, %rdi
	movq	%rax, %rsi
	callq	_fopen
	movq	%rax, %rbx
	testq	%rbx, %rbx
	je	LBB1_4
## %bb.1:                               ## %get_size
	xorl	%esi, %esi
	movl	$2, %edx
	movq	%rbx, %rdi
	callq	_fseek
	movq	%rbx, %rdi
	callq	_ftell
	movq	%rax, %r14
	xorl	%esi, %esi
	xorl	%edx, %edx
	movq	%rbx, %rdi
	callq	_fseek
	movq	%r14, %rdi
	callq	_GC_malloc
	movq	%rax, %r15
	movl	$1, %esi
	movq	%r15, %rdi
	movq	%r14, %rdx
	movq	%rbx, %rcx
	callq	_fread
	movq	%rax, %r12
	movq	%rbx, %rdi
	callq	_fclose
	cmpq	%r14, %r12
	jne	LBB1_4
## %bb.2:                               ## %return_data
	movq	%r15, %rax
	movq	%r14, %rdx
	jmp	LBB1_3
LBB1_4:                                 ## %read_error
	xorl	%eax, %eax
	xorl	%edx, %edx
LBB1_3:                                 ## %return_data
	addq	$8, %rsp
	popq	%rbx
	popq	%r12
	popq	%r14
	popq	%r15
	retq
	.cfi_endproc
                                        ## -- End function
	.section	__TEXT,__cstring,cstring_literals
	.p2align	4               ## @.str.file_error
L_.str.file_error:
	.asciz	"Error reading file: "

	.p2align	4               ## @.str.usage
L_.str.usage:
	.asciz	"Usage: vibe <filename> - Evaluate a file"

L_.str.newline:                         ## @.str.newline
	.asciz	"\n"

L_.str.read_mode:                       ## @.str.read_mode
	.asciz	"r"


.subsections_via_symbols
