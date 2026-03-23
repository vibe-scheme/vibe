# Codegen Migration and Self-Host Terminator Bug

**Date**: 2025-03-12
**Model**: Cursor Composer
**Context**: Codegen migration (Phase 1, Tier A, helpers), ICmp predicate fix, balanced parens fix. Self-host build fails with "Basic Block does not have terminator"; investigated differences between `codegen.ll` and `codegen_no_vibe.ll` + `codegen.vibe`.

## Session Overview

This session covered codegen migration work and the self-host terminator bug investigation.

**Build status**: Kernel build (`./build.sh build_kernel`) succeeds. Self-host build (`./build.sh build`) fails with "Basic Block in function 'X' does not have terminator! label %entry" for many functions.

## Codegen Migration

Migrated functions from `codegen_no_vibe.ll` to `kernel/codegen.vibe`:

**Phase 1 (4)**: `codegen_dsl_alloca`, `codegen_dsl_br`, `codegen_dsl_label`, `codegen_dsl_phi`

**Tier A (18)**: `codegen_dsl_add`, `codegen_dsl_or`, `codegen_dsl_sub`, `codegen_dsl_and`, `codegen_dsl_mul`, `codegen_dsl_urem`, `codegen_dsl_udiv`, `codegen_dsl_const_int`, `codegen_dsl_bitcast`, `codegen_dsl_store`, `codegen_dsl_load`, `codegen_dsl_trunc`, `codegen_dsl_select`, `codegen_dsl_zext`, `codegen_dsl_icmp`, `codegen_dsl_insertvalue`, `codegen_dsl_extractvalue`, `codegen_dsl_ptrtoint`

**Helpers**: `codegen_store_function_type`, `codegen_get_function_type`, `codegen_map_predicate_string`, `codegen_append_escaped_string`, `codegen_append_bytevector`, `codegen_get_constant`, `codegen_write_bytevector_to_buffer`, `codegen_extract_function_name`

For each, `codegen_no_vibe.ll` was updated to replace `define` with `declare`. 62 functions migrated total; ~37 remain.

**Other fixes**: ICmp predicate validation extended to reject values outside 32–41. Balanced parens handling fixed (unclosed/extra parens now reported).

## Self-Host Terminator Bug

**Symptom**: Self-host fails; kernel succeeds. Many functions in compiled `codegen.vibe` have entry blocks without terminators.

**Finding**: `codegen_dsl_check_primitive` is fully defined in `codegen.ll` but only declared in `codegen_no_vibe.ll`; self-host uses the `.vibe` implementation (select+ret). Tried moving the implementation to `.ll`; self-host still failed on other handlers. Conclusion: main issue is missing terminators across many `.vibe` handlers, not just `codegen_dsl_check_primitive`.

**Suspected cause**: Chat 0036 documents the store+br workaround—when a block has store then conditional br, the br can be dropped. Workaround: split into two blocks. Similar patterns may affect select+ret and other sequences.

**Next steps**: Apply store+br workaround systematically to affected handlers; ensure every block has a terminator. If needed, keep `codegen_dsl_check_primitive` in `.ll` as a fallback.

## Files Modified

- `kernel/codegen.vibe` – migrated functions
- `bootstrap/codegen_no_vibe.ll` – declare for migrated functions
- `bootstrap/codegen.ll` – ICmp predicate fix (when applicable)

## References

- Chat 0034: SSA cross-block resolution
- Chat 0036: Store+br workaround, phi migration
- AGENTS.md: Bootstrap/Kernel sync, cross-block variable usage
