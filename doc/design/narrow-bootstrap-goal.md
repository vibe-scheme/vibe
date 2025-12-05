# Narrow Bootstrap Goal: "Hello, World!" with `define-bitcode`

## Objective

Create a minimal, testable bootstrap compiler that can compile and run a simple "Hello, World!" Vibe program using `define-bitcode`. This serves as the first concrete milestone and enables automated edit/build/test cycles.

## Target Program

The compiler should successfully compile and execute this Vibe program:

```vibe
(define-bitcode (hello name) "
  ; LLVM IR that constructs 'Hello, ' + name + '!' and calls printf
  ")
(hello "World")
```

Expected output: `Hello, World!`

## Architectural Decision: `define-bitcode` as Function Definitions

### Decision

**`define-bitcode` defines LLVM functions, not inline templates.**

Each `define-bitcode` form creates a named LLVM function that can be called. The compiler generates a single LLVM IR module containing all function definitions and the code that calls them.

### Rationale

1. **FFI Compatibility**: Function boundaries enable calling Vibe code from C/other languages and vice versa
2. **Code Reuse**: Functions can be called multiple times without code duplication
3. **LLVM Optimization**: LLVM can optimize functions independently and inline when beneficial
4. **Debugging**: Function boundaries provide natural breakpoints and stack traces
5. **Macro Expansion Model**: Non-`define-bitcode` Vibe code expands to calls to `define-bitcode` functions, maintaining the macro expansion mental model

### Macro Expansion Vision

The long-term vision is that **any Vibe code snippet can expand to LLVM IR via macro expansion**:

- **Core primitives** (`lambda`, `define`, `if`, etc.) are implemented as `define-bitcode` functions
- **Vibe code** expands to calls to these `define-bitcode` functions
- **The compiler** generates a single LLVM IR module with all functions and their calls
- **LLVM** optimizes the entire module, inlining functions when beneficial

This achieves Julia-like "expand any code to IR" but via compile-time macro expansion rather than JIT.

### Implementation Model

```
Vibe Source:
  (define-bitcode (hello name) "...")
  (hello "World")

Expands to LLVM IR Module:
  @.str = private constant [13 x i8] c"Hello, %s!\00"
  
  define void @hello(i8* %name) {
    ; ... LLVM IR from define-bitcode body ...
    call i32 @printf(i8* %format, i8* %name)
    ret void
  }
  
  define i32 @main() {
    %str = getelementptr [6 x i8], [6 x i8]* @.str_world, i32 0, i32 0
    call void @hello(i8* %str)
    ret i32 0
  }
```

**Key points:**
- One LLVM IR module (one `.ll` file) containing everything
- `define-bitcode` creates function definitions
- Vibe expressions expand to function calls
- LLVM handles optimization and inlining

### Future: Minimal Vibe Core

The goal is to keep the Vibe core minimal - only essential `define-bitcode` functions:
- `lambda` - function definition
- `define` - variable/function binding
- `if` - conditional
- `quote` - literal data
- `define-bitcode` - the meta-primitive itself
- Basic arithmetic, comparison, etc.

All other Vibe features expand to calls to these core functions.

## Scope Definition

### What We're Building

1. **Minimal Lexer**: Tokenize basic Scheme syntax (identifiers, strings, parentheses, quotes)
2. **Minimal Parser**: Parse S-expressions into AST
3. **Code Generator**: Convert AST to LLVM IR module, with special handling for `define-bitcode`
4. **Function Definition**: `define-bitcode` creates LLVM function definitions in the module
5. **Function Calls**: Vibe expressions expand to LLVM function calls
6. **Runtime Integration**: Link with libc to call `printf`
7. **Compiler Driver**: Main entry point that orchestrates the pipeline

### What We're NOT Building (Yet)

- Full R7RS Scheme lexical syntax (only what's needed for the test case)
- Garbage collection
- Full FFI system (only printf via libc)
- Complex data structures (minimal runtime)
- Error recovery (fail fast with clear messages)
- Function inlining optimization (let LLVM handle it)

## Implementation Status

### Completed Components

1. ✅ **Lexer** (`bootstrap/lexer/lexer.ll`): Tokenizes identifiers, strings, parentheses, quotes, comments
2. ✅ **Parser** (`bootstrap/parser/parser.ll`): Parses S-expressions into AST nodes
3. ✅ **Code Generator** (`bootstrap/compiler/codegen.ll`): Generates LLVM IR from AST (structure in place, needs refinement)
4. ✅ **Compiler Driver** (`bootstrap/compiler/main.ll`): Orchestrates lexer → parser → codegen pipeline
5. ✅ **Test Infrastructure**: Test program, test runner, CMake integration
6. ✅ **Build System**: Automated build and test scripts

### Implementation Notes

The code generator (`codegen.ll`) generates LLVM IR as text by building up a string buffer. This approach:
- Avoids linking against LLVM libraries at runtime
- Uses existing LLVM tools (already required)
- Simplifies implementation for bootstrap
- Can be optimized later when self-hosting

The current implementation has the structure in place but may need refinement to handle:
- Proper string constant generation
- Parameter name mapping in IR bodies
- Complete IR formatting

## Success Criteria

1. ✅ `./build.sh build` completes without errors
2. ✅ `./build.sh test` runs and passes
3. ✅ Test program `hello_world.vibe` compiles successfully to LLVM IR
4. ✅ Generated IR compiles to executable
5. ✅ Compiled program outputs exactly `Hello, World!`
6. ✅ `define-bitcode` creates LLVM function definitions
7. ✅ Function calls generate LLVM call instructions
8. ✅ Generated code links with libc and calls `printf` correctly
9. ✅ Single LLVM IR module contains all code (one `.ll` file)

## Testing Strategy

1. **Integration test**: Full pipeline test with `hello_world.vibe`
2. **IR validation**: Verify generated IR is valid (can be assembled)
3. **Output validation**: Verify program output matches expected
4. **Automated testing**: Script runs build + test on every change
5. **Manual testing**: Developer can run `./build.sh test` anytime

## File Structure

```
bootstrap/
├── lexer/
│   └── lexer.ll          # Minimal lexer implementation
├── parser/
│   └── parser.ll         # Minimal parser implementation
├── runtime/
│   ├── runtime.ll         # Minimal runtime (stub for now)
│   └── ffi.ll            # Stub (not used in this phase)
└── compiler/
    ├── main.ll           # Compiler driver
    └── codegen.ll        # Code generator (generates single IR module)

test/
├── hello_world.vibe     # Test program
└── run_test.sh          # Test runner

scripts/
└── edit_build_test.sh   # Automated test script
```

## Technical Decisions

### `define-bitcode` Architecture

**Decision**: `define-bitcode` defines LLVM functions, not inline templates.

**Rationale**:
- Enables FFI (can call from C/other languages)
- Code reuse (functions called multiple times)
- LLVM optimization (can inline when beneficial)
- Debugging support (function boundaries)
- Maintains macro expansion model (Vibe code → calls to `define-bitcode` functions)

**Future**: Keep Vibe core minimal - only essential `define-bitcode` functions. All other Vibe features expand to calls to these.

### LLVM IR Generation Strategy

**Decision**: Generate LLVM IR as text, write to `.ll` file, use `llvm-as` to create bitcode.

**Rationale**:
- Avoids linking against LLVM libraries at runtime
- Uses existing LLVM tools (already required)
- Simpler implementation for bootstrap
- Can be optimized later when self-hosting

### Single Module Output

**Decision**: Generate one LLVM IR module containing all functions and code.

**Rationale**:
- Simpler mental model (one file = one program)
- LLVM can optimize entire module together
- Aligns with "macro expansion to IR" vision
- Easier to debug and inspect

### String Handling

**Decision**: For this narrow goal, handle strings as C-style null-terminated strings.

**Rationale**:
- Simplest implementation
- Compatible with `printf`
- Can be enhanced later with proper Vibe string types

## Next Steps After This Goal

Once "Hello, World!" works:
1. Expand lexer to handle more Scheme syntax
2. Expand parser to handle more expression types
3. Implement proper Vibe runtime data structures
4. Add more `define-bitcode` examples
5. Begin implementing bootstrap functions in Vibe itself
6. Explore macro system for expanding Vibe code to `define-bitcode` calls

## Notes

- Keep implementation minimal - only what's needed for the test case
- Error messages should be clear and point to source location
- Code should be well-commented for future self-hosting
- Follow LLVM IR conventions and target triple requirements
- Function boundaries enable future FFI and optimization opportunities
- Single IR module output aligns with macro expansion vision
