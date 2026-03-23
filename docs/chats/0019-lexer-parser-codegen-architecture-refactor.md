# Chat 0019: Lexer/Parser/Codegen Architecture Refactor

**Date**: 2025-12-28
**Model**: Cursor Composer 1
**Context**: Careful refactoring of bootstrap compiler architecture to properly separate concerns between lexer, parser, and codegen phases

## Overview

This session focused on fixing an architectural issue where the codegen phase was performing parsing work (specifically stripping vertical bars from type names and handling % prefix parsing) that should have been handled by the lexer/parser. The refactoring was done incrementally with testing after each step to ensure no regressions.

## Problem Identified

The `codegen_resolve_type_string` function in `bootstrap/compiler/codegen.ll` was performing extensive parsing work:

1. **Vertical bar stripping**: Checking for `|` at start/end and stripping them
   - This is parsing work - bars should already be stripped by lexer
   
2. **% prefix parsing**: Checking for `%` prefix and extracting type names
   - This is parsing work - should be handled by parser normalization
   
3. **Type format detection**: Checking for multiple formats (with/without bars, with/without % prefix)
   - This is parsing work - parser should normalize to single format

**Root Cause**: Codegen was being defensive and handling multiple input formats that shouldn't exist after proper normalization.

## Solution Approach (Incremental)

### Phase 1: Verify Current Working State
- ✅ Tested that original code works correctly
- ✅ Verified baseline: `test.vibe` generates correct LLVM IR

### Phase 2: Add Parser Normalization
**File**: `bootstrap/parser/parser.ll`

**Changes**:
1. Added `parse_normalize_type_atom` function to normalize type atom values
   - Strips `%` prefix from named types: `%Token` → `Token`
   - Keeps pointer indicators (`*`) as-is
   - Vertical bars are already stripped by lexer, so parser doesn't handle them
   - Returns original value if no normalization needed (for non-% types)

2. Updated `parse_create_atom` to call normalization function
   - All atoms are normalized when created
   - This ensures consistent format for type names

**Testing**: ✅ Verified function still generates correctly after parser changes

### Phase 3: Simplify Codegen (Incremental)

#### 3.1: Simplify Built-in Type Checks
**File**: `bootstrap/compiler/codegen.ll`

**Changes**:
1. **Simplified void check**: Removed bar handling, single-path logic
2. **Simplified i8/i8* checks**: Removed bar handling, single-path logic  
3. **Simplified i32 check**: Removed bar handling, single-path logic
4. **Simplified i64 check**: Removed bar handling, single-path logic

**Testing**: ✅ Tested after each simplification - function still generates correctly

#### 3.2: Simplify Array Type Handling
**Changes**:
1. Removed bar-checking from array parsing
2. Kept array parsing logic (extracting size and element type) as this is semantic work
3. Assumes input is already normalized (no bars)

**Testing**: ✅ Tested with array types - works correctly

#### 3.3: Simplify Named Type Handling
**Changes**:
1. Removed complex bar-checking and % prefix parsing logic
2. Assumes `%` prefix already stripped by parser
3. Assumes bars already stripped by lexer
4. Simple check for `*` suffix to determine pointer types
5. Fixed control flow: named types checked AFTER built-in types (not before)

**Testing**: ✅ Tested with named types - works correctly

## Key Architectural Principles Established

1. **Lexer**: Recognizes terminal tokens only (per R7RS spec)
   - Vertical bar symbols are recognized as a single token type
   - Content between bars is the token value (bars are syntax, not content)
   - Lexer strips bars during tokenization
   - Implementation: `lex_read_vertical_bar_symbol()` in `bootstrap/lexer/lexer.ll`

2. **Parser**: Handles all production rules and syntax normalization
   - Recognizes combinations of tokens as language constructs
   - Normalizes syntax variations:
     - Named types: `|%Token|` → lexer: `"%Token"` → parser: `"Token"` (strip % prefix)
     - Other types: `|i32|` → lexer: `"i32"` → parser: `"i32"` (pass through)
   - Generates clean AST with normalized values
   - Does NOT perform semantic resolution (that's codegen's job)
   - Implementation: `parse_normalize_type_atom()` in `bootstrap/parser/parser.ll`

3. **Codegen**: Handles semantic resolution only
   - Maps normalized type names to LLVM types
   - Resolves named types by lookup (no `%` prefix needed)
   - Creates pointer/array types based on semantic indicators (`*`, array syntax)
   - Does NOT parse syntax or strip delimiters
   - Assumes input is already normalized (no bars, no % prefix for named types)
   - Implementation: `codegen_resolve_type_string()` in `bootstrap/compiler/codegen.ll`

## Files Modified

1. **bootstrap/parser/parser.ll**: Added type normalization function (+55 lines)
   - `parse_normalize_type_atom`: Strips % prefix from named types
   - Updated `parse_create_atom` to use normalization

2. **bootstrap/compiler/codegen.ll**: Simplified type resolution (-96 net lines)
   - Removed vertical bar handling from all built-in types (~150 lines removed)
   - Simplified named type handling (~50 lines removed)
   - Simplified array type handling (~20 lines removed)
   - Added comments documenting normalization assumptions

3. **docs/design/r7rs-syntax.bnf** (new): Complete R7RS formal syntax reference
   - Full Chapter 7 syntax from R7RS specification
   - Vibe-specific implementation notes and principles

## Testing and Verification

**Test Cases Verified**:
1. ✅ `|i32|` → lexer strips to `i32` → parser passes `i32` → codegen resolves to i32 type
2. ✅ `|i8*|` → lexer strips to `i8*` → parser passes `i8*` → codegen resolves to i8 pointer type
3. ✅ `|[14 x i8]|` → lexer strips to `[14 x i8]` → parser passes `[14 x i8]` → codegen resolves to array type
4. ✅ `|%Token|` → lexer strips to `%Token` → parser strips `%` → codegen looks up "Token"
5. ✅ Multiple parameter types work correctly
6. ✅ Function generation complete (not stopping early)

**Original Test File** (`test.vibe`):
```scheme
(llvm:define-ffi-function (printf (fmt-string |i8*|)) |i32| ...)
(llvm:define-function (bool-test (n |i8|)) |i8| ...)
```

**Result**: ✅ Generates identical LLVM IR to previous working version

## Trade-offs Considered

1. **Normalizing all atoms vs. type-aware normalization**:
   - **Decision**: Normalize all atoms that start with `%`
   - **Rationale**: In Vibe's bootstrap compiler, `%` is specifically used for LLVM type names. Normalizing all atoms is simpler and safe for bootstrap phase. Non-type atoms starting with `%` would be rare and normalization is harmless.

2. **Array type parsing location**:
   - **Decision**: Keep array parsing in codegen (semantic work)
   - **Rationale**: Extracting size `N` from `[N x i8]` and creating the LLVM array type is semantic resolution, not syntax parsing. Parser normalizes format (strips bars), codegen performs semantic resolution.

3. **Structured AST vs. normalized strings**:
   - **Decision**: Keep as normalized strings (for bootstrap simplicity)
   - **Rationale**: Structured AST nodes would require new AST node types and more complex parser logic. Normalized strings are sufficient for bootstrap phase.

## Success Criteria

1. ✅ R7RS syntax extracted to BNF file (complete Chapter 7)
2. ✅ Codegen no longer contains vertical bar stripping logic
3. ✅ Parser normalizes % prefix from named types
4. ✅ All tests pass with refactored code
5. ✅ Function generation works correctly (no early stopping)
6. ✅ Architecture documented in chat file

## Lessons Learned

1. **Always test baseline first**: Before making changes, verify the current code works
2. **Incremental changes**: Make small changes and test after each step
3. **Control flow matters**: Named type checks must come AFTER built-in type checks
4. **Parser normalization is key**: Once parser normalizes correctly, codegen can be much simpler

## Related Documentation

- `docs/design/r7rs-syntax.bnf`: Complete R7RS syntax reference with Vibe implementation notes
- `docs/chats/0018-array-type-parsing-and-architectural-separation.md`: Previous work on array types
- `AGENTS.md`: Coding standards and practices
