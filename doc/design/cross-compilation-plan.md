# Cross-Compilation Plan

## Overview

The Vibe kernel compiler currently targets only `arm64-apple-darwin`. This document outlines the changes needed to support cross-compilation to other architectures (e.g., x86_64, Linux) using only the self-hosted Vibe kernel compiler — no bootstrap regression required.

## Current State

### Hardcoded Target Triple

`kernel/codegen.vibe` contains hardcoded constants for the target:

- `.str.target_triple_value` = `"arm64-apple-darwin\0"`
- `.str.data_layout_value` = `"e-m:o-i64:64-i128:128-n32:64-S128\0"`
- `.str.target_triple` = `"target triple = \"arm64-apple-darwin\"\n\n\0"` (for text IR output)

`codegen_init` unconditionally sets these on the LLVM module and writes them to the text IR buffer.

`codegen_emit_object_file` calls `llvm_get_default_target_triple()` and falls back to the hardcoded value, but by that point the LLVM module already has the hardcoded triple set.

### AArch64-Only Target Initialization

`kernel/dsl.vibe` declares and calls only AArch64 initialization functions:

- `LLVMInitializeAArch64TargetInfo`
- `LLVMInitializeAArch64Target`
- `LLVMInitializeAArch64TargetMC`
- `LLVMInitializeAArch64AsmPrinter`
- `LLVMInitializeAArch64AsmParser`

If the detected triple is not ARM64, `llvm_initialize_native_target` silently skips initialization and no target backend is available.

### Build System

`CMakeLists.txt` links architecture-specific LLVM libraries based on the detected target triple. Only AArch64 or X86 libraries are linked — not both simultaneously.

## Proposed Changes

### Phase 1: Runtime Target Detection (Native Compilation on Any Arch)

**Goal**: The compiler detects its host architecture at runtime and targets it correctly, eliminating the hardcoded `arm64-apple-darwin`.

#### `kernel/dsl.vibe`

1. Add X86 target initialization declarations:
   - `LLVMInitializeX86TargetInfo`
   - `LLVMInitializeX86Target`
   - `LLVMInitializeX86TargetMC`
   - `LLVMInitializeX86AsmPrinter`
   - `LLVMInitializeX86AsmParser`

2. Extend `llvm_initialize_native_target` with an X86 branch (when `is_arm64_target` returns 0, check for X86 and initialize those components).

#### `kernel/codegen.vibe`

1. Replace hardcoded `.str.target_triple_value` usage in `codegen_init` with a call to `LLVMGetDefaultTargetTriple()`.

2. For the data layout, use `LLVMCreateTargetDataLayout` from the target machine rather than a hardcoded string.

3. For text IR output, dynamically format the `target triple = "..."` and `target datalayout = "..."` lines from the runtime-detected values.

#### `bootstrap/codegen.ll` (Sync)

Apply equivalent changes to the bootstrap codegen to maintain behavioral sync per the sync strategy.

#### `CMakeLists.txt`

Link both AArch64 and X86 LLVM libraries unconditionally (or based on a CMake option), so the compiled binary can target either architecture.

### Phase 2: Command-Line Target Override (True Cross-Compilation)

**Goal**: The compiler accepts a `-target <triple>` flag to generate code for a different architecture than the host.

#### `kernel/main.vibe`

1. Add argument parsing for `-target <triple>` (and optionally `-data-layout <layout>`).
2. Pass the target triple through to `codegen_init`.

#### `kernel/codegen.vibe`

1. Modify `codegen_init` to accept an optional target triple parameter.
2. If provided, use it instead of `LLVMGetDefaultTargetTriple()`.
3. Use `LLVMGetTargetFromTriple` and `LLVMCreateTargetDataLayout` to derive the correct data layout from the specified target.

#### `kernel/dsl.vibe`

1. Modify `llvm_initialize_native_target` (or add a new `llvm_initialize_target_for_triple`) to initialize the target backend matching the requested triple, not just the host.
2. Consider initializing all available backends unconditionally — the cost is minimal and simplifies the logic.

### Phase 3: Build System Support

#### `CMakeLists.txt`

1. Add a `CROSS_COMPILE_TARGETS` option listing which target backends to link.
2. Default to "all available" or at least AArch64 + X86.

#### `build.sh`

1. Add optional `--target` flag that propagates to the compiler invocation.

## Key Insight: No Bootstrap Regression Required

All changes are to `.vibe` source files. The existing `vibe_kernel` binary (running on arm64) can compile the updated `.vibe` files that add cross-compilation support. This is a natural demonstration of the self-hosting capability: the compiler extends itself.

The bootstrap `.ll` files should be kept in sync per the sync strategy, but they are not required for this work.

## Dependencies

- LLVM must be built with (or have available) the target backends for all desired architectures. Homebrew LLVM on macOS typically includes both AArch64 and X86.
- The `types.ll` shared type definitions are architecture-neutral (pointer sizes are `i64` on both arm64 and x86_64), so no changes needed there.

## Future Considerations

- **Linux support**: Beyond the target triple, Linux builds may need different linker flags, library paths, and potentially `libdl` for FFI. These are build system concerns, not compiler concerns.
- **Additional architectures**: RISC-V, WebAssembly, etc. would follow the same pattern — add `LLVMInitialize<Arch>*` declarations and a detection branch.
- **Sysroot / cross-linker**: Generating object files for a foreign target is only half the story. Linking them into an executable requires a cross-linker and target sysroot, which is outside the compiler's scope.
