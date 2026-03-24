# Chat 0003: Bytevector and Vertical Bar Syntax Implementation

**Date**: 2025-12-05  
**Model**: Cursor Composer 1  
**Context**: Implementing R7RS-compatible bytevector syntax and vertical-bar-delimited symbols for LLVM types

## Overview

This conversation focused on implementing two major syntax improvements to the Vibe bootstrap compiler:

1. **Vertical-bar-delimited symbols** for LLVM types (e.g., `|i32|`, `|i8*|`, `|[13 x i8]|`)
2. **R7RS bytevector syntax** (`#u8(...)`) for constant values

These changes address concerns about polluting the LISP-1 binding space with LLVM type names and provide a more Scheme-compatible way to represent byte data.

## Key Decisions

### Syntax Redesign

The user requested a significant redesign from the initial implementation:

**Before:**
- LLVM types as plain symbols: `i32`, `i8*`
- Constants as C-style strings: `c"Hello, World"`
- Types in binding space: `(define-bitcode-type Point (x i32) (y i32))`

**After:**
- LLVM types as vertical-bar-delimited symbols: `|i32|`, `|i8*|`, `|[13 x i8]|`
- Constants as R7RS bytevectors: `#u8(72 101 108 108 111 44 32 87 111 114 108 100 0)`
- Types isolated from binding space: `(define-bitcode-type Point (x |i32|) (y |i32|))`

### Rationale

1. **Vertical-bar symbols** prevent LLVM type names from polluting the LISP-1 binding space
2. **Special characters** in type names (like `*`, `[`, `]`) can be handled naturally within vertical bars
3. **R7RS bytevectors** align with Scheme standards and provide explicit byte-level control
4. **Future extensibility** - types like `i32**` or `%ASTNode*` can be represented without conflicts

## Implementation Details

### Lexer Changes (`bootstrap/lexer/lexer.ll`)

#### New Token Type
- Added `TOKEN_BYTEVECTOR = 13` to token type enumeration

#### New Helper Functions

1. **`lex_peek_char`**: Peek ahead in the source without advancing position
   - Parameters: lexer pointer, offset
   - Returns: character at offset (or 0 if out of bounds)

2. **`lex_read_vertical_bar_symbol`**: Parse symbols enclosed in `|...|`
   - Handles opening `|`, reads content until closing `|`
   - Returns identifier token with the symbol content (without bars)
   - Error handling for unclosed vertical bars

3. **`lex_read_bytevector`**: Parse R7RS bytevector syntax `#u8(...)`
   - Recognizes `#u8(` pattern
   - Reads space-separated decimal numbers (0-255)
   - Converts numbers to bytes and stores in token value
   - Handles closing `)`
   - Error handling for invalid syntax

#### Modified `lex_next` Function
- Added detection for `|` character (vertical bar)
- Added detection for `#` character (potential bytevector)
- Added state checks: `check_vertical_bar`, `vertical_bar_symbol`, `check_hash`, `check_bytevector`, `check_u8`, `check_u8_lparen`

#### New Error Messages
- `@.str.unclosed_vbar`: "Unclosed vertical bar symbol"
- `@.str.invalid_bytevector`: "Invalid bytevector syntax"

### Parser Changes (`bootstrap/parser/parser.ll`)

**No changes required** - The parser already handles bytevectors correctly as atoms. The `parse_create_atom` function copies the token type to the AST node, so bytevector tokens are automatically handled.

### Codegen Changes (`bootstrap/compiler/codegen.ll`)

#### Modified `codegen_define_bitcode_constant`

Added bytevector detection and formatting:
- Checks if value node is an atom with `TOKEN_BYTEVECTOR` type
- If bytevector: formats as `c"..."` with proper escaping
- If not bytevector: uses existing formatting

#### New Function: `codegen_append_bytevector`

Converts bytevector data to LLVM IR string literal format:
- Iterates through each byte
- Escapes special characters:
  - Null bytes (`\00`) → `\00`
  - Quotes (`"`) → `\"`
  - Backslashes (`\`) → `\\`
- Writes normal bytes directly

#### New String Literals
- `@.str.c_quote_open`: `c"`
- `@.str.backslash_00`: `\00`
- `@.str.backslash_quote`: `\"`
- `@.str.backslash_backslash`: `\\`

### Test File Updates (`test/hello_world.vibe`)

Updated to use new syntax:
```scheme
(define-bitcode-type Point (x |i32|) (y |i32|))
(define-bitcode-constant hello_string |[13 x i8]| #u8(72 101 108 108 111 44 32 87 111 114 108 100 0))
(define-bitcode-function (hello (name |i8*|)) |void| "...")
```

## Technical Challenges

### String Literal Sizing

Multiple iterations were needed to correctly size LLVM IR string literals:
- Initial error: Missing quotes around `target triple` value
- Fixed: Added escaped quotes (`\22`) in string literal
- Challenge: Calculating exact byte counts including escape sequences

### Bytevector Escaping

LLVM IR string literals require escaping of special characters:
- Null bytes must be escaped as `\00` (not `\0`)
- Quotes must be escaped as `\"`
- Backslashes must be escaped as `\\`
- Other bytes can be written directly

### Control Flow Complexity

Adding new token detection in `lex_next` required careful insertion to avoid:
- Duplicate labels
- Broken control flow
- Missing error handling

## Build Errors Fixed

1. **Duplicate labels**: Removed duplicate `string:` and `check_lparen:` labels
2. **Undefined references**: Fixed `br` instructions pointing to non-existent labels
3. **String literal size mismatches**: Corrected array sizes for error message strings
   - `@.str.unclosed_vbar`: `[29 x i8]` (was `[30 x i8]`)
   - `@.str.invalid_bytevector`: `[26 x i8]` (was `[29 x i8]`)

## Results

### Successfully Generated IR

The bytevector constant is now correctly formatted:
```llvm
@hello_string = constant [13 x i8] c"Hello, World\00"
```

This matches the expected LLVM IR format and validates correctly with `llvm-as`.

### Remaining Issues

The function definition (`define-bitcode-function`) still has issues:
- Generated IR shows: `@ = constant void` instead of `define void @hello(...)`
- This is a pre-existing issue unrelated to bytevector support
- Function name extraction appears to be failing

## Files Modified

- `bootstrap/lexer/lexer.ll`: Added vertical bar and bytevector lexing
- `bootstrap/compiler/codegen.ll`: Added bytevector codegen support
- `test/hello_world.vibe`: Updated to use new syntax

## Related Documentation

- R7RS Scheme specification (bytevector syntax)
- LLVM IR specification (string literal format)
- Previous chat: `0002-codegen-compilation-fixes.md`

## Next Steps

1. Fix function definition codegen (separate issue)
2. Add support for more bytevector operations
3. Consider adding bytevector literals to the runtime
4. Document bytevector syntax in language specification
