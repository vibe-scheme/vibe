# Chat 0055: Kernel build concat prefix and Darwin libc FFI

**Date**: 2026-03-25  
**Model**: Cursor agent (Composer 2)  
**Context**: Follow-up to macro work in the self-hosted kernel. Macros are per `vibe_kernel` invocation, so sharing them across `kernel/*.vibe` modules required either driver changes, `include`, or build-time source concatenation. The project chose CMake-driven concatenation, then centralized Darwin libc FFI.

## Session overview

### 1. Build-time kernel source concatenation

- Added [`scripts/concat_vibe.sh`](../../scripts/concat_vibe.sh): concatenates inputs in order, creates the output directory with `mkdir -p`.
- Updated [`CMakeLists.txt`](../../CMakeLists.txt): each kernel object is built from a generated `build/kernel_concat/<module>.vibe` assembled from:
  1. [`kernel/types.vibe`](../../kernel/types.vibe) — shared `llvm:define-type` structs (`Token`, `Lexer`, `ASTNode`, `Parser`, `NormalizeResult`, `CodeGen`).
  2. [`kernel/macros.vibe`](../../kernel/macros.vibe) — shared `define-syntax` (initially `vibe:ast-null?`, migrated from [`kernel/expander.vibe`](../../kernel/expander.vibe)).
  3. Third prefix slot (see below).
  4. `kernel/<module>.vibe`.

- **Canonical `CodeGen`**: [`kernel/main.vibe`](../../kernel/main.vibe) previously used a different struct layout than [`kernel/codegen.vibe`](../../kernel/codegen.vibe); `types.vibe` uses the codegen layout (main only passes opaque `|%CodeGen*|`).

- **Link / symbol lesson**: Duplicating `llvm:declare-function` for the same name in the prefix and again in the module body caused the compiler to emit suffixed LLVM symbols (e.g. `check_primitive.2`, `lex_next.1`) and **undefined symbols** at link time. A short-lived `forward_defs.vibe` was reduced to comments, then removed in favor of keeping each binding in exactly one place per compile unit.

### 2. `forward_defs.vibe` removed; `ffi_libc_darwin.vibe` added

- Deleted `kernel/forward_defs.vibe` (no longer part of the pipeline).
- Added [`kernel/ffi_libc_darwin.vibe`](../../kernel/ffi_libc_darwin.vibe): all `llvm:define-ffi-function` entries targeting `"/usr/lib/libSystem.B.dylib"` — `malloc`, `free`, `memcpy`, `realloc`, `strncmp` (third parameter `|i32|` to match call sites), `dlopen`, `dlsym`.
- Removed duplicate FFI blocks from [`kernel/lexer.vibe`](../../kernel/lexer.vibe), [`kernel/parser.vibe`](../../kernel/parser.vibe), [`kernel/dsl.vibe`](../../kernel/dsl.vibe), and `dlopen`/`dlsym` from [`kernel/ffi.vibe`](../../kernel/ffi.vibe) (wrappers `ffi_load_library` / `ffi_get_symbol` remain).
- Removed matching `llvm:declare-function` lines for those symbols from [`kernel/main.vibe`](../../kernel/main.vibe), [`kernel/codegen.vibe`](../../kernel/codegen.vibe), [`kernel/util.vibe`](../../kernel/util.vibe), [`kernel/expander.vibe`](../../kernel/expander.vibe) where they would duplicate the prefix. **Codegen** still declares `strlen` only (link-time libc).
- [`kernel/dsl.vibe`](../../kernel/dsl.vibe): `is_arm64_target` `strncmp` length arguments changed from `|i64|` to `|i32|` to match the unified FFI signature.

### 3. Mechanical deduplication

- Stripped redundant `llvm:define-type` blocks from lexer, parser, main, codegen, util, expander (superseded by `types.vibe`).
- Parser retains `lex_next` `llvm:declare-function` (calls lexer); lexer retains its own forward declare before `lex_peek` (single declare per lexer compile unit).

### 4. Documentation

- Updated [`AGENTS.md`](../../AGENTS.md): directory structure, build pipeline (concat order), hand-compile note, duplicate binding warning (declare + FFI + prefix), forward-decl guidance without `forward_defs`.
- Updated order comment in [`kernel/types.vibe`](../../kernel/types.vibe).

## Files touched (summary)

| Area | Files |
|------|--------|
| Build | `CMakeLists.txt`, `scripts/concat_vibe.sh` |
| New kernel prefix | `kernel/types.vibe`, `kernel/macros.vibe`, `kernel/ffi_libc_darwin.vibe` |
| Removed | `kernel/forward_defs.vibe` |
| Kernel modules | `lexer.vibe`, `parser.vibe`, `main.vibe`, `codegen.vibe`, `util.vibe`, `expander.vibe`, `dsl.vibe`, `ffi.vibe` |
| Docs | `AGENTS.md`, `docs/chats/0055-kernel-concat-prefix-and-darwin-ffi.md` |

## Verification

- `./build.sh build` and `./build.sh test` pass after the changes.
- Second self-host `./build.sh build` succeeds (incremental).

## Notes for follow-up

- Shared macros in `macros.vibe` can be extended; next session may apply them across more of the kernel.
- Non-Darwin builds will need a sibling FFI prefix (e.g. `ffi_libc_linux.vibe`) and CMake OS selection; `ffi_libc_darwin.vibe` is explicitly Darwin-only.

## Related docs

- [`AGENTS.md`](../../AGENTS.md) — build pipeline and duplicate-binding warning  
- [`docs/design/macro-system.md`](../design/macro-system.md) — macro architecture  
