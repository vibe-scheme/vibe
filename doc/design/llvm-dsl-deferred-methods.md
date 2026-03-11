# LLVM DSL Deferred Methods

This document records LLVM instructions that could be exposed as DSL primitives in the Vibe kernel but are not currently implemented. It explains why each was omitted and when it might be useful in the future.

## Purpose

- **Reference**: When extending the DSL, check this document to see if a method was intentionally deferred and why
- **Future work**: Prioritize implementation when a use case arises
- **Workaround documentation**: Document how to achieve the same effect with existing primitives

## Deferred Methods

| Method | LLVM API | Why Not Implemented | Future Use Case |
|--------|----------|---------------------|-----------------|
| `llvm:xor` | LLVMBuildXor | Boolean negation achievable via `(llvm:icmp 'ne x (llvm:const-int \|i1\| 0))` | Cleaner boolean flip; bootstrap uses `xor i1` in codegen_define_string_constant_only |
| `llvm:inttoptr` | LLVMBuildIntToPtr | Not used in codebase | Integer-to-pointer casts (reverse of ptrtoint) |
| `llvm:sext` | LLVMBuildSExt | zext suffices for current code | Sign-extending narrow integers |
| `llvm:sdiv` | LLVMBuildSDiv | udiv/urem cover current needs | Signed division |
| `llvm:srem` | LLVMBuildSRem | udiv/urem cover current needs | Signed remainder |
| `llvm:shl` | LLVMBuildShl | Not used | Shift left |
| `llvm:ashr` | LLVMBuildAShr | Not used | Arithmetic shift right |
| `llvm:lshr` | LLVMBuildLShr | Not used | Logical shift right |

## Implementation Pattern

When adding a deferred method, follow the Batch 1 pattern documented in `doc/chats/0027-codegen-migration-batch-1.md`:

1. **bootstrap/dsl.ll**: Add LLVM C API declaration (e.g., `declare %LLVMValueRef @LLVMBuildXor(...)`) and wrapper function (e.g., `llvm_build_xor`)
2. **kernel/dsl.vibe**: Add `llvm:declare-function` and `llvm:define-function` wrapper
3. **bootstrap/codegen.ll**: Add string constant for primitive name, dispatch check in `codegen_eval_dsl_expr`, and handler function (e.g., `codegen_dsl_xor`)

## Related

- `doc/chats/0027-codegen-migration-batch-1.md` — Batch 1 migration, added urem/udiv/ptrtoint
- `AGENTS.md` — Bootstrap/Kernel sync strategy
