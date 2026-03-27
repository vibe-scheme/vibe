# Session: Kernel pointer and AST shape macros

**Date**: 2026-03-27  
**Model**: Cursor agent (Composer 2)  
**Context**: Implement the planned macro-ization of repeated LLVM patterns in the self-hosted kernel: rename opaque-pointer helpers, add length/empty-span and AST-discriminant macros, migrate call sites, and update design docs.

## Overview

Extended **`kernel/macros.vibe`** with **`vibe:ptr-null?`**, **`vibe:ptr-some?`** (renamed from **`vibe:void-ptr-*`**), **`vibe:len-zero?`**, **`vibe:ptr-empty?`**, **`vibe:node-kind?`** (literals **`atom`** / **`list`** on **`ASTNode.type`**), and **`vibe:atom-type?`** (literals **`number`**, **`string`**, **`bytevector`**, **`pointer`** on **`ASTNode.atom_type`**). Documented field tag meanings beside **`ASTNode`** in **`kernel/types.vibe`**.

Updated **`docs/design/macro-system.md`** and **`docs/design/primitive-forms.md`** macro tables; did not edit committed older chat files.

Replaced manual **`llvm:icmp`** + **`gep`/`load`** sequences across **`kernel/codegen.vibe`**, **`kernel/expander.vibe`**, **`kernel/util.vibe`**, **`kernel/parser.vibe`**, and **`kernel/main.vibe`**, folding single-use **`let*`** bindings into macro calls where safe. Left **`AST_QUOTE`** checks (**`type == 2`**) as explicit **`icmp`** — distinct from list/atom node kind.

## Verification

- **`./build.sh build`**: success (self-hosted **`vibe_kernel`**).
- **`./build.sh test`**: all four tests passed.

## Files touched

| File | Changes |
|------|---------|
| **`kernel/macros.vibe`** | New/renamed macros; **`define-vibe-syntax`** + doc strings |
| **`kernel/types.vibe`** | Comments for **`type`** / **`atom_type`** numeric tags |
| **`kernel/codegen.vibe`** | Wide migration to new macros |
| **`kernel/expander.vibe`** | **`node-kind?`** on **`form`**, **`car_val`**, **`node`** |
| **`kernel/util.vibe`** | **`parse_int_from_ast`** uses **`node-kind?`** / **`atom-type?`**; **`ptr-*`** rename |
| **`kernel/parser.vibe`** | **`ptr-empty?`** for normalize; **`ptr-null?`** rename |
| **`kernel/main.vibe`** | **`len-zero?`** for path helpers |
| **`kernel/dsl.vibe`** | **`ptr-null?`** rename |
| **`docs/design/macro-system.md`** | Table + wording |
| **`docs/design/primitive-forms.md`** | Registry table |

## Follow-up: `vibe:node-empty?`

Added **`vibe:node-empty?`** — expands to **`ptr-empty?`** on **`load`** of **`ASTNode`** fields **`value`** (2) and **`value_len`** (3). Migrated **`codegen.vibe`** sites that loaded those only for an empty-span test (**`get_stored_name_common`**, **`get_type_string`**, **`check_name_node`**, **`process_binding`**). Left **`ptr-empty?`** where the pointer/length are not both from one node (e.g. **`codegen_resolve_type_string`** parameters, IR text buffers, **`parse_normalize_type_atom`** token **`value`**/**`len`**).

## Notes

- **`vibe:ptr-empty?`** expands to **`(llvm:or (vibe:ptr-null? ptr) (vibe:len-zero? len))`**; **`ptr`** must be the opaque **`i8*`** pattern used today.
- **`vibe:node-kind?`** / **`vibe:atom-type?`** embed **`gep` + `load`** so call sites pass an **`|%ASTNode*|`**, not a pre-loaded **`i32`**.
