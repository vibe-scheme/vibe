# Chat 0046: Main.ll Helper Functions Migration

**Date**: 2025-03-17
**Model**: Cursor Composer 1.5

## Overview

Migrated 8 helper functions from `bootstrap/main.ll` to `kernel/main.vibe` using the established codegen pattern. Bootstrap continues to use unchanged `main.ll`; KERNEL/SELF_HOST use `main.vibe` + `main_no_vibe.ll` linked together. The `main` function remains in `main_no_vibe.ll`.

## Setup (One-Time)

1. **Copied** `bootstrap/main.ll` to `bootstrap/main_no_vibe.ll`
2. **Modified CMakeLists.txt** so that:
   - BOOTSTRAP mode: continues using `main.ll` (no changes)
   - KERNEL/SELF_HOST mode: compiles `main.vibe` to IR, assembles `main_no_vibe.ll`, links both with types
3. **Created** `kernel/main.vibe` with C library declarations

## Functions Migrated (in order)

| # | Function | Complexity | Notes |
|---|----------|------------|-------|
| 1 | `print_usage` | Low | Moved `.str.usage` constant to main.vibe |
| 2 | `print_error` | Low | Pass-through to print_string |
| 3 | `print_string` | Low | strlen + write(1, str, len) |
| 4 | `check_identifier` | Low | Length check + strncmp |
| 5 | `check_extension` | Low | strlen x2, suffix comparison; fixed paren balance |
| 6 | `read_file` | Medium | open/malloc/read/close; alloca/store/load for fd, buffer, bytes_read across blocks |
| 7 | `write_file` | Medium | open/write/close; alloca for fd across blocks |
| 8 | `extract_module_name` | High | 3 loops (slash, dot, copy); all allocas in outer let*; phi replaced with store in use_dot_length/use_full_length |

## Key Migration Patterns

- **Cross-block values**: Used alloca/store/load for values flowing across blocks (e.g., fd, buffer, bytes_read in read_file)
- **Loops**: Allocas for loop state (i_ptr, j_ptr, i_copy_ptr) in outer let*; labels load/store for iteration
- **Phi replacement**: final_len in extract_module_name used store in use_dot_length and use_full_length, load in allocate_name
- **Constants before functions**: `.str.usage` defined before print_usage (forward-reference fix)

## C Library Declarations Added

```vibe
(llvm:declare-function (malloc (size |i64|)) |i8*|)
(llvm:declare-function (free (ptr |i8*|)) |void|)
(llvm:declare-function (strlen (s |i8*|)) |i64|)
(llvm:declare-function (write (fd |i32|) (buf |i8*|) (count |i32|)) |i64|)
(llvm:declare-function (open (path |i8*|) (flags |i32|) (mode |i32|)) |i32|)
(llvm:declare-function (read (fd |i32|) (buf |i8*|) (count |i64|)) |i64|)
(llvm:declare-function (close (fd |i32|)) |i32|)
(llvm:declare-function (strncmp (s1 |i8*|) (s2 |i8*|) (n |i32|)) |i32|)
```

Note: `open` uses 3 fixed args (path, flags, mode). For read_file we pass (filename, 0, 0) for O_RDONLY.

## Build Validation

Full build flow passes:
```
./build.sh clean && ./build.sh bootstrap && ./build.sh build_kernel && ./build.sh build
```

## Files Changed

| File | Change |
|------|--------|
| `bootstrap/main_no_vibe.ll` | New file (copy of main.ll); 8 functions replaced with declares |
| `kernel/main.vibe` | New file; 8 migrated functions + C declarations + .str.usage |
| `CMakeLists.txt` | Conditional main module: main.ll for BOOTSTRAP, main_no_vibe.ll + main.vibe for KERNEL/SELF_HOST |
| `AGENTS.md` | Updated migration status, directory structure |

## Migration Statistics

- **Functions migrated**: 8
- **main()**: Remains in main_no_vibe.ll (not migrated per plan)
- **main.ll**: Unchanged, BOOTSTRAP mode only
