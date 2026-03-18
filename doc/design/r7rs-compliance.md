# R7RS Small Compliance Tracker

## Overview

This document tracks Vibe's progress toward implementing the R7RS Small Scheme standard. Each section corresponds to a section of the R7RS specification. Items are marked as:

- **Not Started** — no implementation work has begun
- **In Progress** — partially implemented
- **Done** — fully implemented and tested

The kernel DSL (`llvm:*` primitives) provides low-level building blocks but does not itself constitute Scheme-level support. An item is marked "Done" only when it is usable as standard Scheme syntax or as a standard procedure callable from Scheme code.

## 4. Expressions

### 4.1 Primitive expression types

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| Variable references | 4.1.1 | Not Started | Compiler resolves DSL-level names but not Scheme-level variable lookup |
| `quote` | 4.1.2 | Not Started | Kernel handles quoted atoms for DSL dispatch; no general Scheme `quote` |
| Procedure calls | 4.1.3 | Not Started | `llvm:call` exists at DSL level; no Scheme-level procedure call semantics |
| `lambda` | 4.1.4 | Not Started | No closure support yet |
| `if` | 4.1.5 | Not Started | `llvm:br` provides conditional branching at DSL level |
| `set!` | 4.1.6 | Not Started | `llvm:store` exists at DSL level |
| `include` | 4.1.7 | Not Started | |

### 4.2 Derived expression types

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `cond` | 4.2.1 | Not Started | |
| `case` | 4.2.1 | Not Started | |
| `and` | 4.2.1 | Not Started | |
| `or` | 4.2.1 | Not Started | |
| `when` | 4.2.1 | Not Started | |
| `unless` | 4.2.1 | Not Started | |
| `let` | 4.2.2 | Not Started | |
| `let*` | 4.2.2 | Not Started | Kernel has `let*` as a DSL built-in; not yet a Scheme-level macro |
| `letrec` | 4.2.2 | Not Started | |
| `letrec*` | 4.2.2 | Not Started | |
| `let-values` | 4.2.2 | Not Started | |
| `let*-values` | 4.2.2 | Not Started | |
| `begin` | 4.2.3 | Not Started | |
| `do` | 4.2.4 | Not Started | |
| `delay` | 4.2.5 | Not Started | |
| `delay-force` | 4.2.5 | Not Started | |
| `force` | 4.2.5 | Not Started | |
| `make-promise` | 4.2.5 | Not Started | |
| `make-parameter` | 4.2.6 | Not Started | |
| `parameterize` | 4.2.6 | Not Started | |
| `guard` | 4.2.7 | Not Started | |
| Quasiquotation | 4.2.8 | Not Started | |
| `case-lambda` | 4.2.9 | Not Started | |

### 4.3 Macros

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `let-syntax` | 4.3.1 | Not Started | |
| `letrec-syntax` | 4.3.1 | Not Started | |
| `syntax-rules` | 4.3.2 | Not Started | |
| `syntax-error` | 4.3.3 | Not Started | |

## 5. Program Structure

### 5.1-5.4 Definitions and syntax definitions

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `define` (variable) | 5.2 | Not Started | Kernel uses `llvm:define-function`; no Scheme-level `define` |
| `define` (procedure shorthand) | 5.2 | Not Started | |
| Internal definitions | 5.3.2 | Not Started | |
| `define-values` | 5.2 | Not Started | |
| `define-syntax` | 5.4 | Not Started | |
| `define-record-type` | 5.5 | Not Started | |

### 5.6-5.7 Libraries and programs

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `define-library` | 5.6 | Not Started | |
| `import` | 5.6 | Not Started | |
| `export` | 5.6 | Not Started | |
| `begin` (library body) | 5.6 | Not Started | |
| `include` / `include-ci` | 5.6 | Not Started | |
| `cond-expand` | 5.6 | Not Started | |
| Programs (top-level `import` + expressions) | 5.7 | Not Started | |

## 6. Standard Procedures

### 6.1 Equivalence predicates

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `eqv?` | 6.1 | Not Started | |
| `eq?` | 6.1 | Not Started | |
| `equal?` | 6.1 | Not Started | |

### 6.2 Numbers

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| Number types (integer, rational, real, complex) | 6.2.1 | Not Started | Kernel has `i32`/`i64` integers at DSL level |
| Exactness | 6.2.1 | Not Started | |
| Numerical literals | 6.2.4 | Not Started | Kernel lexer parses integers |
| `number?`, `complex?`, `real?`, `rational?`, `integer?` | 6.2.6 | Not Started | |
| `exact?`, `inexact?` | 6.2.6 | Not Started | |
| `=`, `<`, `>`, `<=`, `>=` | 6.2.6 | Not Started | `llvm:icmp` exists at DSL level |
| `+`, `-`, `*`, `/` | 6.2.6 | Not Started | `llvm:add`, `llvm:sub`, `llvm:mul` exist at DSL level |
| `zero?`, `positive?`, `negative?`, `odd?`, `even?` | 6.2.6 | Not Started | |
| `max`, `min` | 6.2.6 | Not Started | |
| `abs` | 6.2.6 | Not Started | |
| `quotient`, `remainder`, `modulo` | 6.2.6 | Not Started | `llvm:udiv`, `llvm:urem` exist at DSL level |
| `gcd`, `lcm` | 6.2.6 | Not Started | |
| `floor`, `ceiling`, `truncate`, `round` | 6.2.6 | Not Started | |
| `exact->inexact`, `inexact->exact` | 6.2.6 | Not Started | |
| `number->string`, `string->number` | 6.2.7 | Not Started | |

### 6.3 Booleans

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `#t`, `#f` | 6.3 | Not Started | Kernel lexer recognizes `#t`/`#f` |
| `not` | 6.3 | Not Started | |
| `boolean?` | 6.3 | Not Started | |
| `boolean=?` | 6.3 | Not Started | |

### 6.4 Pairs and lists

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `pair?` | 6.4 | Not Started | |
| `cons` | 6.4 | Not Started | |
| `car`, `cdr` | 6.4 | Not Started | |
| `set-car!`, `set-cdr!` | 6.4 | Not Started | |
| `null?` | 6.4 | Not Started | |
| `list?` | 6.4 | Not Started | |
| `list` | 6.4 | Not Started | |
| `length` | 6.4 | Not Started | |
| `append` | 6.4 | Not Started | |
| `reverse` | 6.4 | Not Started | |
| `list-tail`, `list-ref` | 6.4 | Not Started | |
| `list-set!` | 6.4 | Not Started | |
| `memq`, `memv`, `member` | 6.4 | Not Started | |
| `assq`, `assv`, `assoc` | 6.4 | Not Started | |
| `list-copy` | 6.4 | Not Started | |
| `map`, `for-each` | 6.4 | Not Started | Also listed under 6.10 |

### 6.5 Symbols

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `symbol?` | 6.5 | Not Started | |
| `symbol=?` | 6.5 | Not Started | |
| `symbol->string` | 6.5 | Not Started | |
| `string->symbol` | 6.5 | Not Started | |

### 6.6 Characters

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `char?` | 6.6 | Not Started | |
| `char=?`, `char<?`, `char>?`, `char<=?`, `char>=?` | 6.6 | Not Started | |
| `char-alphabetic?`, `char-numeric?`, `char-whitespace?` | 6.6 | Not Started | |
| `char-upcase`, `char-downcase` | 6.6 | Not Started | |
| `char->integer`, `integer->char` | 6.6 | Not Started | |

### 6.7 Strings

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `string?` | 6.7 | Not Started | |
| `make-string` | 6.7 | Not Started | |
| `string` | 6.7 | Not Started | |
| `string-length` | 6.7 | Not Started | Kernel has `strlen` at C level |
| `string-ref` | 6.7 | Not Started | |
| `string-set!` | 6.7 | Not Started | |
| `string=?`, `string<?`, etc. | 6.7 | Not Started | Kernel has `strncmp` at C level |
| `substring` | 6.7 | Not Started | |
| `string-append` | 6.7 | Not Started | |
| `string-copy` | 6.7 | Not Started | |
| `string->list`, `list->string` | 6.7 | Not Started | |
| `string-copy!`, `string-fill!` | 6.7 | Not Started | |
| `number->string`, `string->number` | 6.7 | Not Started | Also under 6.2 |

### 6.8 Vectors

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `vector?` | 6.8 | Not Started | |
| `make-vector` | 6.8 | Not Started | |
| `vector` | 6.8 | Not Started | |
| `vector-length` | 6.8 | Not Started | |
| `vector-ref` | 6.8 | Not Started | |
| `vector-set!` | 6.8 | Not Started | |
| `vector->list`, `list->vector` | 6.8 | Not Started | |
| `vector-copy`, `vector-copy!`, `vector-fill!` | 6.8 | Not Started | |
| `vector-append` | 6.8 | Not Started | |
| `vector-map`, `vector-for-each` | 6.8 | Not Started | |
| `string->vector`, `vector->string` | 6.8 | Not Started | |

### 6.9 Bytevectors

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `bytevector?` | 6.9 | Not Started | |
| `make-bytevector` | 6.9 | Not Started | |
| `bytevector` | 6.9 | Not Started | |
| `bytevector-length` | 6.9 | Not Started | |
| `bytevector-u8-ref`, `bytevector-u8-set!` | 6.9 | Not Started | |
| `bytevector-copy`, `bytevector-copy!`, `bytevector-append` | 6.9 | Not Started | |
| `utf8->string`, `string->utf8` | 6.9 | Not Started | |

### 6.10 Control features

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `procedure?` | 6.10 | Not Started | |
| `apply` | 6.10 | Not Started | |
| `map` | 6.10 | Not Started | |
| `for-each` | 6.10 | Not Started | |
| `string-map`, `string-for-each` | 6.10 | Not Started | |
| `call-with-current-continuation` (`call/cc`) | 6.10 | Not Started | Requires runtime continuation support |
| `values` | 6.10 | Not Started | |
| `call-with-values` | 6.10 | Not Started | |
| `dynamic-wind` | 6.10 | Not Started | |

### 6.11 Exceptions

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `with-exception-handler` | 6.11 | Not Started | |
| `raise` | 6.11 | Not Started | |
| `raise-continuable` | 6.11 | Not Started | |
| `error` | 6.11 | Not Started | |
| `error-object?`, `error-object-message`, `error-object-irritants`, `error-object-type` | 6.11 | Not Started | |

### 6.12 Environments and evaluation

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `environment` | 6.12 | Not Started | |
| `scheme-report-environment` | 6.12 | Not Started | |
| `null-environment` | 6.12 | Not Started | |
| `interaction-environment` | 6.12 | Not Started | |
| `eval` | 6.12 | Not Started | |

### 6.13 Input and output

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| **Ports** | | | |
| `input-port?`, `output-port?`, `textual-port?`, `binary-port?`, `port?` | 6.13.1 | Not Started | |
| `input-port-open?`, `output-port-open?` | 6.13.1 | Not Started | |
| `current-input-port`, `current-output-port`, `current-error-port` | 6.13.1 | Not Started | |
| `open-input-file`, `open-output-file` | 6.13.1 | Not Started | |
| `open-binary-input-file`, `open-binary-output-file` | 6.13.1 | Not Started | |
| `close-port`, `close-input-port`, `close-output-port` | 6.13.1 | Not Started | |
| `open-input-string`, `open-output-string`, `get-output-string` | 6.13.1 | Not Started | |
| `open-input-bytevector`, `open-output-bytevector`, `get-output-bytevector` | 6.13.1 | Not Started | |
| **Read** | | | |
| `read` | 6.13.2 | Not Started | |
| `read-char`, `peek-char`, `read-line` | 6.13.2 | Not Started | |
| `char-ready?` | 6.13.2 | Not Started | |
| `read-string` | 6.13.2 | Not Started | |
| `read-u8`, `peek-u8`, `u8-ready?` | 6.13.2 | Not Started | |
| `read-bytevector`, `read-bytevector!` | 6.13.2 | Not Started | |
| `eof-object`, `eof-object?` | 6.13.2 | Not Started | |
| **Write** | | | |
| `write`, `write-shared`, `write-simple` | 6.13.3 | Not Started | |
| `display` | 6.13.3 | Not Started | |
| `newline` | 6.13.3 | Not Started | |
| `write-char` | 6.13.3 | Not Started | |
| `write-string` | 6.13.3 | Not Started | |
| `write-u8` | 6.13.3 | Not Started | |
| `write-bytevector` | 6.13.3 | Not Started | |
| `flush-output-port` | 6.13.3 | Not Started | |

### 6.14 System interface

| Feature | R7RS Section | Status | Notes |
|---|---|---|---|
| `load` | 6.14 | Not Started | |
| `file-exists?` | 6.14 | Not Started | |
| `delete-file` | 6.14 | Not Started | |
| `command-line` | 6.14 | Not Started | |
| `exit` | 6.14 | Not Started | |
| `emergency-exit` | 6.14 | Not Started | |
| `get-environment-variable`, `get-environment-variables` | 6.14 | Not Started | |
| `current-second`, `current-jiffy`, `jiffies-per-second` | 6.14 | Not Started | |
| `features` | 6.14 | Not Started | |

## R7RS Standard Libraries

R7RS Small defines a set of standard libraries. Vibe will need to implement these as `define-library` forms once the library system is in place.

| Library | Status | Notes |
|---|---|---|
| `(scheme base)` | Not Started | Core library; most of sections 4-6 |
| `(scheme case-lambda)` | Not Started | `case-lambda` |
| `(scheme char)` | Not Started | Character procedures |
| `(scheme complex)` | Not Started | Complex number procedures |
| `(scheme cxr)` | Not Started | `caaar` through `cddddr` |
| `(scheme eval)` | Not Started | `eval`, `environment` |
| `(scheme file)` | Not Started | File I/O |
| `(scheme inexact)` | Not Started | Inexact number procedures |
| `(scheme lazy)` | Not Started | `delay`, `force`, promises |
| `(scheme load)` | Not Started | `load` |
| `(scheme process-context)` | Not Started | `command-line`, `exit`, etc. |
| `(scheme read)` | Not Started | `read` |
| `(scheme repl)` | Not Started | `interaction-environment` |
| `(scheme time)` | Not Started | `current-second`, etc. |
| `(scheme write)` | Not Started | `write`, `display` |
| `(scheme r5rs)` | Not Started | R5RS compatibility |

## Implementation Strategy

Vibe takes a **macro-first** approach rather than the textbook order. Because the compiler is already self-hosted with a capable DSL, the macro system can be built on existing AST infrastructure without requiring a Scheme-level runtime. This lets macros improve the development experience before tackling the harder problems of value representation, closures, and memory management. See `macro-system.md` for the full rationale.

The implementation order is:

1. **Macro system (unhygienic)**: `define-syntax`, `syntax-rules` — minimal pattern matching and template substitution, sufficient for kernel-level convenience macros
2. **Kernel rewrite**: Use macros to simplify the compiler's own source code, making subsequent work tractable
3. **Macro system (hygienic)**: Full R7RS-compliant `syntax-rules` with hygienic renaming
4. **Primitive forms**: `quote`, `if`, `lambda`, `define`, `set!` — the irreducible core, implemented with macros available for readability
5. **Core derived forms**: `let`, `let*`, `letrec*`, `begin`, `cond`, `and`, `or`, `when`, `unless` — defined as macros over the primitives
6. **Data types**: pairs/lists, symbols, strings, vectors, bytevectors — the standard data structures
7. **Standard procedures**: arithmetic, predicates, list operations, string operations
8. **Control features**: `apply`, `map`, `call/cc`, `values`, `dynamic-wind`
9. **I/O**: ports, read, write
10. **Library system**: `define-library`, `import`, `export`
11. **Remaining forms**: `do`, `case-lambda`, `guard`, promises, `parameterize`

See `primitive-forms.md` for the analysis of which forms are primitive vs. derived.

## Related Documents

- `vision.md` — Vibe's mission and goals
- `primitive-forms.md` — primitive vs. derived form analysis
- `macro-system.md` — macro-first strategy, phased implementation plan, and architectural changes
